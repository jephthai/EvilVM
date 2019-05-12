BITS 64
default rel
global main
	
%include "defines.asm"

	section .text

main:	mov ecx, CODE_LEN
	mov rax, KEY32
base:	lea rbx, [rel $ + code - base]

loop:	ror rax, 57
	mov dh, [rbx]
	xor dh, al
	mov [rbx], dh
	inc rbx
	loop loop

%include "code.asm"
