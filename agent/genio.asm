start_def ASM, prompt, "prompt"
	call .b
.a:	db 27, "[32;1m ok ", 27, "[0m"
.b:	pop rax
	pushthing rax
	pushthing .b - .a
	call code_type
end_def prompt	

start_def ASM, err, "err"
	call .b
.a:	db 27, "[31;1m ? ", 27, "[0m"
.b:	pop rax
	pushthing rax
	pushthing .b - .a
	call code_type
end_def err	
	
start_def ASM, underflow, "underflow"
	call .b
.a:	db 10, 27, "[31;1mERROR! ", 27, "[7m^W ", 27, "[27m to continue", 27, "[0m", 24, 10
.b:	pop rax
	pushthing rax
	pushthing .b - .a
	call code_type
	call code_banner
	call code_prompt
end_def underflow
	
start_def ASM, close, "close"
	popthing rcx
	W32Call W32_CloseHandle
end_def close	


start_def ASM, memkey, "memkey"
	pushthing G_MEMINPUT
	mov TOS, [TOS]
	and TOS, 0xff
	inc QWORD G_MEMINPUT
end_def memkey
	
start_def ASM, cr, "cr"
	pushthing 10
	call code_emit
end_def cr	

start_def ASM, space, "space"
	pushthing 32
	call code_emit
end_def space	

start_def ASM, word, "word"
	mov rax, G_TIBB		; move the TIB up
	inc rax			; 
	xor ah, ah		; wrap at 256 chars
	mov G_TIBB, rax		; 
	mov G_TIBA, rax		; start an empty string
.loop:	
	call G_KEY
	popthing rax
	cmp al, 32
	je .done
	cmp al, 10
	je .done
	cmp al, 13
	je .done
	cmp al, 9
	je .done
	cmp al, 8
	je .bs
	mov rbx, G_TIBB
	inc QWORD G_TIBB
	mov [rbx], al
	jmp .loop
.done:  mov rbx, G_TIBA
	pushthing rbx
	mov rbx, G_TIBB
	sub rbx, TOS
	pushthing rbx
	ret
.bs:    dec QWORD G_TIBB
	jmp .loop
end_def word
