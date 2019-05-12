;;; ------------------------------------------------------------------------
;;; Stack manipulators
;;; ------------------------------------------------------------------------

start_def INL, dup, "dup"
	dup
end_def dup

start_def INL, drop, "drop"
	drop
end_def drop

start_def INL, nip, "nip"
	nip
end_def nip

start_def INL, swap, "swap"
	swap
end_def swap

start_def ASM, tor, ">r"
	pop rax
	to_r
	push rax
end_def tor

start_def ASM, rfrom, "r>"
	pop rax
	r_from
	push rax
end_def rfrom

start_def ASM, rat, "r@"
	pushthing [rsp + 8]
end_def rat
	
start_def INL, ddup, "2dup"
	ddup
end_def ddup

start_def INL, ddrop, "2drop"
	ddrop
end_def ddrop

start_def INL, over, "over"
	over
end_def over	

start_def INL, rot, "rot"
	xchg TOS, [PSP]
	xchg TOS, [PSP+8]
end_def rot	
	
start_def INL, fetch, "@"
	mov TOS, [TOS]
end_def fetch
	
start_def INL, store, "!"
	mov W, [PSP]
	mov [rdi], W
	add PSP, CELL * 2
	xchg rdi, [PSP - CELL]
end_def store

start_def INL, cstore, "c!"
	mov eax, [PSP]
	mov BYTE [rdi], al
	mov rdi, [PSP+CELL]
	add PSP, CELL * 2
end_def cstore

start_def INL, dstore, "d!"
	mov eax, [PSP]
	mov [rdi], eax
	mov rdi, [PSP+CELL]
	add PSP, CELL * 2
end_def dstore

start_def INL, cell, "cell"
	pushthing 8
end_def cell	

start_def INL, cells, "cells"
	shl TOS, 3
end_def cells	
	
start_def INL, getname, ">name"
	add rdi, 17
	xor eax, eax
	mov al, [TOS]
	inc rdi	
	pushthing rax
end_def getname

;;; ------------------------------------------------------------------------
;;; DLLs and function pointers
;;; ------------------------------------------------------------------------
	
start_def INL, kernel32, "kernel32"
	pushthing KERNEL32_BASE
end_def kernel32

start_def ASM, gpa, "getproc" 	; ( dll cstr -- a )
	mov rcx, [PSP]
	mov rdx, rdi
	add PSP, 8
	W32Call W32_GetProcAddress
	mov rdi, rax
end_def gpa	

;;; ------------------------------------------------------------------------
;;; Constants / compiler state variables
;;; ------------------------------------------------------------------------
	
start_def INL, psp, "psp"
      pushthing PSP
end_def psp
      
start_def INL, globals, "globals"	
	pushthing r15
end_def globals	
	
;;; ------------------------------------------------------------------------
;;; Basic math operations
;;; ------------------------------------------------------------------------
	
start_def INL, plus, "+"
	add TOS, [PSP]
	add PSP, CELL
end_def plus

start_def INL, minus, "-"
	xchg TOS, [PSP]
	sub TOS, [PSP]
	add PSP, CELL
end_def minus

start_def INL, mul, "*"
	mov rax, [PSP]
	imul TOS
	mov TOS, rax
	add PSP, CELL
end_def mul	

start_def INL, divmod, "/mod"
	mov rax, [PSP]
	xor edx, edx		
	cqo
	idiv TOS
	mov TOS, rax
	mov [PSP], rdx
end_def divmod	

start_def ASM, div, "/"
	call code_divmod
	nip
end_def div

start_def INL, and, "and"
	and TOS, [PSP]
	add PSP, CELL
end_def and
	
start_def INL, or, "or"
	or TOS, [PSP]
	add PSP, CELL
end_def or
	
;;; ------------------------------------------------------------------------
;;; Counted string comparison
;;; ------------------------------------------------------------------------
	
;;; 40 bytes
start_def ASM, compare, "compare" 
%push bob			  ;
	add PSP, CELL * 3	  ; clear the stack
	cmp TOS, [PSP - 2 * CELL] ; check if lengths differ
	jne .fail		  ; fail if so
	mov rsi, [PSP - CELL]	  ; string 1
	mov rdi, [PSP - 3 * CELL] ; string 2
	mov rcx, [PSP - 2 * CELL] ; count
	repe cmpsb		  ; find non-matching bytes
.test:  jz .succ		  ;
.fail:	xor edi, edi		  ; return 0
	ret			  ;
.succ:  xor edi, edi		  ; return -1
	dec edi			  ;
%pop bob	
end_def compare

;;; ------------------------------------------------------------------------
;;; Given a counted string, find the dictionary entry with that name
;;; ------------------------------------------------------------------------
	
start_def ASM, lookup, "lookup"
	push TOS
	push QWORD [PSP]
	call code_ddrop
	pushthing G_LAST

.words:	call code_dup		; stack: last last 
	call code_getname	; stack: last a u
	pushthing [rsp]		; stack: last a u a'
	pushthing [rsp + CELL]	; stack: last a u a' u' 
	call code_compare	; stack: last b
	popthing rax		; stack: last
	test eax, eax		; stack: last
	jnz .succ		; stack: last 
.fetch: mov TOS, [TOS]		; stack: last'
	test TOS, TOS		; loop if pointer isn't NULL
	jnz .words		; ...
	xor edi, edi		; failed, return NULL
