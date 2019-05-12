;;; ------------------------------------------------------------------------
;;; We will be making some space for a table of global variables 
;;; ------------------------------------------------------------------------
	
%define GLOBAL_SPACE 0x240
%define KERNEL32_BASE       [ r15 + 0x008 ]
%define KERNEL32_NAMES      [ r15 + 0x010 ]	
%define KERNEL32_FNS        [ r15 + 0x018 ]	
%define KERNEL32_ORDS       [ r15 + 0x020 ]	
%define W32_GetProcAddress  [ r15 + 0x028 ]

%assign offset 0x30
	
%macro DefGlobal 2
%xdefine %1_OFF %2
%xdefine %1 [ r15 + %2 ]
%endmacro

;;; ------------------------------------------------------------------------
;;; Define a bunch of runtime global variables for compiler state
;;; ------------------------------------------------------------------------
	
DefGlobal G_BOTTOM,   0x30	; bottom of the data stack
DefGlobal G_KEY,      0x38	; function pointer for reading a byte from input stream
DefGlobal G_MEMINPUT, 0x40	; pointer to current location for compiling from memory
DefGlobal G_BOOT,     0x48	; boot pointer for error handler to reset
DefGlobal G_RESET,    0x50	; function pointer to reset state on error
DefGlobal G_HERE,     0x58	; next available byte in dictionary
DefGlobal G_LAST,     0x60	; last defined word in dictionary
DefGlobal G_THIS,     0x68	; current word definition in dictionary
DefGlobal G_STDIN,    0x70	; process's actual standard input stream handle
DefGlobal G_INPUT,    0x78	; handle for input with default IO
DefGlobal G_TIB,      0x80	; beginning of the TIB
DefGlobal G_TIBA,     0x88	; start of unused TIB
DefGlobal G_TIBB,     0x90	; last read char in TIB
DefGlobal G_TIBN,     0x98	; length of the TIB
DefGlobal G_SCRATCH,  0x100	; pointer to unmanaged scratch space in memory
DefGlobal G_ECHO,     0x108	; flag to echo input to output
DefGlobal G_BASE,     0x110	; numeric base for IO
DefGlobal G_INIT,     0x118	; offset to core API during initialization
DefGlobal G_ENTRY,    0x120	; entrypoint to the shellcode
DefGlobal G_RSP0,     0x128	; save boot-time call stack pointer for reset
DefGlobal G_PSP0,     0x130	; save boot-time data stack pointer for reset
DefGlobal G_STDOUT,   0x138	; process's actual standard output stream handle
DefGlobal G_STACK,    0x140	; base of the data stack
DefGlobal G_DICT,     0x148	; base of the dictionary
DefGlobal G_LASTEX,   0x150	; pointer to last exception
DefGlobal G_HANDLER,  0x158	; exception handler pointer
DefGlobal G_LASTCALL, 0x160 	; last call on stack at exception
DefGlobal G_DSIZE,    0x168     ; size of the initial dictionary as allocated
DefGlobal G_LINENO,   0x170	; for counting lines 
DefGlobal G_LASTWORD, 0x178	; last word read by interpreter
DefGlobal G_LASTLEN,  0x180 	; last word length
DefGlobal G_EOS,      0x188	; end of shellcode in memory
	
;;; From now on, we'll tack on more globals in macros, and keep track
;;; of the offsets using this variable.  This is handy for optional code
;;; (such as alternative IO layers) so that they can create usable global
;;; variable slots without having to keep track of indexes manually.

%assign offset 0x190

%macro AddGlobal 2
%xdefine %1_OFF offset
%xdefine %1 [ r15 + offset ]
%assign offset offset + 8
	mov %1, %2
%endmacro
