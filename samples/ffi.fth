' getproc value getproc-fn

\ make shadow space and call the address in TOS

: shadowcall ,[ 4883ec20ffd74883c4204889c7 ] ; 

\ Set up the registers in the right order for calling Win32
\ functions. 

hex
: call1 ,[ 4889f9498b3c244983c408 ] drop  ; \ pop TOS into rcx
: call2 ,[ 4889fa498b3c244983c408 ] call1 ; \ pop TOS into rdx
: call3 ,[ 4989f8498b3c244983c408 ] call2 ; \ pop TOS into r8
: call4 ,[ 4989f9498b3c244983c408 ] call3 ; \ pop TOS into r9
dec

\ until the remaining args are 4 in number, compile pop/push
\ instructions to put extra args on the stack

: callN dup 4 = if call4 else ,[ 57498b3c244983c408 ] 1- tail then ;

\ Compiles code for setting up registers and the stack for the
\ Windows 64-bit calling convention.  It takes in the number
\ of parameters and calls the correct setup function.  Since
\ callN handles 5+ params, it clamps the input at 5.

create callreg ' drop , ' call1 , ' call2 , ' call3 , ' call4 , ' callN ,
does> swap 5 min cells + @ execute ;

: compile-c-call
       >r here >r , r> r>
       ,[ 515241504151 ] \ save registers
       ,[ 4889e5 ]  \ mov rbp, rsp
       ,[ 4883e4f0 ]  \ and esp, -0x10 ; paragraph-align the stack

       \ an odd number of args needs stack alignment
       dup 4 - 2 /mod drop 0 max if ,[ 50 ] then
       \ dup 2 /mod drop if ,[ 50 ] then 

       dup dup callreg \ set up args for calling convention
       swap litq       \ put address of function on stack
       ,[ 488b3f ]     \ mov rdi, [rdi]   ; dereference the pointer
       shadowcall      \ call the function
       ,[ 4889ec ]     \ mov rsp, rbp     ; restore the stack
       drop            \ don't need extra copy of arg count

       ,[ 415941585a59 ] \ restore registers
       ,[ c3 ]         \ compile a return
       [does] 8 + execute [;] ;

: dllfun create >r readline trim drop getproc-fn execute r> compile-c-call ;
