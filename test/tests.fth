0 !echo cr

\ word names for lookup during tests
: "setup" " setup" lookup >xt ;
: "unit"  " unit" lookup >xt ;
: "check" " check" lookup >xt ;
: pass    ." [36;1m+[0m" ;     \ better hope you speak utf8
: fail    ." [31;1mx[0m" ;
: sep     ." [36m  | [0m" ;

\ a number too big for 32-bits
: big   5678901234 ;
: big2  5678901235 ;
: cols           4 ;

cols 1 - variable count count !

variable good
variable bad 
variable start
variable end

: inc       dup @ 1+ swap ! ;
: none      0 ;
: more      ;
: less      0 swap - ;
: pass      pass good inc ; 
: fail      fail bad inc ;
: clear     depth if drop tail then ;
: pad       12 swap - 0 do space loop ;
: tabulate  count @ cols /mod drop if sep else cr then ;

: test ( effect -- )
  count inc tabulate
  word swap over type pad  \ Print the test name padded to 12 chars
  >r                        \ save the expected stack effect
  "setup" execute            \ find "setup" and run it
  depth start !               \ record the starting stack depth
  "unit" execute               \ find "unit" and run it
  depth start @ - r> =          \ check the stack effect
  if pass else fail then         \ and report status
  space "check" execute           \ find "check" and run it
  if pass else fail then           \ report whether check function worked
  clear                             \ clear the tack to 0 depth
  ;

\ ------------------------------------------------------------------------
\ Tests Ensue
\ ------------------------------------------------------------------------

: setup ;
: unit  ;
: check 1 less ;
none test good-check

: setup 1 ;
: unit  2 = ;
: check ;
none test fail-check

: setup ;
: unit  ;
: check 1 ;
1 test fail-effect

: setup ;
: unit  ;
: check 0 ;
4 test fail-both

0 bad !
0 good !

: setup 2 ;
: unit  dup ;
: check 2 = ;
1 more test dup

: setup 99 7 ;
: unit  drop ;
: check 99 = ;
1 less test drop

: setup 1 2 3 ;
: unit  nip ;
: check + 4 = ;
1 less test nip

: setup 1 2 ;
: unit  swap ;
: check 1 = >r 2 = r> and ;
none test swap

: setup 2 ;
: unit  >r r@ r@ r> ;
: check + + 6 = ;
2 more test r-funs

: setup 1 2 ;
: unit  2dup ;
: check 2 = swap 1 = and swap 2 = and swap 1 = and ;
2 more test 2dup

: setup 1 2 3 ;
: unit  2drop ;
: check 1 = ;
2 less test 2drop

: setup 1 2 ;
: unit  over ;
: check 1 = swap 2 = and swap 1 = and ;
1 more test over

: setup 1 2 3 ;
: unit  rot ;
: check 1 = swap 3 = and swap 2 = and ;
none test rot1

: setup 1 2 3 ;
: unit  rot rot rot ;
: check 3 = swap 2 = and swap 1 = and ;
none test rot2

create x big , 
: setup x ;
: unit  @ ;
: check big = ;
none test fetch

create x 47 ,
: setup 22 x ;
: unit  ! ;
: check x @ 22 = ;
2 less test store

hex create x ff000000ff ,         \ make sure to test that it only
: setup 5c5c x ;                   \ sets 32-bits and won't disturb
: unit  d! ;                        \ the high side of a cell-size
: check [ ff00005c5c litq ] x @ = ;  \ integer.
2 less test dstore dec

: setup ;
: unit  cell ;
: check 8 = ;
1 more test cell

: setup 19 ;
: unit  cells ;
: check 152 = ;
none test cells

create string 98 c, 97 c, 110 c, 110 c, 101 c, 114 c, does> 6 ;
: setup [ word banner lookup litq ] ;
: unit  >name ;
: check string compare ;
1 more test >name

: setup ;
: unit  kernel32 ;
hex : check d@ 905a4d = ; dec
1 more test kernel32

: setup 47 ;
: unit  psp ;
: check @ 47 = ;
1 more test psp

: setup 47 ;
: unit  depth 22 depth ;
: check rot - 2 = ;
3 more test depth

: setup 22 ;
: unit  bottom ;
: check depth cells - @ 22 = ;
1 more test bottom

: setup big , 27 , ;
: unit  here ;
: check dup cell - @ 27 = swap 2 cells - @ big = and ;
1 more test here

