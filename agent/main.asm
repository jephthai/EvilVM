BITS 64
default rel
global main
section .text

;;; ------------------------------------------------------------------------
;;; Definitions that describe and govern configuration of the Forth machine
;;; ------------------------------------------------------------------------
	
%define CELL     8              ; bytes in a forth CELL
%define PSP      r12		; register for top of the stack
%define TOS      rdi		; store top of stack in a register for efficiency
%define W        r14		; a slush register for the forth machine

%define ASM      1		; some words are machine code
%define CODE     2		; some are Forth definitions
%define IMM      4		; immediate words aren't compiled
%define INL      5		; inline words for optimization

%define TIBSZ     128 		; bytes in the TIB
%define SCRATCHSZ 0x10000	; 64KB for TIB, PAD, etc.
%define STACKSZ   0x10000	; 64KB for the stack
%define DICTSZ    0x400000	; 4MB for the dictionary
%define SHADOW    0x20		; Silly x64 ABI

%include "table.asm"	 	; Definitions for global variables / addresses
%include "utilities.asm"        ; Utilities for svelte code

;;; ------------------------------------------------------------------------
;;; Bootstrapping is so ugly, I hide it in these two files
;;; ------------------------------------------------------------------------

mark_boot:	
%include "bootstrap.asm"	; Find PEB and load essential global variables
mark_functions:	
%include "functions.asm"        ; Load the important Win32 functions
mark_stacks:	
%include "stacks.asm"
mark_defns:	
%include "defns.asm"

;;; ------------------------------------------------------------------------
;;; Now we can write a program using the Win32 API
;;; ------------------------------------------------------------------------

init:
	lea rax, [ rel $ + 9 ]	; Get RIP at this spot
	jmp save		;
	
save:   sub rax, save - main	; find entry point for shellcode
	mov G_ENTRY, rax	; save as global variable for reference
	
	mov G_RSP0, rsp
	mov G_PSP0, r12
	
	sub rsp, 0x20
	mov ecx, -11
	call W32_GetStdHandle
	mov G_STDOUT, rax
	
	mov ecx, -10
	call W32_GetStdHandle
	mov G_STDIN, rax
	mov G_INPUT, rax

	xor ecx, ecx		; NULL address
	mov edx, STACKSZ	; space for parameter stack
	mov r8d, 0x3000		; allocation type
	mov r9d, 0x40		; protection flags
	call W32_VirtualAlloc	; ...
	mov G_STACK, rax
	
	add rax, STACKSZ - 0x100 ; safety buffer for detecting overflow
	mov G_BOTTOM, rax
	mov PSP, rax

	xor ecx, ecx		; NULL address
	mov edx, DICTSZ		; space for dictionary
	mov G_DSIZE, edx	; save this for introspection
	mov r8d, 0x3000		; allocation type
	mov r9d, 0x40		; protection flags
	call W32_VirtualAlloc	; ...
	mov G_DICT, rax
	mov G_HERE, rax

	xor ecx, ecx		; NULL address
	mov edx, SCRATCHSZ	; size of scratch space
	mov r8d, 0x3000		; allocation type
	mov r9d, 0x40		; protection flags
	call W32_VirtualAlloc	; ...
	add rsp, 0x20		; remove shadow space
	
	mov G_SCRATCH, rax
	add rax, 0x100
	mov G_TIB, rax		; TIB buffer space
	add rax, TIBSZ		; TIB space
	mov G_TIBA, rax		;
	mov G_TIBB, rax		;
	mov rax, TIBSZ		; 
	mov G_TIBN, rax 	;

	mov eax, 10
	mov G_BASE, rax		; current base for numerical representation
	
	xor eax, eax		;
	dec eax			;
	mov G_ECHO, rax		; Variable controlling whether input is echo'd
	
	mov rax, link
	mov G_LAST, rax
	mov G_THIS, rax

	lea rax, [ rel $ + 9 ]	; Get RIP at this spot
	jmp core		; 
core:   mov G_INIT, rax         ; and store it for relative offsets from init
	jmp postinit

;;; ------------------------------------------------------------------------
;;; Now we have globals, we can define the default dictionary
;;; ------------------------------------------------------------------------

%ifdef ADDCRYPTO
	%include "crypto/spritz.asm" ; some crypto routines
%endif
	%include "genio.asm" 	  ; Contains defs common to all IO layers

%ifdef IONET	
	%include "io/net.asm"	  ; TCP transport network layer
%endif
	
%ifdef IOWININET
	%include "io/wininet.asm" ; WININET http transport
%endif

%ifdef IOSTD
	%include "io/io.asm"	  ; STDIO/STDOUT streams IO layer
%endif
	
%ifdef IOMEM
	%include "io/memory.asm" ; shared memory IO layer
%endif

mark_core:	
%include "core.asm"	
mark_compiler:	
%include "compiler.asm"

