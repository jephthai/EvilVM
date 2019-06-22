;;; ------------------------------------------------------------------------
;;; Mark words immediate, inline, etc
;;; ------------------------------------------------------------------------

start_def ASM, imm, "immediate"
	mov rax, G_THIS
	mov BYTE [rax + 8], IMM
end_def imm	

start_def ASM, inl, "inline"
	mov rax, G_THIS
	mov BYTE [rax + 8], INL
end_def inl	
	
;;; ------------------------------------------------------------------------
;;; Parse a word, convert to number if it fails
;;; ------------------------------------------------------------------------

start_def ASM, parse, "parse"
	call code_ddup		; a u a u
	call code_lookup	; a u u'
	and TOS, TOS		; test lookup (NULL pointer fails)
	jz .num			; parse as a number
	add PSP, 16		; u' 
	call code_getxt		; xt
	call code_execute	; ...
	jmp .done
.num:	call code_drop		; a u 
	call code_s_to_num
.done:	
end_def parse

;;; ------------------------------------------------------------------------
;;; Convert a string to a number
;;; ------------------------------------------------------------------------

start_def ASM, s_to_num, "s>n"
	push rbp
	mov rbx, G_BASE		; get number base
	
	xor ebp, ebp		; use ebp as a flag for negation
	mov rax, [PSP]		; get address of string
	mov al, [rax]		; get first byte
	cmp al, '-'		; compare it to a minus sign
	jne .positive		; leave the flag zero if not equal
	mov ebp, 1		; flag negative conversion for later
	inc QWORD [PSP]		; skip first char
	dec edi			; ...
	
.positive:
	;; Test for $ sigil (for hexadecimal numbers)
	mov rax, [PSP]
	mov al, [rax]		; 
	cmp al, '$'		;
	jne .base
	mov rbx, 16		; set base to hex
	inc QWORD [PSP]		; move the pointer
	dec edi			; reduce the length

.base:	xor eax, eax		; start at 0
.loop:	call code_walk		; a' u' c
	sub TOS, 0x30		; digits start here
	cmp TOS, 9		; check for bases over 10
	jle .dec		; ...
	sub TOS, 0x27		; high bases use small letters
.dec: 	and TOS, TOS		; test for negative numbers
	js .invalid		; ...
	cmp TOS, rbx		; test for digits too big
	jge .invalid 		; ...
	popthing rcx		; a' u' 
	xor rdx, rdx		; perform multiplication
	mul rbx			; ...
	add rax, rcx		; add the current digit
	test TOS, TOS		;
	jnz .loop
	call code_drop		; a'
	mov TOS, rax		; n
	jmp .done
.invalid:
	call code_ddrop
	call code_drop
	call code_err
	pop rbp
	int3
.done:

	and ebp, ebp
	jz .skipnegate
	neg TOS

.skipnegate:
	pop rbp
end_def s_to_num	

start_def ASM, reset, "reset"
	
	;; VEH clobbers r15 and r12, so they need to be recovered.  Then
	;; we can recover the initial boot state, signal error, and
	;; return to the outer interpreter.
	
	;; rcx is a pointer to an _EXCEPTION_POINTERS struct
	
	mov r15, [rcx]
	mov eax, [r15] 
	
	;; experiment: restore r15 from TIB->Env pointer
	;; see note in main.asm -- this seems like a safe place to store the
	;; value of r15 that will survive when handling an exception.
	
	mov r15, [gs:0x38]
	mov G_LASTEX, rcx	; save exception for later review
	mov rcx, [rcx + 8]	; address of context
	mov rcx, [rcx + 19 * 8]	; get old RSP
	mov rcx, [rcx]		; get actual value at top of stack
	mov G_LASTCALL, rcx	; save for reference

.skip:  mov PSP, G_PSP0		; reset parameter stack
	mov rsp, G_RSP0		; reset call stack
	call G_HANDLER		; error handler
	pushthing 250		; prevent busy loop on fail
	call code_ms		; ...
.wait:
	call code_key		; wait until server or user issues a ^W
	cmp rdi, 0x17		; check for ETB character, signaling end of last input
	je .ret			; ...
	drop			; don't fill up the stack
	jmp .wait		; ...
.ret:
	drop			; still have ETB on top, so remove it
	push QWORD G_BOOT	; force return to initial boot
end_def reset
	
start_def ASM, setboot, "!boot"
	mov G_BOOT, rdi
	call code_drop 	; drop
end_def setboot

;;; ------------------------------------------------------------------------
;;; Terminate a spate of compilation
;;; ------------------------------------------------------------------------

