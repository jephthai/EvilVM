: glob       globals + ; inline
: hex        16 272 glob ! ; inline
: dec        10 272 glob ! ; inline
: base       272 glob ; inline
: dict       328 glob ; inline
hex
: bottom     30 glob @ ; inline
: @key       38 glob @ ; inline
: !key       38 glob ! ; inline
: meminput   40 glob @ ; inline
: !meminput  40 glob ! ; inline
: here       58 glob @ ; inline
: !here      58 glob ! ; inline
: last       60 glob @ ; inline
: !last      60 glob ! ; inline
: this       68 glob @ ; inline
: !this      68 glob ! ; inline
: @input     78 glob @ ; inline
: !input     78 glob ! ; inline
: stdin      70 glob @ ; inline
: scratch    100 glob @ ; inline
: entrypoint 120 glob @ ; inline
: endofshell 188 glob @ ; inline
: line       170 glob ; inline
: lastword   178 glob @ 180 glob @ ; inline

: imm   immediate ; 
: -rot  rot rot ; inline
: tuck  swap over ;
: c@    @ ff and ; inline
: d@    @ ffffffff and ; inline
: ,call e8 c, here - 4 - d, ;
: lit   8ec8349 d, 243c8949 d, bf c, d, ;
: litq  8ec8349 d, 243c8949 d, bf48 w, , ;
: '     word lookup >xt ; 
: [']   ' litq ; imm
: +!    dup @ rot + swap ! ; inline
: -!    dup @ rot - swap ! ; inline
: *!    dup @ rot * swap ! ; inline
: /!    dup @ rot / swap ! ; inline
: rdrop r> r> drop >r ;
: postpone ' ,call ; imm
: [c] ' litq ['] ,call ,call ; imm
: w@    @ ffff and ;
: key   @key execute ; inline

: return c3 c, ; imm

: [0?]      8948 w, f8 c, 243c8b49 d, 8c48349 d, 2148 w, c0 c, ;
: [0branch] 840f w, here 0 d, ;
: [Nbranch] 850f w, here 0 d, ;
: [branch]  e9 c, here 0 d, ;

: -jump     here over - 4 - swap d! ;
: +jump     dup here - swap d! ;
dec

: if    [0?] [0branch] ; imm
: else  >r [branch] r> -jump ; imm
: then  -jump ; imm

: 0= 0 swap if else 1 - then ; 
: =  - 0= ;