postinit:
	mov rax, link		; reset LAST link
	mov G_LAST, rax		; ...
	
	;; We need to move the dictionary to the read/write/execute space
	;; that we allocated above so we can update LINK pointers to
	;; valid memory addresses (they are offsets from "core" up to now)

	push TOS
	mov rsi, G_INIT		  ; dictionary starts at RIP-relative core
	mov rdi, G_DICT		  ; we allocated write/exec dictionary space
	mov rcx, postinit - core  ; size of the core dictionary
	rep movsb		  ; ...
	mov G_HERE, rdi
	pop TOS
	
	;; Now we need to update the addresses for LINK pointers

	mov rsi, G_LAST		; last LINK offset
	mov TOS, G_DICT
	mov rbx, TOS		; core dictionary base address
	add rbx, rsi		; add LINK offset
	mov G_LAST, rbx		; update LAST pointer in global variable
	
update:	mov rcx, [rbx]		; get LINK offset
	add rcx, TOS		; add base address
	xchg rcx, [rbx]		; swap it out to memory
	mov rbx, rcx		; update dictionary header ptr
	add rbx, TOS		; ...
	loop update		; loop until we get to a 1-offset

	xor ecx, ecx		; loop screws up the NULL pointer
	mov [rbx + 0x0b], rcx	; so we fix it here

;;; ------------------------------------------------------------------------
;;; Environment is set up, dictionary exists, "main" code follows
;;; ------------------------------------------------------------------------

	sub rsp, 0x20
	mov ecx, 0xffff		 ; avoid error reporting
	call W32_SetErrorMode    ; ...

	;; Experiment -- store r15 in TIB->Env pointer
	;; 
	;; This is better than trying to make 'reset' extract the value of r15
	;; from the structured exception struct.  If all exceptions happened
	;; in Evil#Forth code, that would actually be fine.  But since they
	;; can also happen in a Win32 DLL, then the r15 that gets restored may
	;; be some invalid value.  I experimented with several places -- the
	;; arbitrary data pointer in the TEB would be ideal, but I'm already
	;; using that for memory-resident code when spawned as a thread.  So
	;; after some experimentation, I realized that TEB->Environment is not
	;; a field that's in use.  Or at least, it's always NULL as far as I
	;; can see, and it's not used for the actual environment... 
	
	mov [gs:0x38], r15
	
	pushthing code_reset - main
	add rdi, G_ENTRY
	mov rdx, rdi
	popthing G_RESET
	xor ecx, ecx
	;inc ecx
	call W32_AddVectoredExceptionHandler
	add rsp, 0x20

	pushthing code_key - main
	add rdi, G_ENTRY
	popthing G_KEY

	pushthing code_underflow - main
	add rdi, G_ENTRY
	popthing G_HANDLER

boot:	call code_initio
	
	;; It's good to send some unpredictable data right away so all
	;; phones home don't look the same
	push rbp
	mov rbp, rsp
	sub rsp, 0x20
	and rsp, -16
	call W32_GetTickCount	; ticks since boot
	pushthing rax		;
	call code_dot		;
	pushthing G_HERE	; this was allocated randomly
	call code_dot		;
	pushthing [gs:0x40]	; process ID
	call code_dot		;
	pushthing [gs:0x40]	; thread ID
	call code_dot
	mov rsp, rbp
	pop rbp

	call code_banner
	call code_echooff
	call code_cr
	xor eax, eax
	mov G_ECHO, rax

%ifndef IONET
	call .b
	db "core.fth", 0
.b:	pop rcx
	mov edx, 0x80000000
	mov r8, 1
	xor r9d, r9d
	sub rsp, 0x40		; paragraph alignment is important
	mov QWORD [rsp+0x30], 0	; ...
	mov QWORD [rsp+0x28], 0	; ...
	mov QWORD [rsp+0x20], 3	; ...
	call W32_CreateFileA	; ...
	add rsp, 0x40		; ...
	xor ebx, ebx
	cmp rax, rbx
	jle .nocore
	mov G_INPUT, rax
%endif	
	
.nocore:
	mov rax, [gs:0x28]	; get the arbitrary data slot value
	mov G_MEMINPUT, rax	; save it in the memory input pointer

.noparam:
	mov G_RSP0, rsp
	mov G_PSP0, PSP
	
	;; +N to skip the mov at .a, so we don't get a bizarre
	;; infinite loop on a second exception
	lea rax, [rel $ + 13 ]
	jmp .a
.a:	mov G_BOOT, rax
	
	mov rax, end - main	; store last byte in shellcode too
	add rax, G_ENTRY	; as offset from entrypoint
	mov G_EOS, rax		; store in global
	
	;; This is the outer interpreter
	
aloop:	call code_word
	and TOS, TOS
	jz .c2
	mov rax, [r12]
	mov G_LASTWORD, rax
	mov G_LASTLEN, rdi
	call code_parse
	jmp aloop
.c2:	ddrop
	jmp aloop

end:	nop
%warning Max global table index: offset
%assign  len end - main
%warning Size len

%assign  len mark_functions - mark_boot
%warning From boot to functions: len bytes

%assign  len mark_stacks - mark_functions
%warning From functions to stacks: len bytes

%assign  len mark_defns - mark_stacks
%warning From stacks to defns: len bytes

%assign  len init - mark_defns
%warning From defns to init: len bytes

%assign  len mark_core - init
%warning From init to core: len bytes

%assign  len mark_compiler - mark_core
%warning From core to compiler: len bytes

%assign  len postinit - mark_compiler
%warning From compiler to postinit: len bytes

%assign  len end - postinit
%warning From postinit to end: len bytes

