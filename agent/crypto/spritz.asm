;;; 
;;; Implement the SPRITZ-C algorithm.  Rivest published the original SPRITZ,
;;; but Subhadeep Banik and Takanori Isobe published a paper in IEICE, June
;;; 2017 describing a distinguishing attack and weak state issues in the
;;; full SPRITZ.  They then added a countermeasure which eliminates the bias
;;; in certain keystream bytes, which makes for a stronger cipher.  They
;;; called their variant SPRITZ-C, which is implemented in the code below.
;;;

%define CRYPTOSIZE 264
	
%define SN   256
%define BASE rbx
%define SI   rbx + 256
%define SJ   rbx + 257
%define SK   rbx + 258
%define SA   rbx + 259
%define SZ   rbx + 260
%define SW   rbx + 261

start_def ASM, cipher, "cipher"
	InlineString "SPRITZ-C", rax, rbx
	pushthing rax
	pushthing rbx
end_def cipher
	
start_def ASM, cryptsize, "cryptsize"
	pushthing CRYPTOSIZE
end_def cryptsize

;;; : cryptinit ( addr u state -- )
start_def ASM, cryptinit, "cryptinit"
	push rbx		; save old regs, in case
	push rsi		; ...
	popthing rbx		; rbx -> state, rdi -> length
	mov rsi, [PSP]		; put key in rsi
	call crypt_setup	; initialize the cipher state
	drop			; TOP now points to the key address
	mov rdi, rbx		; return the state pointer on stack
	pop rsi			; restore regs
	pop rbx			; ...
end_def cryptinit

;;; : encrypt ( addr u state -- )
start_def ASM, encrypt, "encrypt"
	push rbx		; save rbx in case
	popthing rbx		; ( addr u )
	mov rsi, [PSP]		; set up calling convention
	call crypt_encrypt	; do encryption
	ddrop			; clean args from stack
	pop rbx			; restore old rbx
end_def encrypt

;;; : drip ( state -- b )
start_def ASM, drip, "drip"
	push rbx		; save rbx in case
	mov rbx, rdi		; set state pointer
	call crypt_drip		; get next keystream byte in al
	mov rdi, rax		; replace state pointer with byte on stack
	pop rbx			; restore rbx
end_def drip

;;; : absorb ( state u -- )
start_def ASM, absorb, "absorb"
	push rbx		; save regs in case
	push rcx		; ...
	popthing rcx		; byte to absorb is in cl
	popthing rbx		; set state pointer
	call crypt_absorb	; ...
	pop rcx			; ...
	pop rbx			; restore regs
end_def absorb

;;; : absorb-stop ( state -- )
start_def ASM, absorbstop, "absorb-stop"
	push rbx
	popthing rbx
	call crypt_absorb_stop
	pop rbx
end_def absorbstop
	
;;; setup(len:RDI, key:RSI) -- rbx points to crypto state
crypt_setup:
	;; initialize state struct
	xor ecx, ecx		; get a zero
	mov QWORD [SI], rcx	; start all variables as 0
	mov byte [SW], 1	; 'w' initializes to 1 (keeps it odd)
	mov ecx, SN - 1		; counter
	
.lp1:	mov [BASE + rcx], cl ; set S[] array
	loop .lp1
	mov [BASE + rcx], cl	; get the last one
	mov rax, rbx		; return state pointer

	;; absorb the key
	mov ecx, edi		; counter
.lp2:	push rcx		; save counter
	mov cl, [rsi]		; get byte
	call crypt_absorb	; ...
	inc rsi			; next byte
	pop rcx			; restore counter
	loop .lp2
.eof:	ret

;;; absorb_stop()
crypt_absorb_stop:
	cmp BYTE [SA], 128	; check if we reached middle of S[]
	jne .skip		; don't shuffle if we haven't
	call crypt_shuffle	; ...
.skip:	inc BYTE [SA]		; a = a + 1
	ret

;;; absorb(byte:CL)
crypt_absorb:
	mov ch, cl		; make a copy
	and cx, 0xf00f		; mask nybbles
	call crypt_absorb_nyb	; absorb the low nybble
	shr cx, 12		; isolate high nybble
	call crypt_absorb_nyb	; absorb it
	ret

;;; absorb_nyb(nybble:CL)
crypt_absorb_nyb:
	push r8			; save regs
	push r9			; ...
	push r10		; ...
	
	xor r9, r9
	mov r8, r9
	mov r10, r9
	
	cmp BYTE [SA], 128	; check if we reached the middle of S[]
	jne .skip		; don't shuffle otherwise
	call crypt_shuffle	; ...
