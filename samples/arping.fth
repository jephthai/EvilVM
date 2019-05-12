\ 
\ This example shows how to do an ARP ping on the compiler's
\ local subnet.  Microsoft is so kind to give us such
\ convenient functions in the standard libraries.
\

{ ." 

arping.fth

Implements an ARP ping for testing whether systems on the
local subnet are live.

Run arping <ip> to ping an address.

" ETX emit }!

loadlib ws2_32.dll
value ws2_32

loadlib iphlpapi.dll
value iphlpapi

ws2_32 1 dllfun inet_addr inet_addr
iphlpapi 4 dllfun SendARP SendARP

: get_ip   readline 2dup type drop inet_addr ;
: .mac     space 6 bounds do i c@ .byte ." :" loop ;
: .arping  0= if here .mac ."  alive" else ."  dead" then cr ;
: setargs  get_ip 0 here 6 over 16 + swap over ! ;
: arping   .pre setargs SendARP .arping .post ;
