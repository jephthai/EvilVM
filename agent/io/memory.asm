;;; memory.asm
;;;
;;; An IO stream layer implemented around shared memory.  It should make sense
;;; in both inter-process and same-process shared memory regions.

;;; Put a number on the stack identifying which IO engine this is.  Each IO layer
;;; needs to have its own unique ID.  This allows payloads to make decisions
;;; based on the configured IO.
	
start_def ASM, engine, "engine"
	pushthing 4
end_def engine

;;; This function will be called before any IO is performed.  This can be used to
;;; set up streams, initialize IO layer global variables, make network connections,
;;; etc.
;;;
;;; In the case of the memory I/O layer, we should have received a pointer to the
;;; memory buffer used for transfer in the first argument to the compiler's entry
;;; point.  This has been saved in the arbitrary data pointer in the TEB.  
	
start_def ASM, initio, "initio"
	mov rbp, rsp
	sub rsp, 0x20
	and rsp, -16
	
	xor ebx, ebx
	AddGlobal G_IOVAL, rbx

	mov bl, 0x28
	mov rcx, [gs:rbx]
	AddGlobal G_IOBUF, rcx
	xor ecx, ecx		; clear the ADP so later code won't try to use it
	mov [gs:rbx], rcx
	
	;; Get function pointers for WinINet interface
	InlineString "api-ms-win-core-synch-l1-2-0.dll", rcx, rax
	call W32_LoadLibraryA
	AddGlobal G_SYNCHDLL, rax

	mov rsi, W32_GetProcAddress
	mov rdi, G_SYNCHDLL
	GetProcAddress "WaitOnAddress",		W32_WaitOnAddress
	
	mov rsp, rbp
end_def initio
	
%assign dbgoffset1 code_initio - main
%warning Initio is at dbgoffset1 bytes
	
;;; Take a value from the stack and emit it to the output stream as a single byte.

start_def ASM, emit, "emit"
	mov rbp, rsp
	sub rsp, 0x20
	and rsp, -16
	
	mov rbx, G_IOBUF	; get pointer to IO buffer
.lp:
	mov al, [rbx+0]		; get flag for outbound byte waiting
	and al, al		; test it
	jz .continue		; no data waitin to be read by upstream
	
	mov rax, [rbx]
	mov G_IOVAL, rax
	mov rcx, rbx
	lea rdx, [r15 + G_IOVAL_OFF]
	mov r8, 1
	mov r9, 100
	call W32_WaitOnAddress
	jmp .lp
	
.continue:
	mov al, dil		; byte to send
	mov ah, 255		; set flag
	xchg ah, al
	mov [rbx+0], ax		; send the byte
	popthing rsp

	mov rsp, rbp
end_def emit
%assign where code_emit - main
%warning Emit is at byte where
	
;;; Read a single byte from the input stream and put its value on top of the stkack.
	
start_def ASM, key, "key"
	mov rbp, rsp
	sub rsp, 0x20
	and rsp, -16

	mov rbx, G_IOBUF
.lp:
	mov al, [rbx+2]		; get flag for byte available
	and al, al		; test it
	jnz .continue		; there's a byte available to read
	
	mov rax, [rbx + 2]
	mov G_IOVAL, rax
	lea rcx, [rbx + 2]
	lea rdx, [r15 + G_IOVAL_OFF]
	mov r8, 1
	mov r9, 100
	call W32_WaitOnAddress
	jmp .lp
	
.continue:
	xor eax, eax		; blank the A register
	mov al, [rbx+3]		; get the byte
	pushthing rax		; put it on the stack
	xor ax, ax		; get 16 bits of zero
	mov [rbx+2], ax		; clear the flag
	
	mov rsp, rbp
end_def key

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

start_def ASM, keyq, "key?"
	pushthing G_IOBUF
	mov rdi, [rdi]
	and rdi, 0xff0000
end_def keyq
