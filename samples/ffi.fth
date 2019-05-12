0 !echo

\ Examples for FFI.  Provide the DLL base address and the name
\ of the function (as a C-string), plus the number of args
\ the function takes.  You'll get a defined word that properly
\ consumes args, sets up for the calling convention, and runs
\ the function, leaving the result on top of the stack.

kernel32 1 dllfun ExitProcess ExitProcess
kernel32 3 dllfun CopyFile CopyFile
kernel32 7 dllfun CreateFile CreateFileA
kernel32 5 dllfun WriteFile WriteFile
kernel32 1 dllfun CloseHandle CloseHandle

variable handle
variable written

hex
: GENERIC_WRITE 40000000 ;
: CREATE_ALWAYS 2 ;
dec

: mkfile  s" bogus.dat" drop GENERIC_WRITE 0 0 CREATE_ALWAYS 0 0 CreateFile ;
: message handle @ -rot written 0 WriteFile drop ;
: close   handle @ CloseHandle drop ;

mkfile handle !
{ s" \x1b[35;1mMy name is Inigo Montoya!\n" }! message
{ s" You killed my father!\n"               }! message
{ s" Prepare to die!\x1b[0m\n"              }! message
close

0 ExitProcess
bye