.succ:  add rsp, 0x10		; fix stack frame
end_def lookup

;;; ------------------------------------------------------------------------
;;; get XT from dictionary entry
;;; ------------------------------------------------------------------------

start_def INL, getxt, ">xt"
	mov eax, [TOS+13]
	add TOS, rax
end_def getxt

start_def INL, execute, "execute"
	xchg rax, rdi
	mov rdi, [r12]
	add r12, 8
	call rax
end_def execute

;;; ------------------------------------------------------------------------
;;; Enumerate the contents of the dictionary
;;; ------------------------------------------------------------------------

start_def ASM, words, "words"
	pushthing G_DICT	; Searching through the dictionary...
	pushthing G_LAST	; Start at the last definition
words:	call code_dup		; traverse the dictionary
	call code_getname	; ...
	call code_type		; print the names
	call code_space		; space delimited
	call code_fetch		; next name
	test edi, edi		; check for 0 as final link pointer
	jnz words
	call code_ddrop
	call code_cr
end_def words
	
;;; ------------------------------------------------------------------------
;;; Exit the program immediately
;;; ------------------------------------------------------------------------

start_def ASM, bye, "bye"
	xor ecx, ecx
	W32Call W32_ExitThread
end_def bye
	
;;; ------------------------------------------------------------------------
;;; Print out a value on the stack
;;; ------------------------------------------------------------------------

;;; OPTIMIZE

start_def ASM, dot, "."	
	push rsi
	push rcx
	push rbx
	push rdx
	push rax
	
	popthing rax
	mov rsi, G_SCRATCH
	add rsi, 0x100
	xor ecx, ecx
	mov rbx, G_BASE	
	
.lp:	xor edx, edx
	div rbx
	add dl, 0x30
	cmp dl, 0x39
	jle .dec		; check for non-numeric values
	add dl, 0x27		; bump up to the alphabet if not decimal
	
.dec:	mov [rsi], dl
	dec rsi
	inc rcx
	and rax, rax
	jnz .lp

	inc rsi
	pushthing rsi
	pushthing rcx
	call code_type
	call code_space
	
	pop rax
	pop rdx
	pop rbx
	pop rcx
	pop rsi
end_def dot	
	
;;; ------------------------------------------------------------------------
;;; A really crude hexdump function
;;; ------------------------------------------------------------------------

start_def ASM, dump, "dump"
	popthing rcx		; counter
	popthing rbx		; base address
	mov rax, G_BASE		; save old numeric base
	push rax		; ...
	mov rax, 16		; set to hex for a hex dump (duh)
	mov G_BASE, rax		; ...
	xor eax, eax		; store bytes in A register
	mov esi, eax		; track offset from starting address
	
.loop:  and rsi, 0xf		; every 16 bytes go to another line
	jnz .mid		; otherwise, skip
	call code_cr		; new line
	pushthing rbx		; print current address
	call code_dot		; ... 
	call code_space		; ...
	
.mid:	mov al, [rbx]		; get a byte
	inc rbx			; increment counters
	inc rsi			; ...
	pushthing rax		; get ready to print its value
	test dil, 0xf0		; if it's small, we need a leading 0
	jnz .2dig		; ...
	pushthing 0x30		; ...
	call code_emit		; ...
	
.2dig:	call code_dot		; print the value
	loop .loop		; repeat
	
	pop rax			; restore old numeric base
	mov G_BASE, rax		; ...
	
	call code_cr
end_def dump   
       
;;; ------------------------------------------------------------------------
;;; System banner 
;;; ------------------------------------------------------------------------

start_def ASM, banner, "banner"
	call .b
.a:	db 27, "[35;1mEvil#", 27, "[36;1mForth", 27, "[0m", 10
.b:	pop rax
	pushthing rax
	pushthing .b - .a
	call code_type
end_def banner


;;; ------------------------------------------------------------------------
;;; Extract one byte from a memory region, and advance the pointer
;;; ------------------------------------------------------------------------

start_def ASM, walk, "walk" 	; ( a u -- a+1 u-1 c )
	push rax
	call code_over
	xor eax, eax
	mov al, [TOS]
	mov TOS, rax
	dec QWORD [PSP]
	inc QWORD [PSP + CELL]
	pop rax
end_def walk

;;; ------------------------------------------------------------------------
;;; Store data in the dictionary
;;; ------------------------------------------------------------------------

start_def INL, comma, ","
	mov rax, G_HERE
	add qword G_HERE, 8
	mov [rax], rdi
	mov rdi, [r12]
	add r12, 8
end_def comma	

start_def INL, ccomma, "c,"
	mov rax, G_HERE
	inc qword G_HERE
	mov [rax], dil
	mov rdi, [r12]
	add r12, 8
end_def ccomma
	
start_def INL, wcomma, "w,"
	mov rax, G_HERE
	add qword G_HERE, 2
	mov [rax], di
	mov rdi, [r12]
	add r12, 8
end_def wcomma

start_def INL, dcomma, "d,"
	mov rax, G_HERE
	add qword G_HERE, 4
	mov [rax], edi
	mov rdi, [r12]
	add r12, 8
end_def dcomma

;;; ------------------------------------------------------------------------
;;; Sleep for indicated number of milliseconds
;;; ------------------------------------------------------------------------

start_def ASM, ms, "ms"
	popthing rcx
	W32Call W32_Sleep
end_def ms