start_def IMM, exit, ";"
	nop
	mov rax, G_THIS		; current header
	add rax, 9		; offset of length field
	mov rbx, rax		; save location of length
	add rax, 8		; increment to name len
	xor rcx, rcx		; blank rcx
	mov cl, [rax]		; get the name length
	add rax, rcx		; find beginning of code
	inc rax			; ...
	mov rcx, G_HERE		; start at end of dictionary
	sub rcx, rax		; get code length before RET
	mov [rbx], ecx		; write length field value

	pushthing G_BOTTOM_OFF	;
	call code_dup		; test for stack underflow
	mov edi, 0xa73b4d	; Compile:
	call code_dcomma	;  cmp r12, [G_BOTTOM]
	sub QWORD G_HERE, 1	;  ...
	call code_dcomma	; ...

	pushthing 0xc3cc017e 	; compile:
	call code_dcomma	; jle 1; int3; ret

	mov rax, G_THIS		; update LAST pointer
	mov G_LAST, rax 	; ...

	;; we were called from the compiler; we pop the stored RIP off
	;; the stack, so we'll return to wherever we were before the
	;; compiler was called.
.x:	pop rax			
	call code_ddrop
end_def exit	
	
;;; ------------------------------------------------------------------------
;;; Create a header in the dictionary
;;; ------------------------------------------------------------------------

start_def ASM, header, "header"
	pushthing G_HERE 	; ( here )
.d1:	call code_dup		; ( a0 here )
	pushthing G_LAST	; ( a0 here last )
	call code_comma		; ( a0 here )
	popthing QWORD G_THIS	; ( a0 )
	pushthing ASM		; ( a0 1 )
	call code_ccomma	; ( a0 ) 
	call code_dup		; ( a0 )
	xor edi, edi		; ( a0 )
	call code_comma		; ( a0 ) write 8 bytes of zeros
end_def header	
	
;;; ------------------------------------------------------------------------
;;; The colon compiler (almost working!)
;;; ------------------------------------------------------------------------

start_def ASM, colon, ":"
	call code_header	; ( a0 )
	call code_word		; ( a0 a u )
	call code_dup		; ( a0 a u u )
	call code_ccomma	; ( a0 a u )
	
	;; write the function's name to the dictionary
.dbg0:	popthing rcx		; length of the string
	popthing rsi		; address of the string
	push rdi		; save the address (rdi is TOS)
	mov rdi, G_HERE		; tack on to dictionary
.dbg1:	rep movsb		; perform copy
	mov G_HERE, rdi		; update HERE pointer
	pop rdi
	
	;; remember where we are so ';' can update header later
.dbg2:	pushthing G_HERE	; ( a0 here )
	call code_over		; ( a0 here a0 )
	call code_minus		; ( a0 delta )
	mov rax, G_THIS		; ( a0 delta )
	add rax, 13		; ( a0 delta )
	popthing rbx		; ( a0 )
	mov [rax], ebx		; ( a0 )
	pushthing G_HERE	; ( a0 here ) 

	jmp code_compile
end_def colon

start_def ASM, compile, "compile"
	;; read words and compile them
.next:  call code_word
	and TOS, TOS
	jz .empty
	call code_ddup
	mov rax, [r12]
	mov G_LASTWORD, rax
	mov G_LASTLEN, rdi
	call code_lookup
	and TOS, TOS
	jz .num
	add PSP, 16		; nip nip
	;; get flag and check for immediacy
	mov bl, [TOS + CELL]	; get the flags field
	cmp bl, INL		; inline words thusly flagged
	je .inl			; ...
	cmp bl, IMM		; immediate words get executed, not compiled
	jne .cpl		; compile normal words
	
.imm:	call code_getxt		; get the function pointer
	popthing rax		; take it off the stack
	call rax		; call the immediate
	jmp .next		; done with this token
	
.cpl:	call code_getxt		; get execution token (function ptr)
	mov rax, G_HERE		; get current address
	sub TOS, rax		; calculate relative offset
	sub TOS, 5		; account for call instruction
	pushthing 0xe8		; op code for call
	call code_ccomma	; write the op code
	call code_dcomma	; write the address
	jmp .next		; done with this token

.inl:	call code_dup		; copy header pointer
	call code_getxt		; get the function pointer
	call code_swap		; reorder ( fn hdr )
	mov edi, [rdi + 9]	; get length from header field
	mov rsi, [r12]		; function pointer is source
	mov rcx, rdi		; length in counter register
	mov rax, rcx		; back it up to increment HERE later
	mov rdi, G_HERE		; current spot in dictionary
	rep movsb		; copy bytes
	add G_HERE, rax		; reposition HERE
	call code_ddrop		; clear stack
	jmp .next		; done with this token
	
 .num:	call code_drop		; a u 
 	call code_s_to_num
	pushthing 0x08ec8349	; make space on the stack
	call code_dcomma	; write SUB instruction
	pushthing 0x243c8949	; copy TOS to stack
	call code_dcomma	; write MOV instruction
	pushthing 0xbf		; op code for MOV instruction
	call code_ccomma	; write op code
	call code_dcomma	; write constant value
	jmp .next		; done with this token
.empty: call code_ddrop  	; ddrop
	jmp .next
.invalid:
	add PSP, 24
	mov rdi, [PSP-8]
	call code_err
end_def compile

start_def IMM, tail, "tail"
	pushthing 0xe9
	call code_ccomma
	pushthing G_THIS
	call code_getxt
	sub rdi, G_HERE
	sub rdi, 4
	call code_dcomma
end_def tail