: setup here dup 32 + ;
: unit  !here ;
: check here swap - 32 = ;
1 less test !here

: setup ;
: unit  this last ;
: check = ;
2 more test this-last

: setup kernel32 ; \ the second global is the kernel32 base address
: unit  globals ;
: check 8 + @ = ;
1 more test globals

: setup big 1 ;
: unit  + ;
: check big2 = ;
1 less test +

: setup big2 1 ;
: unit  - ;
: check big = ;
1 less test -

: setup 47 92 ;
: unit  * ;
: check 4324 = ;
1 less test *

: setup 36 9 36 10 ;
: unit  / -rot / ;
: check 4 = swap 3 = and ;
2 less test /

: setup 26 8 ;
: unit  /mod ;
: check 3 = swap 2 = and ;
none test /mod

: setup 10 7 ;
: unit  and ;
: check 2 = ;
1 less test and

: setup 10 7 ;
: unit  or ;
: check 15 = ;
1 less test or

: setup " Berimbolo" 2dup ;
: unit  walk ;
: check [char] B = >r rot swap - 1 = >r swap - 1 = r> and r> and ;
1 more test walk

\ ------------------------------------------------------------------------
\ Some more complex functional tests
\ ------------------------------------------------------------------------

create array 1 , 2 , 3 , 4 , does> swap cells + ;
: setup ;
: unit  0 4 0 do i array @ + loop ;
: check 10 = ;
1 more test array

: setup 5 ;
: unit  dup 1 do i * loop ;
: check 120 = ;
none test fact(5)
: setup 3 ;
: check 6 = ;
none test fact(3)

: setup ;
: unit  [ 3 9 + 6 / litq ] ;
: check 2 = ;
1 more test brackets

: setup 1 2 3 ;
: unit  2 < rot 2 < rot 2 < rot ;
: check 0= rot -1 = rot 0= rot and and ;
none test <

: unit  2 >= rot 2 >= rot 2 >= rot ;
: check -1 = rot 0= rot -1 = rot and and ;
none test >=

: setup 57 ;
: unit  10 max 20 min ;
: check 20 = ;
none test clamp1
: setup 3 ;
: check 10 = ;
none test clamp2
: setup 15 ;
: check 15 = ;
none test clamp3

: setup 2 ;
: unit  3 1 do 4 1 do i j + * loop loop ;
: check 2880 = ;
none test iter

variable x 
variable y
: setup x off ;
: unit  5 x ! x @ ;
: check 5 = ;
1 more test vars

: setup 5 x ! 5 y ! ;
: unit  x off y on ;
: check x @ 0= y @ -1 = and ;
none test off/on

: setup ;
: unit  [char] A [char] ~ ;
: check 126 = swap 65 = and ;
2 more test [char] 

: setup 10 13 ;
: unit  nl? swap nl? ;
: check and ;
none test nl?

: setup s" abc" ;
: unit  walk -rot walk -rot 2drop ;
: check [char] b = swap [char] a = and ;
none test walk

: setup s" abc   " s"    abc   " ;
: unit ltrim ;
: check compare ;
none test ltrim

: setup s"    abc" s"    abc   " ;
: unit  rtrim ;
: check compare ;
none test rtrim

: setup s" abc" s"   abc   " ;
: unit  trim ;
: check compare ;
none test trim

: setup 1 2 3 () cons cons cons 0 swap ;
: unit  3 0 do dup >r car + r> cdr loop ;
: check () = swap 6 = and ;
none test c[ad]r

: setup 1 2 3 () cons cons cons ;
: unit  reverse ;
: check 3 0 do dup car swap cdr loop drop + - 0=  ;
none test reverse

: setup 1 2 3 () cons cons cons ;
: unit  1 swap nth ;
: check swap 2 = and ;
1 more test nth

: setup ;
: unit  10 0 do i dup 5 = if unloop return else drop then loop ;
: check 5 = ;
1 more test unloop

: setup 26 ;
: unit  $1a ;
: check = ;
1 more test hex-sigil-1

$ff
: setup ;
: unit ;
: check 255 = ;
none test hex-sigil-2

\ ------------------------------------------------------------------------
\ Done with the test suite
\ ------------------------------------------------------------------------

: report
  cr cr space
  good @ dup . [char] / emit space
  bad @ + . ." using " . ." bytes" cr ;

' report ' "setup" - report

{ engine 1 = if cr bye then }!
