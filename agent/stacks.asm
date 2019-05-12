%macro pushdown 0
	sub PSP, CELL
	mov qword [PSP], TOS
%endmacro

%macro pushthing 1
	pushdown
	mov TOS, %1
%endmacro

%macro drop 0
	mov TOS, [PSP]
	add PSP, CELL
%endmacro

%macro popthing 1
	mov %1, TOS
	drop
%endmacro

%macro nip 0
	add PSP, CELL
%endmacro

%macro dup 0
	pushdown
%endmacro

%macro swap 0
	xchg TOS, [PSP]
%endmacro

%macro to_r 0
	push TOS
	mov TOS, [PSP]
	add PSP, CELL
%endmacro

%macro r_from 0
	sub PSP, CELL
	mov [PSP], TOS
	pop TOS
%endmacro

%macro over 0	
	sub PSP, CELL
	xchg TOS, [PSP]
	mov TOS, [PSP+8]
%endmacro
	
%macro ddup 0
	dup
	mov W, [PSP + CELL]
	sub PSP, CELL
	mov [PSP], W
%endmacro

%macro ddrop 0
	nip
	drop
%endmacro

