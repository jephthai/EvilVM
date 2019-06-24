\ require structs.fth
\ require named-locals.fth
\ require strings.fth
\ require parsers.fth
\ require luhn.fth

{ ." 

 This is a sample that searches allocated memory in other processes.
 It presents a functional interface, where you can provide your own
 scanners that are passed regions of memory from the target process.
 
 E.g., consider these examples:
 
 Run 672 ' scan-pans each-region to search for 16-digit #s
 
 Run 672 { s\" josh\" match-ascii } each-region to search for ASCII
 strings that contain josh as a substring.
 
 In each case, the stack effect for the each-region word is as
 follows:
 
   ( PID FN -- )
 
 Where PID is the process ID of the target process whose memory you
 want to scan, and FN is the XT for a function that will behave in
 the following way:
 
   ( ADDR LEN -- )
 
 The scanner is thus passed a region of memory starting at the address
 ADDR, and continuing for LEN bytes.  You can also use the word
 translate to translate an address in this provided region to its
 correct address in the target process's address space:
 
   : translate ( ADDR -- ADDR' ) ... ;
 
 The sophistication of these scanners is up to you.  NOTE: the scanner
 will only process PAGE_READWRITE regions of memory.  If you want to
 scan others, you'll have to modify the code.
   
" ETX emit }!


: word-align 7  + $fffffff8 and ;
: para-align 15 + $fffffff0 and ;

\ Some structures from WIN32 that we need to work with 
struct SYSTEM_INFO
  DWORD     field dwOemId
  DWORD     field dwPageSize
  QWORD     field lpMinimumApplicationAddress
  QWORD     field lpMaximumApplicationAddress
  QWORD     field dwActiveProcessorMask
  DWORD     field dwNumberOfProcessors
  DWORD     field dwProcessorType
  DWORD     field dwAllocationGranularity
  WORD      field wProcessorLevel
  WORD      field wProcessorRevision
end-struct

struct MEMORY_BASIC_INFORMATION
  QWORD  field BaseAddress
  QWORD  field AllocationBase
  DWORD  field AllocationProtect
  word-align
  QWORD  field RegionSize
  DWORD  field State
  DWORD  field Protect
  DWORD  field Type
  word-align
end-struct

\ function imports from KERNEL32.DLL
kernel32 3 dllfun OpenProcess OpenProcess
kernel32 4 dllfun VirtualQueryEx VirtualQueryEx
kernel32 1 dllfun GetSystemInfo GetSystemInfo
kernel32 5 dllfun ReadProcessMemory ReadProcessMemory

$400 value PROCESS_QUERY_INFORMATION
$10  value PROCESS_VM_READ

variable target-pid
variable output
variable region
variable bytes
variable process
variable minaddr
variable maxaddr

: 8align 8 here 7 and - allot here this >xt 10 + ! ;

create system-info 8align SYSTEM_INFO allot
create mem-info    8align MEMORY_BASIC_INFORMATION allot

: get-sys-info
  system-info GetSystemInfo drop
  system-info lpMinimumApplicationAddress @ minaddr !
  system-info lpMaximumApplicationAddress @ maxaddr !
;

: open-process
  dup target-pid !
  PROCESS_QUERY_INFORMATION PROCESS_VM_READ or 
  0 rot OpenProcess process !
;

: close-process
  process @ CloseHandle drop
;

: mem-valid?
  mem-info Protect get 4 =
;

: mem-commited?
  mem-info State get $1000 =
;

readline \RFound region: \B%.d\R bytes at address \B%.x\R prot: \B%x\R state: \B%x\R\n
String value region-fmt

: .region
  mem-info State get
  mem-info Protect get
  mem-info BaseAddress get 10
  mem-info RegionSize  get 14
  region-fmt S.printf
;

: translate    region @ - mem-info BaseAddress get + ;

variable scanner
variable range-start
variable range-len

\ ------------------------------------------------------------------------
\ Scanning for 16-digit numbers that might be PANs -- including UNICODE!
\ This uses the parsers.fth library to do a pretty decent job of finding
\ likely PAN encodings.  
\ ------------------------------------------------------------------------

\ I want to support Unicode and ASCII, so we'll redefine walk to work with either
' walk value walk-fn
: walk-unicode  over w@ >r >r 2 + r> 2 - r> ;
: walk-ascii    walk ;
: walk          walk-fn execute ;
: unicode       ['] walk-unicode [to] walk-fn ;
: ascii         ['] walk-ascii   [to] walk-fn ;

create TEST 16 allot
create PAN 16 allot
variable PAN-index PAN-index off

: inc-index  PAN-index @ 1+ 16 /mod drop PAN-index ! ;
: save-digit PAN PAN-index @ + c! inc-index ;
: get-PAN    16 0 do PAN PAN-index @ + c@ TEST i + c! inc-index loop ;

variable sepchar

: EOS       dup 0 = ;
: digit     walk dup $30 $39 within dup if swap save-digit else nip then ;
: digits    0 do digit not if unloop 0 return then loop -1 ;
: <>digit   digit not ;
: sentinel  walk [char] ; = ;
: sep1      walk sepchar ! -1 ;
: sepN      walk sepchar @ = ;

: term     parser EOS | <>digit end-parser ;

: cc#-sep
  parser
    4 digits & sep1 & 4 digits & sepN & 4 digits & sepN & 4 digits
  end-parser
;

: cc#-lang
  parser
    cc#-sep   & term  |
    16 digits & term  |
    sentinel  & digit & digit & me
  end-parser
;

: cc#-lang  parser ascii cc#-lang | unicode cc#-lang end-parser ascii ;

: .addr ." 0x" 12 hex .r dec ;

\ finds likely PANs in memory
: scan-pans ( addr u -- )
  begin
    dup 16 > while

    \ make sure we're in a string
    \ (this makes a HUGE difference in performance)
    over c@ 32 126 within if 

      \ parse this spot for a PAN
      2dup cc#-lang if 

	\ we have a match, so pull it out and print it for the user
	>r >r over ( addr u addr )
	r@ swap -  ( addr u len )

	\ load match into TEST variable, and check for luhn
	get-PAN TEST 16 luhn if

	  \ yay, a "legit" PAN, print it!
	  nip over hex -bold .addr +bold 
	  TEST 16 type space
	  -bold type cr
	else

	  \ an illegitimate PAN, so scrub the stack
	  nip 2drop
	then

	2r> ( addr u )
      else
	2drop walk drop
      then
    else
      walk drop
    then
  repeat
  2drop 
;

\ ------------------------------------------------------------------------
\ Scanning for ASCII substrings
\ ------------------------------------------------------------------------

: ascii? 32 126 within ;

: strlen ( boundary addr -- addr u )
  tuck - 2dup bounds do
    i c@ ascii? 0= if drop dup i - neg unloop return then
  loop
;

: backup ( boundary here -- here' )
  begin
    2dup <= while
    dup 1- c@ ascii? 0= if nip return then
    1-
  repeat
  nip
;

: contains ( regA regN subA subN -- addr[1] )
  locals regA regN subA subN
  begin
    regN @ subN @ >= while
    regA @ subN @ subA @ subN @ strcmp 0=
    if regA @ unframe return then
    1 regA +!
    1 regN -!
  repeat
  0 
  end-locals
;

\ this is ugly, even without using local named variables.  I should
\ really consider abstracting a lot of this with a general strings
\ or region API.

variable notified

: match-ascii ( addr u addr u -- )
  notified on
  locals regA regN subA subN
  
    \ loop through this region until we've checked it all
    begin regN @ subN @ >= while
  
      \ test if from this offset, we find a string match
      regA @ regN @ subA @ subN @ contains
      dup if
	
	\ print region info for first match
	notified @ if cr .region notified off then
	
        \ find beginning of this string
        regA @ swap backup 
  
        \ find forward extent of this string
        regA @ regN @ + over strlen ( matchA matchU )
  
        \ translate its address to target's space and print in hex
        over translate -bold hex 16 .r dec +bold
  
        \ now print this detected string
        2dup type cr
  
        \ advance to the remaining portion of this region
        nip + regA @ regN @ + over -
        regN ! regA !
      else
        drop unframe return
      then
  
    repeat

  end-locals
;

\ ------------------------------------------------------------------------
\ Reading memory in another process
\ ------------------------------------------------------------------------

: read-memory ( -- bool )
  mem-info RegionSize get allocate region !
  process @
  mem-info BaseAddress get
  region @
  mem-info RegionSize get
  output
  ReadProcessMemory
;

: .prefix
  bytes off .pre -bold ." Successfully opened process " 
  +bold target-pid @ . cr cr
;

: .amount
  dup $400      < if . ." B " return then
  dup $100000   < if $400 / . ." KB " return then
  dup $40000000 < if $100000 / . ." MB " return then
  $40000000 / . ." GB " 
;

: .suffix
  -bold ." \nProcessed " +bold bytes @ .amount -bold ." of process RAM\n" .post
;  

: setup       ( pid scan -- ) get-sys-info scanner ! open-process ;
: in-memory?  ( -- bool )     minaddr @ maxaddr @ < ;
: get-region  ( -- bool )     process @ minaddr @ mem-info MEMORY_BASIC_INFORMATION VirtualQueryEx ;
: scan-region ( -- )          region @ mem-info RegionSize get scanner @ execute ;
: next-region ( -- )          mem-info RegionSize get minaddr +! ;

: handle-region ( -- )
  mem-valid? mem-commited? and if
    mem-info RegionSize get bytes +!
    read-memory
    if scan-region then
    region @ free
  then
;

\ Start at minimum address, while below max address
: each-region
  depth 2 >= if
    setup process @ if 
      .prefix begin
        in-memory? while
	get-region 0= if .err return then 
	handle-region
	next-region
      repeat
      .suffix close-process
    else
      .err
    then
  else
    ." usage: [pid] [fun] each-region\n"
  then
;
