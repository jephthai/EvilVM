\
\ Implements the LUHN verification algorithm in Evil#Forth
\
\ Works for any string plausible with length longer than 2.
\ The code keeps two function pointers in the 'digits' array
\ for processing the string's digits.
\
\ With the minor complexity of pre-swapping these pointers
\ if the number is of odd length, this seems like a nice,
\ elegant way to execute the check.
\

private

create digits 2 cells allot
variable SUM

: >num    ( char -- u )  $30 - 0 max 9 min ;
: double  ( char -- u )  >num 1 << 10 /mod + ;
: digswap ( -- )         digits dup 2@ swap rot 2! ;
: diginit ( -- )         ['] double ['] >num digits 2! SUM off ;
: init    ( -- )         diginit dup 1 and if digswap then ;
: cksum   ( char -- )    digits @ execute SUM +! digswap ;
: valid?  ( -- b )       SUM @ 10 /mod drop 0 = ;

public{

: luhn ( addr u -- b )
  dup 1 > if
    init bounds do i c@ cksum loop valid?
  else
    2drop 0
  then
;

}public
