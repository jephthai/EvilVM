\ require parsers.fth
\ require strings.fth

\ try to split strings using parsers
: sep      parser EOS | whitespace & me | whitespace end-parser ;
: content  parser whitespace not & me | sep          end-parser ;
: field    parser sep & content | content            end-parser ;

variable fields

: finalize ( addr u -- list )
  2drop 
  fields @ reverse
  fields @ free-list
;

: add-field ( addr u addr u -- )
  >r >r drop r@ 
  over - trim String fields @ cons fields !
  r> r>
;

\ splits a string on consecutive whitespace
: split ( addr u -- list )
  fields off begin
    dup while
    2dup field drop add-field
  repeat
  finalize
;

