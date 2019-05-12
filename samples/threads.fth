\ ------------------------------------------------------------------------
\ An interface for listing processes and current status of threads
\ ------------------------------------------------------------------------

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

private

: align 64 here 64 /mod drop - allot ;

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
  dup 28 + d@ ." PPID: " 8 cyan .r magenta
      44 +    ." Image: " green .cstring magenta cr ;

public{

: .threads .pre PID ! ['] .threads* *threads .post ;
: .ps .pre ['] .ps *processes .post ;

}public
