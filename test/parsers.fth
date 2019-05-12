\ require parsers.fth

{ ." 

parsers.fth - demonstration of simple parsing library.
" }!

{ ." \nPARSER RESULT  MS  TEXT\n"
    ." ------ ------  --  ----\n"
}!

\ I want to support Unicode and ASCII, so we'll redefine walk to work with either
' walk value walk-fn
: walk-unicode  over w@ >r >r 2 + r> 2 - r> ;
: walk-ascii    walk ;
: walk          walk-fn execute ;
: unicode       ['] walk-unicode [to] walk-fn ;
: ascii         ['] walk-ascii   [to] walk-fn ;

\ ------------------------------------------------------------------------
\ Match credit card numbers, maybe with matching separators
\ ------------------------------------------------------------------------

variable sepchar

: EOS       dup 0 = ;
: digit     walk $30 $39 within ;
: digits    0 do digit not if unloop 0 return then loop -1 ;
: <>digit   digit not ;
: sentinel  walk [char] ; = ;
: sep1      walk sepchar ! -1 ;
: sepN      walk sepchar @ = ;

: term
  parser
    EOS | <>digit
  end-parser
;

: cc#-sep
  parser
    4 digits & sep1 & 4 digits & sepN & 4 digits & sepN & 4 digits
  end-parser
;

: cc#-lang
  parser
    cc#-sep   & term  |
    16 digits & term  |
    sentinel  & digit & digit & me
  end-parser
;

: cc#-lang
  parser
    ascii cc#-lang | unicode cc#-lang
  end-parser
  ascii
;

\ ------------------------------------------------------------------------
\ Now test it on some expressions
\ ------------------------------------------------------------------------

: success  green ."  SUCCESS " clear ;
: failure  red   ."  failure " clear ;
: match    nip nip if success else failure then ;

: test 
  ." PAN?: " readline 2dup 
  time >r cc#-lang match time r> - 4 .r 
  type cr
;

' walk-unicode to walk-fn

test 4111-1111-1111-1111
test 4111-1111-1111-11111
test 4111-1111 1111-1111
test 4111111111111111=
test ;011234567890123445=724724100000000000030300XXXX040400099010=**
test 4111111111111111
test 41111111111111111
test 411111111A111111
test 411111111111111

\ ------------------------------------------------------------------------
\ An attempt at a simple arithmetic expression parser
\ ------------------------------------------------------------------------

\ math operators
: operator
  walk case
    [char] + of -1 endof
    [char] * of -1 endof
    [char] - of -1 endof
    [char] / of -1 endof
    [char] % of -1 endof
    drop 0
  endcase
;

\ some symbol literals
: lpar  walk [char] ( = ;
: rpar  walk [char] ) = ;
: term  walk [char] a [char] z within ;

\ mutual recursion requires some acrobatics
0 value opfn
: expr'  opfn execute ;

\ parsers
: expr
  parser
    expr' & EOS | expr' & operator & me | expr'
  end-parser ;

: expr'  [ here to opfn ]
  parser
    term & operator & expr | lpar & expr & rpar | term 
  end-parser ;

: math  parser expr & EOS end-parser ;

\ ------------------------------------------------------------------------
\ Now test it on some expressions
\ ------------------------------------------------------------------------

: test 
  ." MATH?:" readline 2dup 
  time >r math match time r> - 4 .r 
  type cr
;

test a
test a+b
test a+b++
test a+b+c+d+e
test Z
test (a+(c-)b
test (a+b)
test a*(b+c)
test ((a+b)*(c+d))
test (a+b)*(c+d)*(e+f)*(g+h)
test ((((a+b)+(c+d))+(e+f)*(g+h)))
test ((((a+b)+(c+d))+(e+f)*(g+h))
test ((((a+b)+(c+d)+((e+f)*(g+h)))
test ((((a+b)+(c+d))z(e+f)*(g+h)))
test ((((((((((b))))))))))
test aaaa
test (a+b)ZZZZ
 
cr ETX emit
