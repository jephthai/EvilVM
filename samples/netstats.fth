\
\ netstat is a nice command, but we can do most of what it does
\ directly with iphlpapi.dll.
\

{ ." 

  netstats.fth
  
  Provides some basic netstat-like functionality using the interfaces
  provided by iphlpapi.dll.
  
  Run netstat to see current TCP connections
  Run routes to view the route table
  
" ETX emit }!

loadlib ws2_32.dll
value ws2_32

loadlib iphlpapi.dll
value iphlpapi

\ private

\ ------------------------------------------------------------------------
\ Print the routing table
\ ------------------------------------------------------------------------

iphlpapi 3 dllfun GetIpForwardTable GetIpForwardTable

variable tsize 1024 tsize !
variable table
tsize @ allocate table !

: get-table ( -- addr )
  table @ tsize 1 GetIpForwardTable
  if table @ tsize @ realloc table ! tail then
  table @ 
;

variable len

: @octets  4 bounds do i c@ loop ;

: .ip
  <# @octets 3 0 do #s 46 hold loop #s #>   \ get and format octets
  18 out# @ - 0 do space loop ;              \ pad to 18 chars to be pretty

: >dword 
  ( a -- a+4 a )
  dup 4 + swap ;
    
: .table ( addr -- )
  ." #  Destination        Netmask            Gateway\n"
  ." -  -----------        -------            -------\n"
  dup 4 + swap d@ 0 do
    i 2 .r space 
    dup i 56 * +       \ find i'th row in table
    >dword .ip space
    >dword .ip space 
    >dword drop
    >dword .ip
    cr drop
  loop
;

\ ------------------------------------------------------------------------
\ Get network configuration parameters
\ ------------------------------------------------------------------------

iphlpapi 2 dllfun GetNetworkParams GetNetworkParams

\ space for FIXED_INFO struct
create net-params 1024 allot
variable param-size 1024 param-size !

: get-net-params
  net-params param-size GetNetworkParams 
;

: .params
  ." Hostname:    " net-params .cstring cr
  ." Domainname:  " net-params 132 + .cstring cr
  ." DNS list:    " net-params 280 + .cstring cr
;

\ ------------------------------------------------------------------------
\ Get current connection information
\ ------------------------------------------------------------------------

iphlpapi 6 dllfun GetExtendedTcpTable GetExtendedTcpTable

2 value AF_INET
1 value TCP_TABLE_BASIC_CONNECTIONS 
2 value TCP_TABLE_BASIC_ALL
5 value TCP_TABLE_OWNER_PID_ALL

variable tcp-conn-size
variable tcp-conn-table

\ load tcp connection table
: get-tcp-table
  tcp-conn-table @
  tcp-conn-size
  0 AF_INET TCP_TABLE_OWNER_PID_ALL 0
  GetExtendedTcpTable
;

\ run once to get data size, allocate, and then load table
: get-tcp-table
  tcp-conn-table off
  tcp-conn-size off
  get-tcp-table 
  tcp-conn-size @ allocate tcp-conn-table !
  get-tcp-table
;

\ reset the tcp connection state and release memory
: free-tcp-table
  tcp-conn-table @ free
  tcp-conn-table off
  tcp-conn-size off
;

: type.pad  -rot swap over type - spaces ;
: hl ." \x1b[1m" ;

: .state
  case
    1  of s" CLOSED"       12 type.pad endof
    2  of s" LISTEN"       12 type.pad endof
    3  of s" SYN_SENT"     12 type.pad endof
    4  of s" SYN_RCVD"     12 type.pad endof
    5  of +bold s" ESTAB"  12 type.pad endof
    6  of s" FIN_WAIT1"    12 type.pad endof
    7  of s" FIN_WAIT2"    12 type.pad endof
    8  of s" CLOSE_WAIT"   12 type.pad endof
    9  of s" CLOSING"      12 type.pad endof
    10 of s" LAST_ACK"     12 type.pad endof
    11 of s" TIME_WAIT"    12 type.pad endof
    12 of s" DELETE_TCB"   12 type.pad endof
    drop  s" UNKNOWN" 12 type.pad
  endcase
;

: net.16
  dup c@ 8 <<
  swap 1+ c@ or ;
  
: .tcp-table
  tcp-conn-table @ 
  ." #   State       Local IP           lport   Remote IP          rport   PID\n"
  ." -   -----       --------           -----   ---------          -----   ---\n"
  dup 4 + swap d@ 0 do
    -bold
    i 3 .r space 
    dup i 24 * +       \ find i'th row in table
    >dword d@ .state    \ state
    >dword .ip space     \ local ip
    >dword net.16 8 .r    \ lport
    >dword .ip space       \ remote ip 
    >dword net.16 8 .r      \ rport
    >dword d@ dup .          \ lovely PID data
    pid = if ." *" then 
    cr drop
  loop
;


\ determine if a given TCP connection table row is an ESTABLISHED connection
: row-estab? ( row -- bool )
  d@ 5 = ;

\ extract row fields as a list node
variable local
variable remote
: tcp-node ( row -- node )
  >dword drop
  >dword @ >r 
  >dword drop
  >dword @ r> 
  cons nip ;

\ decode the connection data in a list node
: tcp-pair ( node -- addr port )
  dup 32 >> dup 255 and 8 <<
            swap 8 >> or >r
      32 << 32 >> r> ;

\ print it prettily
: .tcp-pair
  swap here ! here .ip 8 .r ;

\ pretty print a node containing a connection
: .tcp-node ( node -- )
  dup cdr tcp-pair .tcp-pair 
      car tcp-pair .tcp-pair ;

\ get all ESTABLISHED connections in a list
variable _list 
_list off

: get-tcp-list ( -- list )
  _list off
  get-tcp-table
  tcp-conn-table @ dup 4 + swap d@ 0 do
    \ each row
    dup row-estab? if
      dup tcp-node _list @ cons _list !
    then

    \ next row
    24 +
  loop
  free-tcp-table
;
  
: free-tcp-list
  ['] uncons _list @ each
  _list @ free-list
;

\ ------------------------------------------------------------------------
\ external interface
\ ------------------------------------------------------------------------

\ public{

: netstat    get-tcp-table if .err else .pre .tcp-table .post free-tcp-table then ;
: netparams  get-net-params if .err else .pre .params .post then ;
: routes     .pre get-table .table .post table @ free ;

\ }public