: (
  41 key - if tail then ; imm
: \
  key dup 13 = swap 10 = or if else tail then ; imm

: recurse $e8 c, this >xt here - 4 - d, ; imm

\ Now we have comments!  This allows us to document the code
\ from here on out.

\ ------------------------------------------------------------------------
\ Break out of compiler and get back into it
\ ------------------------------------------------------------------------

hex
: [ word parse tail ; imm
: ] r> r> r> drop 2drop ; imm
dec 

\ ------------------------------------------------------------------------
\ Some more comparison operators
\ ------------------------------------------------------------------------

hex
: -1 [ 0 1 - litq ] ; inline
: < [ 3949c031 d, 980f243c d, 49c789c0 d, 4808c483 d, f7 c, df c, ] ; inline
dec

\ ------------------------------------------------------------------------
\ Hex strings to the dictionary
\ ------------------------------------------------------------------------

: hexon 16 * key 48 - 9 over < if 39 - then + ; 
: hexes 0 hexon hexon dup 0 < if drop else c, tail then ;
: i,[ hexes ; immediate
: hexes 0 hexon hexon dup 0 < if drop else lit [c] c, tail then ; 
: ,[ hexes ; immediate

\ ------------------------------------------------------------------------
\ This is a crude way to inline increments and decrements
\ ------------------------------------------------------------------------

: 1-   i,[ 48ffcf ] ; inline
: 1+   i,[ 48ffc7 ] ; inline
: r@   i,[ 4983ec0849893c24488b3c24 ] ; inline
: >r   i,[ 57498b3c244983c408 ] ; inline
: r>   i,[ 4983ec0849893c245f ] ; inline
: 2>r  i,[ 5741ff3424498b7c24084983c410 ] ; inline
: 2r>  i,[ 4983ec1049897c2408418f04245f ] ; inline
: 2r@  i,[ 4983ec1049897c2408488b042449890424488b7c2408 ] ; inline
: 2@   i,[ 4983ec08488b0749890424488b7f08 ] ; inline
: 2!   i,[ 498b042448894708498b442408488907498b7c24104983c418 ] ; inline
: 2*   i,[ 48d1e7 ] ; inline
: 2/   i,[ 48d1ef ] ; inline

\ ------------------------------------------------------------------------
\ some more memory operators
\ ------------------------------------------------------------------------

: w!   i,[ 498b0424668907 ] ; inline

\ ------------------------------------------------------------------------
\ yet more comparisons with efficient hex compilation
\ ------------------------------------------------------------------------

: not i,[ 48f7d7 ] ; inline
: xor i,[ 49333c244983c408 ] ; inline
: neg i,[ 48f7df ] ; inline
: >=  i,[ 31c049393c240f99c089c74983c408 ] neg ; inline
: >   1+ >= ; inline
: <=  1+ < ; inline
: <>  i,[ 31c049393c24400f95c74983c40848 ] neg ; inline 
: =   i,[ 31c049393c240f94c089c74983c408 ] neg ; inline
: 0=  i,[ 31c04821ff0f94c089c7 ] neg ; inline
: <<  i,[ 498b0c244887f948d3e74983c408 ] ; inline
: >>  i,[ 498b0c244887f948d3ef4983c408 ] ; inline
: within >r over <= swap r> <= and ;
: incr i,[ 48ff07 ] drop ; inline
: decr i,[ 48ff0f ] drop ; inline

: depth $30 glob @ psp - $10 - 3 >> ; inline

\ ------------------------------------------------------------------------
\ Comparisons continue
\ ------------------------------------------------------------------------

: min  2dup < if drop else nip then ; inline
: max  2dup < if nip else drop then ; inline

\ ------------------------------------------------------------------------
\ Hacky inlining for experimenting with optimization
\ ------------------------------------------------------------------------

: mem,     \ copy region to end of dictionary
  dup if
    1- >r 
    dup c@ c,
    1+ r> tail
  else
    2drop
  then ;

: @word  word lookup dup >xt swap cell + 1+ @ 65535 and ;
: [i]    @word mem, ; imm

: see    word lookup dup >xt swap cell + 1+ d@ 11 + dump ;

\ ------------------------------------------------------------------------
\ Counted loops
\ ------------------------------------------------------------------------

hex
\ push TOS; push [PSP]; add r12, 16; mov rdi, [r12-8]
: do ,[ 5741ff34244983c410498b7c24f8 ] here
; imm

\ inc [rsp+8]; mov rax, [rsp]; cmp rax, [rsp+8]; jl
: loop
  ,[ 48ff442408488b0424483b4424080f8f ]
  here - 4 - d,     \ jump target
  5858 w,           \ pop rax; pop rax
; imm

: unloop r> r> r> 2drop >r ;

\ sub r12, 8; mov [r12], rdi; mov rdi, [rsp+_] 
: #r@ ( c -- )
  ,[ 4983ec0849893c24488b7c24 ] c,
;   

: i   8 #r@ ; imm
: j  18 #r@ ; imm
: k  28 #r@ ; imm
: l  38 #r@ ; imm
: m  48 #r@ ; imm
dec

\ ------------------------------------------------------------------------
\ disassemble functions
\ ------------------------------------------------------------------------

: .raw   8 0 do dup 255 and emit 8 >> loop drop ;
: disas  2 emit 1 emit over .raw dup .raw type ;
: seeasm word lookup dup >xt swap cell + 1+ d@ 11 + disas 3 emit ;

\ ------------------------------------------------------------------------
\ Non counted loops
\ ------------------------------------------------------------------------

: begin  0 here ; imm
: while  nip [0?] [0branch] swap ; imm
: until  nip [0?] [Nbranch] swap ; imm
: repeat 233 c, here - 4 - d, dup if -jump else drop then ; imm

\ ------------------------------------------------------------------------
\ any language without case statements sucks
\ ------------------------------------------------------------------------

\ get the address and length of the inline body of a function
: body dup 9 + d@ over 13 + d@ rot + swap ;

\ make an immediate word inline a specified word
: [i]     word lookup body swap litq litq [c] mem, ; immediate

: case    [i] >r [i] r@ 0 ; immediate
: of      [i] = [0?] [0branch] [i] r> [i] drop ; immediate
: endof   >r >r [branch] r> 1+ r> -jump [i] r@ ; immediate
: endcase [i] r> [i] drop 0 do -jump loop ; immediate

\ ------------------------------------------------------------------------
\ Space allocation
\ ------------------------------------------------------------------------

: safehere? dup dict @ dup $168 glob @ + within ;
: allot     here + safehere? if !here else [ $cc c, ] then ;

\ ------------------------------------------------------------------------
\ Variables and create / does>
\ ------------------------------------------------------------------------

: final 
  this !last    \ update dictionary head pointer
  last 17 + dup c@ + 1+ >r ( r: code )
  here r@ - ( dcode r: code )
  last 9 + d!
  r> last - last 13 + d! 
  drop
;
  
: variable
  header word dup c, mem, here 19 + litq 
  final 195 c, 0 , 
  5 this 8 + c! \ mark variables "inline"
; 

: create variable
	 1 this 8 + c! \ mark regular (can't be inline!)
	 here 17 - dup @ 16 + ( jmp ptr' )
	 swap ! 8 allot ;
hex
: does> here last >xt 12 + ( here *ret )
	e9 over d! 1+      ( here addr )
	here over - 4 -    ( addr delta )
	swap d!            ( ) 
	here
;

: [does] [c] does> [branch] here swap ; immediate
: [;]    ,call postpone ; ;
: [;]    c3 c, -jump litq [c] [;] ; immediate

: does> does> compile ;
dec

: off   0 swap ! ; inline
: on    0 1- swap ! ; inline

: value header word dup c, mem, swap litq
	 final 195 c, 0 ,
	 1 this 8 + c! ;

: to
  word lookup dup 13 + d@ + 10 + !
;

: [to]
  word lookup dup 13 + d@ + 10 + litq 
  ['] ! ,call ; immediate

\ : value create , [does] @ [;] ;

\ ------------------------------------------------------------------------
\ Start hiding words in the dictionary
\ ------------------------------------------------------------------------

variable SKIP
variable START


: private last SKIP ! ;
: public  SKIP @ last ! ;
: public{ here START ! ;
: }public SKIP @ START @ ! ;

\ ------------------------------------------------------------------------
\ Strings! (note, compilation only, no interpreter strings!)
\ ------------------------------------------------------------------------

: [char] key lit ; imm

private
: escape key dup [char] n = 
	 if drop 10 
	 else dup [char] x = if
		drop 0 hexon hexon 
	      then
	 then ;

: ," key dup [char] " = if 
       drop 
     else dup 92 = if drop escape then
	  c, 1+ tail 
     then ;

public{

: " here 23 + litq [branch]  \ compile address and jump
    0 ," >r 0 c,              \ collect and count chars
    here over - 4 - swap d!    \ place jump target
    r> lit                      \ write string length    
; imm


: s" postpone " ; imm 

: ." postpone " [c] type ; imm

}public

\ ------------------------------------------------------------------------
\ Assembling strings in scratch space
\ ------------------------------------------------------------------------

variable precision 100 precision !

: zero     over + swap do 0 i c! loop ;
: pad      here 8192 + ; inline
: nl?      dup 10 = swap 13 = or ;
: tack     >r over r> swap c! >r 1+ r> 1+ ;
: \0term   2dup + 0 swap c! ;

: white?   
  case
    32 of -1 endof
    10 of -1 endof
    13 of -1 endof
    9  of -1 endof
    drop 0
  endcase ;

private
: readline key dup nl? if drop 0 tack nip 1- else tack tail then ;
: walk     over c@ >r >r 1+ r> 1- r> ;
: 0term    2dup + 0 swap c! ;
: rtrim    dup c@ white? if 1- tail else over - then ;

public{

: readline pad dup >r 0 readline r> swap ;
: ltrim    walk white? if tail else >r 1- r> 1+ then ;
: rtrim    over + 1- rtrim 1+ 0term ;
: trim     ltrim rtrim ;
: f.       precision @ /mod . 8 emit 46 emit . ;

}public

\ ------------------------------------------------------------------------
\ Some better output functions
\ ------------------------------------------------------------------------

variable out#
variable out@
variable orig

: spaces  dup 1 >= if 0 do space loop else drop then ;
: <#      pad out@ ! out# off ; inline
: hold    1 out# +! 1 out@ -! out@ @ c! ; 
: adj     dup 10 < if 48 else 87 then + ; 
: #       base @ /mod >r adj hold r> ;
: #s      dup if # tail then drop ;
: #s      dup if #s else 48 hold drop then ;
: #>      out@ @ out# @ type ;
: sign    0 < if [char] - hold then ;
: abs     dup 0 < if -1 * then ;
: .       dup abs <# 32 hold #s sign #> ;
: .depth  ." \x1b[35;1m" depth . ." \x1b[0m" ;
: .r      >r dup abs <# #s sign #> r> out# @ - spaces ;
: .>r     >r dup abs <# #s sign r> out# @ - 0 do 32 hold loop #> ;
: .byte   hex <# 2 0 do # loop #> dec ;

: bounds  over + swap ;
: page    ." \x1b[2J" ;
: at-xy   ." \x1b[" 0 .r ." ;" 0 .r ." H" ;
: save-xy ." \x1b[s" ;
: load-xy ." \x1b[u" ;
: cls     page 0 0 at-xy ;


: r.type ( addr u len -- )
  over - >r type 
  r> dup 0 > if spaces else drop then
;

\ ------------------------------------------------------------------------
\ String comparisons (since those show up pretty often)
\ ------------------------------------------------------------------------

: equal 0 ;
: less -1 ;
: more  1 ;

private

variable caser

: next ( a1 a2 -- a1' a2' )
  >r 1+ r> 1+ ;

public{

: downcase ( c -- c' )
  dup [char] A [char] Z within if 32 + then ;

: ci<> ( a1 a2 -- flag )
  over c@ downcase over c@ downcase - dup if dup abs / then ;

: c<> ( a1 a2 -- flag )
  over c@ over c@ - dup if dup abs / then ;

: strcmp ( a1 u1 a2 u2 -- flag )
  rot 2dup 2>r min 0 do
    caser @ execute
    dup -1 = if unloop unloop nip nip return then 
    dup  1 = if unloop unloop nip nip return then
    drop next
  loop
  2drop 2r> swap - dup if dup abs / then ;

: stricmp ['] ci<> caser ! strcmp ;
: strcmp  ['] c<>  caser ! strcmp ;

}public

\ ------------------------------------------------------------------------
\ A better stack viewer
\ ------------------------------------------------------------------------

private
: .sN 0 do 8 - dup @ . loop drop dup . ;
: .sN psp depth cells + 8 - depth 1- 1- .sN ;
: .s  depth 1 = if dup . else .sN then ;
: .s  depth 0 > if .s then ;
: .s  depth <# [char] ) hold #s #> space .s cr ;
: .s  ." \x1b[32;7m PSP(" .s ." \x1b[0m" ;
public

: clear-stack begin depth while drop repeat ;

\ ------------------------------------------------------------------------
\ Lists - a Lisp-inspired list interface
\ ------------------------------------------------------------------------

variable CELLPOOL 0 CELLPOOL !

\ Conservative List API:
\
\ We start with no available cons cells, and allocate them in the
\ dictionary.  But later, when a list is reclaimed (free-list), its
\ cons cells are added to a list of available cells, which becomes the
\ preferred source of new ones.  In this way, the system only ever
\ uses the number of cells occupied at the maximum extent of list
\ utilization.  A well-written program could then run in constant
\ memory, despite using dictionary- allocated linked lists
\ continuously over time.

: ()       0 ;
: car      8 + @ ;
: cdr      @ ;
: cdr!     ! ;
: car!     8 + ! ;

: recons ( car cdr -- cell )
  CELLPOOL @ dup cdr CELLPOOL ! >r r@ cdr! r@ car! r> ;

: cons ( car cdr -- cell )
  CELLPOOL @ if recons else here >r , , r> then ;

: uncons ( cell -- )
  CELLPOOL @ over cdr! CELLPOOL ! ;

: free-list ( list -- )
  dup if dup cdr >r uncons r> tail then drop ;

: map!     dup if 2dup car swap execute over car! cdr tail then 2drop ;
: each     dup if 2>r 2r@ car swap execute 2r> cdr tail then 2drop ;
: nth      swap dup if 1- swap cdr tail then drop dup if car -1 else drop 0 then ;

private
: reverse  over dup if car swap cons >r cdr r> tail then drop ;
: reverse  () reverse nip ;
public

private
: length   dup if >r 1+ r> cdr tail then drop ;
: length   0 swap length ;
public

private
: map ( xt lst -- lst' )
  dup if 
    dup car -rot cdr recurse
    >r swap over execute r> cons
  then ;

: map map nip ;
public

\ left fold is startlingly elegant, and its incantation rolls off the tongue

: foldl ( xt x0 lst -- x )
  dup if >r >r dup r> r@ car rot execute r> cdr tail then drop nip ;

\ ------------------------------------------------------------------------
\ Quotations so crazy they just might work (anonymous words)
\ ------------------------------------------------------------------------

private

\ Allow throw-away quotations to restore the dictionary pointer
variable BACKUP

public{

\ this version works in the outer interpreter
: { here dup BACKUP ! compile ; immediate
: } $c3 c, r> drop ; immediate

\ a variant for compiling quotations into words
: '{ [branch] here compile ; immediate
: }' >r $c3 c, -jump r> litq r> drop ; immediate

\ if you run it immediately, we can throw it away
: }! $c3 c, execute r> drop BACKUP @ !here ; immediate

}public

\ ------------------------------------------------------------------------
\ Output words for prettier I/O
\ ------------------------------------------------------------------------

\ reverse video on / off
: +rev  ." \x1b[7m" ;
: -rev  ." \x1b[27m" ;

\ bold on / off
: +bold ." \x1b[1m" ;
: -bold ." \x1b[22m" ;

\ conceal / reveal
: +vis  ." \x1b[28m" ;
: -vis  ." \x1b[8m" ;

\ ANSI color codes
: red     ." \x1b[31;1m" ;
: green   ." \x1b[32;1m" ;
: yellow  ." \x1b[33;1m" ;
: blue    ." \x1b[34;1m" ;
: magenta ." \x1b[35;1m" ;
: cyan    ." \x1b[36;1m" ;
: white   ." \x1b[37;1m" ;
: gray    ." \x1b[37;21m" ;
: clear   ." \x1b[0m" ;
: normal  ." \x1b[39m" ;

\ ------------------------------------------------------------------------
\ The FFI, wrapping calls to C functions (samples/ffi.fth for example)
\ ------------------------------------------------------------------------

private
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

: dllfun create >r readline trim drop getproc here >r , r> r>
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
public

\ ------------------------------------------------------------------------
\ Some time and random number functions
\ ------------------------------------------------------------------------

kernel32 1 dllfun GetLocalTime GetLocalTime
kernel32 2 dllfun SystemTimeToFileTime SystemTimeToFileTime
kernel32 2 dllfun FileTimeToSystemTime FileTimeToSystemTime

create SYSTEMTIME 32 allot
variable FILETIME

private

: dash  [char] - emit ;
: colon [char] : emit ;
: dot   [char] . emit ;
: zeros dup 1 >= if 0 do 48 hold loop else drop then ;
: 0#s   >r out# @ >r #s out# @ r> - r> swap - zeros ;

public{

: time 
  SYSTEMTIME GetLocalTime drop 
  SYSTEMTIME FILETIME SystemTimeToFileTime drop 
  FILETIME @ 10000 / ;

: @time SYSTEMTIME dup GetLocalTime drop ;

: .time
  8 0 do dup w@ swap 2 + loop drop
  <# 
  32 hold
  3 0#s 46 hold \ ms
  2 0#s 58 hold \ seconds
  2 0#s 58 hold \ minutes			       
  2 0#s 32 hold \ hours
  2 0#s 45 hold \ day
  drop
  2 0#s 45 hold \ month
  4 0#s         \ year
  #>
;

\ convert time units to milliseconds
: seconds 1000 * ;
: minutes 60 * seconds ;
: hours   60 * minutes ;
: days    24 * hours ;

}public

\ ------------------------------------------------------------------------
\ A very simple random number generator (good for 16-bit numbers)
\ ------------------------------------------------------------------------

19789 variable seed seed !

: rand     1337 seed @ * 3909 + 298332 /mod drop dup seed ! ;
: /rand    rand 3 >> swap /mod drop ;

\ ------------------------------------------------------------------------
\ Heap allocation
\ ------------------------------------------------------------------------

kernel32 0 dllfun GetProcessHeap GetProcessHeap
kernel32 3 dllfun HeapAlloc HeapAlloc
kernel32 3 dllfun HeapFree HeapFree
kernel32 4 dllfun HeapReAlloc HeapReAlloc
kernel32 3 dllfun HeapValidate HeapValidate

variable allocs () allocs !

private

GetProcessHeap value procheap

: record dup allocs @ cons allocs ! ;

public{

: align    64 here 64 /mod drop - allot ;
: allocate procheap 0 rot HeapAlloc record ;
: free     procheap 0 rot HeapFree drop ;
: free?    dup >r procheap 0 rot HeapValidate if r> free else rdrop then ;
: realloc  2>r [ GetProcessHeap litq ] 0 2r> HeapReAlloc ;
: fill     over + swap do dup i c! loop drop ;

: move ( from to count -- )
  0 do over c@ over c! >r 1+ r> 1+ loop 2drop ;

}public

\ ------------------------------------------------------------------------
\ Ability to reset the dictionary to a former state
\ ------------------------------------------------------------------------

private

variable MARKHERE
variable MARKLAST
variable MARKTHIS
variable MARKCELLS

public{

: mark   
  here MARKHERE ! 
  last MARKLAST !
  this MARKTHIS !
  CELLPOOL @ MARKCELLS !
;

: forget 
  MARKHERE @ !here
  MARKLAST @ !last
  MARKTHIS @ !this
  MARKCELLS @ CELLPOOL !
;

}public

\ ------------------------------------------------------------------------
\ Enhanced error handling stuff
\ ------------------------------------------------------------------------

: indict? ( addr -- bool )
  dict @ here within 
;

: inword ( addr -- addr u )
  dup indict? if
    last begin
      dup while
      2dup > if
	nip >name return
      then
      @
    repeat
  else
    entrypoint endofshell within if
      s" shellcode"
    else
      s" UNKNOWN"
    then
  then ;

private

\ if 'here' is corrupted, we can *maybe* fix it by going to the last
\ defined word, calculating its extent, and resetting the 'here'
\ pointer.  (note, the "11 +" is because the length field doesn't
\ include ":"'s postamble)

: fixhere
  last dup >xt swap cell + 1+ @ 65535 and 11 + + !here 
;

kernel32 2 dllfun IsBadReadPtr IsBadReadPtr

: ptr? ( addr -- bool )
  8 IsBadReadPtr if 0 else -1 then
;

: .value  +bold hex . dec -bold cr ;
: .word   +bold type -bold cr ;

public{

: .exception
  red 250 ms

  +bold ." \nInput State:\n"
  line @ -bold   ." Line Number:      " +bold . -bold cr
  lastword -bold ." Last word:        " .word

  +bold ." \nContext:\n"
  here safehere? 0= if
    ." Fixing 'here'; dictionary may be inconsistent now!" fixhere 
  then

  $150 glob @ 8 + @ ( *CONTEXT )
  dup ptr? if
    dup 248 + @  -bold ." Exception RIP:    " .value
    dup 248 + @  -bold ." In word:          " inword .word
    $160 glob @  -bold ." Last call:        " inword .word
    dup 152 + @  -bold ." Exception RSP:    " .value
    -bold ." Context PTR:      " .value
    cr +bold ." Exception Record:\n"
    $150 glob @ @ ( *EXCEPTION_RECORD )
    dup d@ -bold       ." Exception Code:   " .value
    dup 4 + d@ -bold   ." Exception Flags:  " .value
  else
    ." Context invalid, no exception info available\n"
  then

  drop +bold clear
  underflow
;

}public

\ set the exception handler to the pretty printing version
' .exception $158 glob !

: reset-lines 1 line ! ;

\ ------------------------------------------------------------------------
\ Stuff that should be there
\ ------------------------------------------------------------------------

: entry  engine 1 = if 1 !echo @input close stdin !input then ;
entry
