;;; ------------------------------------------------------------------------
;;; Some useful ways to define inline strings
;;; ------------------------------------------------------------------------

%macro InlineString 3
%strlen STRLEN %1
	lea %2, [rel $ + 9 ]
	jmp %%over
	db %1, 0
%%over:	mov %3, STRLEN
%endmacro


%macro InlineStringN 3
%strlen STRLEN %1
	lea %2, [rel $ + 9 ]
	jmp %%over
	db %1, 10, 0
%%over:	mov %3, STRLEN + 1
%endmacro
	
;;; ------------------------------------------------------------------------
;;; Preparing function calls
;;; ------------------------------------------------------------------------

%macro Call1 1	
	mov rcx, %1
%endmacro

%macro Call2 2	
	mov rcx, %1
	mov rdx, %2
%endmacro

%macro Call3 3	
	mov rcx, %1
	mov rdx, %2
	mov r8, %3
%endmacro

%macro Call4 4	
	mov rcx, %1
	mov rdx, %2
	mov r8, %3
	mov r9, %4
%endmacro

%macro Call5 5
	mov rcx, %1
	mov rdx, %2
	mov r8, %3
	mov r9, %4
	push %5
%endmacro

	

	
