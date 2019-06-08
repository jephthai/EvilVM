;;; Beginning of GetProcAddress in little endian hex
%define ACORPTEG 0x41636f7250746547
%define UNIxKERN 0x004e00520045004b
%define UNIxEL32 0x00320033004c0045
%define UNIx.DLL 0x004c004c0044002e
	
;;; ------------------------------------------------------------------------
;;; Macro to do a Win32 function call 
;;; ------------------------------------------------------------------------

%macro W32Call 1
	sub rsp, SHADOW
	call %1
	add rsp, SHADOW
%endmacro	

;;; ------------------------------------------------------------------------
;;; Find the PEB so we can start locating KERNEL32.DLL
;;; ------------------------------------------------------------------------
	
main:
	xor ebx, ebx		; these three instructions save a byte over one mov
	mov bl, 0x28		; indicate default I/O configuration
	mov [gs:rbx], byte 0	; stored in arbitrary data pointer
.seg:	mov bl, 0x60
	mov rbx, [gs:rbx]	; use GS as segment selector to find PEB
	mov rbx, [rbx + 0x18]	; find LoaderData pointer
	mov rbx, [rbx + 0x20]	; cursor in RBX, at second node
	jmp dllloop

;;; ------------------------------------------------------------------------
;;; An alternate entry point where a pointer to initialization data is
;;; provided as the first parameter (rcx).
;;; ------------------------------------------------------------------------
	
ioentry:
	xor ebx, ebx
	mov bl, 0x28
	mov [gs:rbx], rcx
	jmp main.seg

%assign  ioffset ioentry - main
%warning IO entrypoint is at ioffset

;;; ------------------------------------------------------------------------
;;; Find KERNEL32.DLL, which is the key to finding all other useful stuff
;;; ------------------------------------------------------------------------
	
	;; I used to find KERNEL32.DLL by looking for the total path length
	;; (since it would be c:\windows\system32\kernel32.dll, and I thought
	;; that was pretty distinctive.  But no, I ran the code one day from
	;; a program whose path length was the same, and boom, failed run.
	;; 
	;; So I thought, I'll do a string match... but sometimes KERNEL32.DLL
	;; is loaded.  Sometimes kernel32.dll is loaded.  Maybe mixed case.
	;; So this is my hacky way to do a case insensitive match.
	;;
	;; Yeah, maybe it's always the third one... but I'll take no chances.

dllloop:
	cmp byte [rbx+0x48], 24	; check length of name
	cmovne rbx, [rbx]	; update only if mismatch
	jne dllloop		; must match length first
	
	mov r13, 0xdfdfdfdfdfdfdfdf
	mov r14, UNIxKERN
	mov r15, [rbx+0x50]	; get pointer to base name
	mov r12, [r15]		; get string
	and r12, r13		; downcase it
	cmp r12, r14		; test for 'kern' in unicode
	cmovne rbx, [rbx]	; update only if bogus
	jne dllloop		; must match first half of name

	mov r13, 0xffffffffdfdfdfdf
	mov r14, UNIxEL32	;
	mov r15, [rbx+0x50]	; get pointer to next 4 of base name
	mov r12, [r15+8]	; get string
	and r12, r13		; downcase it
	cmp r12, r14		; test for 'el32' in unicode
	cmovne rbx, [rbx]	; update only if bogus
	jne dllloop		; must match second half of name

	mov r13, 0xdfdfdfdfdfdfffff
	mov r14, UNIx.DLL	;
	mov r15, [rbx+0x50]	; get pointer to last 3 of base name
	mov r12, [r15+16]	; get string
	and r12, r13		; downcase it
	cmp r12, r14		; test for '.dll' in unicode
	cmovne rbx, [rbx]	; update only if bogus
	jne dllloop		; must match extension
	
	mov rax, [rbx + 0x20]	; save base address

found:
	enter GLOBAL_SPACE, 0	; make space to store global variables
	mov r15, rsp		; index everything off of R15
	mov KERNEL32_BASE, rax	; Pointer to KERNEL32.DLL base address

;;; ------------------------------------------------------------------------
;;; Find the export table so we can lookup functions
;;; ------------------------------------------------------------------------
	
.funs:
	mov ebx, [rax + 0x3c]	; offset to PE signature
	mov ebx, [rbx+rax+0x88]	; .edata offset (export names)
	add rbx, rax		; pointer to export table
	
	mov esi, [rbx + 0x20]	; offset to names table
	add rsi, rax		; pointer to names table
	mov KERNEL32_NAMES, rsi	; save name array
	
	mov esi, [rbx + 0x1c]	; offset to function table
	add rsi, rax		; pointer to function table
	mov KERNEL32_FNS, rsi	; save function table pointer
	
	mov esi, [rbx + 0x24]   ; offset to ordinals table
	add rsi, rax		; pointer to ordinals table
	mov KERNEL32_ORDS, rsi	; save ordinal table pointer
	
;;; ------------------------------------------------------------------------
;;; Find GetProcAddressA(), so we can find functions the easy way
;;; ------------------------------------------------------------------------

getgpa:
	xor edx, edx
	dec rdx			; index into arrays
	mov rbx, ACORPTEG 	; "GetProcA" string as number
	mov rsi, KERNEL32_NAMES	; Start at the beginning of name table

gpaloop:
	inc edx			; index next entry
	mov eax, [rsi+rdx*4]	; current element in list
	add rax, KERNEL32_BASE	; offsets from start of module
	cmp [rax], rbx		; check if name matches target value
	jne gpaloop

gpafound:
	mov rsi, KERNEL32_ORDS	; address of ordinal values
	xor eax, eax		; 
	mov ax, [rsi + rdx * 2]	;
	shl eax, 2		; 
	add rax, KERNEL32_FNS	;
	mov eax, [rax]		;
	add rax, KERNEL32_BASE	; offset from start of DLL
	mov W32_GetProcAddress, rax 

