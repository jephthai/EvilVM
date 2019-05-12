\ An attempt to make general parsers in Evil#Forth

\ The parsing engine needs its own stack to keep track of progress
\ through a candidate string.  Some operations push info on this
\ stack, others use information stored there.

create p-stack 128 cells allot
variable p-top p-stack p-top !

\ we push things on the stack two cells at a time
: p-push ( a b -- )  16 p-top +! p-top @ 2! ;
: p-@ ( -- a b )     p-top @ 2@ ;
: p-drop ( -- )      16 p-top -! ;

\ head gets the next character to process in the parse
: head ( addr u -- addr u c ) over c@ ;

\ advance moves a string some number of characters
: advance ( addr u u -- addr' u' )
  >r swap r@ + swap r> - 0 max
;

\ test-match evaluates after a list of matches
: test-match
  if advance then
;

\ parser ... end-parser processes a list of parsers

variable options
variable concats

: parser 
  [c] 2dup [c] p-push options off concats off
; immediate

: n-jumps ( * addr -- )
  >r begin r@ @ while
    -jump 1 r@ -!
  repeat
  rdrop
;

\ end-parser is an immediate word that patches in all the
\ jumps from option clauses

: end-parser
  \ if we matched, don't reset the string, otherwise, rewind
  [c] dup [0?] [Nbranch]
  [c] nip [c] nip
  [c] p-@ [c] rot

  -jump
  
  \ patch in the jumps from successful options or failed concats
  concats n-jumps
  options n-jumps

  \ no longer need to remember current starting point on the parser stack
  [c] p-drop
; immediate

\ the '|' word tests success of a parsing option, and jumps if there's
\ a match

: |
  \ if we matched, skip the rest of the options
  [c] dup [0?] [Nbranch] 
  1 options +! 

  \ patch in jumps from the concatenations
  >r concats n-jumps r>
  
  \ reset to beginning of the current string (back tracking)
  [c] drop [c] 2drop [c] p-@
; immediate

\ the '&' word allows you to concatenate together consecutive parsers
\ to match text in sequence

: &
  \ if we didn't match, jump to the next option or the end
  [c] dup [0?] [0branch] 1 concats +!

  \ the next concatenation should not see the boolean result
  [c] drop
; immediate


: me  this >xt litq [c] execute ; immediate

: extract ( a u a u -- )
  drop nip over -
;

\ ------------------------------------------------------------------------
\ Some useful fundamental parsers
\ ------------------------------------------------------------------------

: EOS    dup 0= ;
: digit  walk $30 $39 within ;
: lower  walk [char] a [char] z within ;
: upper  walk [char] A [char] Z within ;
: ascii  walk 0 127 within ;

: printable walk 32 126 within ;

: whitespace
  dup 0= if -1 else
    walk case
      9  of -1 endof
      10 of -1 endof
      13 of -1 endof
      32 of -1 endof
      drop 0
    endcase
  then
;
  
