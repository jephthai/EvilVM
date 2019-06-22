\ An attempt to implement simple data structures (records or structs) in Evil#Forth.

private

variable :GETTER: 
variable :SETTER:

\ There are certain functions for accessing values smaller than
\ a register.  This function finds the right function pointers
\ based on a known field size.  This allows creating field
\ accessors that can address small, packed values.

: select-function
  case
    0 of '{ }' '{ }' endof
    1 of ['] c@ ['] c! endof
    2 of ['] w@ ['] w! endof
    4 of ['] d@ ['] d! endof
    drop ['] @  ['] !
  endcase
;

public{

: word-align 7  + $fffffff8 and ;
: para-align 15 + $fffffff0 and ;

1 value BYTE
2 value WORD
4 value DWORD
8 value QWORD
8 value PVOID
0 value STRUCT

: ARRAY ( count size )  * ;

: set
  :SETTER: @ execute ; inline

: get
  :GETTER: @ execute ; inline

: struct ( [NAME] -- offset )
  create here 0 , [does] @ [;]
  0 ;

\ compiles a field accessor that, when run, will move
\ a pointer to the proper offset and set the generic
\ GETTER / SETTER pointers

: field ( offset bytes [name] -- offset' )
  create dup select-function , , over , +
  [does]
  dup 2@ :GETTER: ! :SETTER: !
  16 + @ +
  [;]
;
  
: end-struct ( address offset -- )
  swap ! ;
  
: make ( size -- )
  >r 0 here r@ fill
  r> allot ;

: copy ( addr u dest -- ) swap move ;

}public
