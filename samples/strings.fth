\ a basic String interface using CONS cells and dynamic memory allocation

: lower?    $61 $7a within ;
: upper?    $41 $5a within ;
: downcase  dup upper? if 32 + then ;
: upcase    dup lower? if 32 - then ;

: S.buf   ( String -- addr )           car ;
: S.len   ( String -- u )              cdr ;
: S.free  ( String -- )                dup S.buf free uncons ;
: S.open  ( String -- addr u )         dup S.buf swap S.len ;
: S.copy  ( String -- String )         dup S.open dup allocate >r r@ swap move r> swap dup >r car! r> ;
: String  ( addr u -- String )         cons S.copy ;
: S.!     ( addr u String -- String )  2dup >r 0 max r> cdr! nip car! ;

: S.head  ( String -- char )           S.buf c@ ;
: S.next  ( String -- )                dup S.open 1- >r 1+ r> rot S.! ;
: S.walk  ( String -- String' char)    dup S.head >r S.next r> ;
: S.drop  ( String u -- )              >r dup S.open r@ - swap r> + swap rot S.! ;
: S.type  ( String -- )                dup S.buf swap S.len type ;
: S.nth   ( String n -- char )         swap S.buf + c@ ;
: S.slice ( String u u -- String )     rot S.buf rot + swap cons ;
: S.eval  ( String -- )                S.open lookup >xt execute ;

: S.empty?  ( String -- bool )         S.len 0= ;
: S.unslice ( String -- )              uncons ;
: S.bounds  ( String -- a1 a0 )        S.open bounds ;
: S.inspect ( String -- )              +rev dup S.len swap S.buf . . -rev space ; 

: S.map      ( String fn -- )  dup do S.bounds do i c@ j execute i c! loop loop ;
: S.each     ( String fn -- )  dup do S.bounds do i c@ j execute loop loop ;
: S.downcase ( String -- )     ['] downcase S.map ;
: S.upcase   ( String -- )     ['] upcase   S.map ;

: S.+     ( String String -- String )
  2dup S.len swap S.len + dup >r allocate >r
  swap S.open tuck r@ swap move
  >r S.open r> r@ + swap move
  r> r> String ;

private

variable escape
variable padding
variable character
variable hexcount
variable literal

: fromhex ( char -- n ) 48 - 9 over < if 39 - then ;

: render-hex ( * char -- )
  fromhex character @ 4 << + character !
  hexcount @ 1+ dup 2 = if
    character @ emit
  else
    literal on hexcount !
  then
;

: render-literal ( * char -- )
  literal off
  case
    [char] N of 14 emit endof
    [char] O of 15 emit endof
    [char] R of ." \x1b[22m" endof
    [char] B of ." \x1b[1m" endof
    [char] b of 8 emit endof
    [char] r of 13 emit endof
    [char] t of 9 emit endof
    [char] n of cr endof
    [char] 0 of 0 emit endof
    [char] x of character off endof
    [char] \ of 92 emit endof
    render-hex
  endcase
;

: render-escape ( * char -- )
  case
    [char] d of padding @ .r escape off endof
    [char] x of hex ." 0x" padding @ .r dec escape off endof
    [char] s of S.type escape off endof
    [char] . of padding ! endof
    emit escape off
  endcase
;

: render-char ( * char -- )
  case
    [char] % of escape on padding off endof
    [char] \ of literal on endof
    emit
  endcase
;

: render ( * char -- )
  literal @ if render-literal return then
  escape @  if render-escape return then
  render-char
;

public{

: S.printf ( * String -- )  escape off literal off ['] render S.each ;

}public
