start_def ASM, engine, "engine"
	pushthing 1		; 1 is the stdin/stdout engine
end_def engine	
	
start_def ASM, initio, "initio"	
	push 1			      ; make space on stack for the result
	Call2 G_STDOUT, rsp	      ; get mode for STDOUT console handle
	W32Call W32_GetConsoleMode    ; ...
	pop rax			      ; get the mode
	or rax, 4		      ; set the VT processing bit
	Call2 G_STDOUT, rax	      ; reset the mode
	W32Call W32_SetConsoleMode    ; ...
end_def initio

start_def ASM, echooff, "-echo"	
	push 1			      ; make space on the stack for the result
	Call2 G_STDIN, rsp	      ; get the mode
	W32Call W32_GetConsoleMode    ; ...
	pop rax			      ; kill the mode bits for line buffering / echo
	and rax, ~6		      ; clear the line buffering and echo bits
	Call2 G_STDIN, rax	      ; reset the mode
	W32Call W32_SetConsoleMode    ; ...
end_def echooff

start_def ASM, echoon, "+echo"	
	push 1
	Call2 G_STDIN, rsp
	W32Call W32_GetConsoleMode
	pop rax
	or rax, 6
	Call2 G_STDIN, rax
	W32Call W32_SetConsoleMode
end_def echoon

start_def ASM, setecho, "!echo"	
	popthing QWORD G_ECHO
end_def setecho	

start_def ASM, emit, "emit"
	push rcx
	mov rcx, G_STDOUT	; first param is the stream HANDLE
	push rdi		; need to put the char somewhere in memory
	mov rdi, [PSP]		; complete popping char off data stack
	add PSP, 8		; ...
	mov rdx, rsp		; second param is address of 'string'
	mov r8, 1		; print only one character
	mov r9, r15		; place to save # bytes written
	push QWORD 0		; final parameter, no flags
	sub rsp, SHADOW		; shadow space
	call W32_WriteFile	; ...
	add rsp, 0x30		; fix stack
	pop rcx
end_def emit

start_def ASM, key, "key"
	push QWORD 0
	mov rdx, rsp
	push QWORD 0
	mov rcx, G_INPUT
	mov r8, 1
	mov r9, r15
	sub rsp, SHADOW
	call W32_ReadFile
	pushthing [rsp+0x28]
	and rdi, 0xff
	add rsp, 0x30
	cmp BYTE G_ECHO, BYTE 0
	jz .done
	cmp TOS, 0x0d
	jne .skip
	inc QWORD G_LINENO
	call code_prompt
	call code_cr
	ret
.skip	cmp TOS, 0x04
	je .done
	call code_dup
	call code_emit
.done:	
end_def key	

start_def ASM, type, "type"	
	push rcx
	mov rcx, G_STDOUT	; write to stdout HANDLE
	mov r8, rdi		; how many bytes to write
	mov rdx, [PSP]		; address of string
	mov rdi, [PSP+8]	; pop off the two values from data stack
	add PSP, 0x10		; ...
	mov r9, r15		; WriteFile reports # bytes written
	push 0			; keep stack paragraph aligned
	push 0			; no flags
	sub rsp, SHADOW		; shadow space
	call W32_WriteFile	; ...
	add rsp, 0x30		; fix stack
	pop rcx
end_def type	
