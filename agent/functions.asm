;;; ------------------------------------------------------------------------
;;; Macro to simplify function lookup in KERNEL32.DLL
;;; ------------------------------------------------------------------------	

%macro GetProcAddress 2
	; %warning %3 table index: offset
%xdefine %2 [ r15 + offset ]
%assign offset offset + 0x008
	lea rdx, [rbx + %1]
	mov rcx, rdi
	call rsi		; note RSI contains GetProcAddress() ptr
	mov %2, rax		; 
%endmacro	

	call getfns
fns:	
.1:	db "GetStdHandle", 0
.2:	db "WriteFile", 0
.3:	db "ReadFile", 0
.4:	db "ExitProcess", 0
.5:	db "ExitThread", 0
.6:	db "LoadLibraryA", 0
.7:	db "VirtualAlloc", 0
.8:	db "SetConsoleMode", 0
.9:	db "GetConsoleMode", 0
.10:	db "Sleep", 0
.11:	db "CreateFileA", 0
.12:	db "GetLastError", 0
.13:	db "SetErrorMode", 0
.14:	db "AddVectoredExceptionHandler", 0
.15:	db "CloseHandle", 0
.16:	db "GetTickCount", 0

getfns:
	pop rbx
	sub rsp, SHADOW
	mov rsi, W32_GetProcAddress
	mov rdi, KERNEL32_BASE
	mov rcx, rdi
	GetProcAddress fns.1  - fns,                W32_GetStdHandle
	GetProcAddress fns.2  - fns,                   W32_WriteFile
	GetProcAddress fns.3  - fns,                    W32_ReadFile
	GetProcAddress fns.4  - fns,                 W32_ExitProcess
	GetProcAddress fns.5  - fns,                  W32_ExitThread
	GetProcAddress fns.6  - fns,                W32_LoadLibraryA
	GetProcAddress fns.7  - fns,                W32_VirtualAlloc
	GetProcAddress fns.8  - fns,              W32_SetConsoleMode
	GetProcAddress fns.9  - fns,              W32_GetConsoleMode
	GetProcAddress fns.10 - fns,                       W32_Sleep
	GetProcAddress fns.11 - fns,                 W32_CreateFileA
	GetProcAddress fns.12 - fns,                W32_GetLastError
	GetProcAddress fns.13 - fns,                W32_SetErrorMode
	GetProcAddress fns.14 - fns, W32_AddVectoredExceptionHandler
	GetProcAddress fns.15 - fns,                 W32_CloseHandle
	GetProcAddress fns.16 - fns,                W32_GetTickCount
	add rsp, SHADOW