.skip:	mov r10b, cl		; build address
	add r10b, 128		; into second half of S[]
	add r10, rbx		; add base address
	mov r8b, [r10]		; read first byte
	mov r9b, [SA]		; 'a' offset into S[]
	xchg r8b, [BASE+r9]	; carry out swap
	mov [r10], r8b		; ...
	inc BYTE [SA]		; increment 'a'
	
	pop r10			; ...
	pop r9			; restore regs
	pop r8			; ...
	ret

;;; shuffle()
crypt_shuffle:
	push rcx
	call crypt_whip		; do the shuffle
	call crypt_crush	; ...
	call crypt_whip		; ...
	call crypt_crush	; ...
	call crypt_whip		; ...
	mov BYTE [SA], 0	; return to bottom of S[] array
	pop rcx
	ret

;;; whip()
crypt_whip:
	mov ecx, SN * 2		; lots of updates
.lp:	call crypt_update	; move stuff around
	loop .lp
	add BYTE [SW], 2	; keep it odd, so relatively prime
	ret

;;; crush()
crypt_crush:
	mov rcx, SN / 2		; counter is N / 2
	xor edx, edx		; up counter (v)
.lp:	mov r8, 256		; r8 = N
	dec r8			; r8 = N - 1
	sub r8, rdx		; r8 = N - 1 - v
	mov r10b, [BASE+r8]	; r10 = S[N - 1 - v]
	and r10, 0xff		; mask it?
	mov r9, [BASE+rdx]	; get other value (S[v])
	and r9, 0xff		; mask it too
	cmp r9, r10		; S[v] > S[N - 1 - v] ?
	jle .skip		; do nothing if <=
	xchg r10b, [BASE+rdx]	; S[v] = S[N - 1 - v]
	mov [BASE+r8], r10b	; S[N - 1 - v] = S[v]
.skip:  inc rdx
	loop .lp
.eof:	ret

;;; update()
crypt_update:
	push rcx
	push rdx
	xor ecx, ecx		; start at 0
	mov cl, [SW]		; to adjust 'i'
	add [SI], cl		; i = i + w
	mov cl, [SI]		; now get the new 'i'
	mov cl, [BASE + rcx]	; rcx = S[i]
	and ecx, 0xff		;
	add cl, [SJ] 		; rcx = j + S[i]
	mov cl, [BASE + rcx]	; rcx = S[j + S[i]]
	add cl, [SK]		; rcx = k + S[j + S[i]]
	mov [SJ], cl		; set value of 'j'
	mov cl, [BASE+rcx]	; rcx = S[j]
	and ecx, 0xff		;
	add cl, [SK]		; rcx = k + S[j]
	add cl, [SI]		; rcx = i + k + S[j]
	mov byte [SK], cl	; set value of 'k'
	mov cl, [SJ]		; rcx = j
	mov cl, [BASE+rcx]	; rcx = S[j]
	xor edx, edx		; start at 0
	mov dl, [SI]		; rdx = i
	xchg cl, [BASE+rdx]	; swap rcx and S[i]
	mov dl, [SJ]		; rdx = j
	xchg cl, [BASE+rdx]	; swap done
	pop rdx
	pop rcx
	ret

;;; drip()
crypt_drip:
	cmp BYTE [SA], 0   ; check if we're at start of S[]
	jng .skip	   ; shuffle if we are
	call crypt_shuffle ; ...
.skip:
	call crypt_update	; do an update cycle
	
	;; Now do the SPRITZ-C output function
	push rcx		; save the reg
	xor eax, eax
	xor ecx, ecx
	mov al, [SK]		; al = k
	add al, [SZ]		; al = z + k
	mov al, [BASE+rax]	; al = S[z + k]
	add al, [SI]		; al = i + S[z + k]
	mov al, [BASE+rax]	; al = S[i + S[z + k]]
	add al, [SJ]		; al = j + S[i + S[z + k]]
	mov al, [BASE+rax]	; al = S[j + S[i + S[z + k]]]
	mov cl, 255		; cl = N - 1
	sub cl, [SI]		; cl = N - 1 - i
	mov cl, [BASE+rcx]	; cl = S[N - 1 - i]
	xor al, cl		; al = z = S[j + S[i + S[z + k]]] ^ S[N - 1 - i]
	mov [SZ], al		; save this new 'z'
	and eax, 0x000000ff	; mask off any stray bits
	pop rcx
	ret

;;; encrypt(len:RDI, buf:RSI)
crypt_encrypt:			
	mov ecx, edi		; counter
.loop:	call crypt_drip		; get a byte from the keystream
	xor [rsi], al		; encrypt
	inc rsi			; next byte
	loop .loop		; ...
	xor eax, eax		; return 0
	ret
