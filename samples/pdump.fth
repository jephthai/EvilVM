\ Pretty dump -- a fancier memory dump, if you find yourself looking at lots of
\ memory stuff, and your eyes glaze over.

{ ." 

pdump.fth

This sample provides an enhanced memory hexdump utility, named pdump,
for \"pretty dump\".  Its interface is identical to the builtin dump,
but it color-codes bytes for NULL, control chars, printables, and high 
bytes.  It also shows a .-replaced ASCII representation at the end 
of each row.

It's slower, and more traffic intensive because of frequent ANSI control
code sequences.  But it's also more convenient for debugging.  For a 
good example, try:

  dict @ 512 pdump

This program requires a 256-color capable ANSI terminal.

" ETX emit }!

private 
create printables 16 allot
variable total

: semi
  [char] ; emit
;

: .chan 
  semi <# # # # #> drop
;

: .256col
  ." \x1b[38;2" 
  .chan 
  .chan
  .chan
  ." m\x1b[1m"
;

: .pad ( -- )
  16 total @ - dup if 
    0 do ."    " loop
  else
    drop
  then
  total @ 8 < if space then
  space
;

: .printables ( -- )
  clear printables total @ .pad type
  total off
  cr over hex . dec 
;

: checkin ( byte -- )  
  printables total @ + c! 1 total +!
;

: print?  ( byte -- byte bool )
  dup $20 $7e within
;

: add-print ( byte -- byte ) 
  print? if dup else [char] . then checkin
;

: .byte ( byte -- byte )
  dup $10 < if $30 emit then hex . dec
;

: divis? ( num mod -- bool )
  /mod drop 0= 
;

: .color ( byte -- byte )
   dup 0=             if $60 $40 $40 .256col return then 
   dup $00 $20 within if $cc $84 $cc .256col return then
   dup $7f $ff within if $b9 $65 $37 .256col return then
                         $ff $f2 $8c .256col
;

: try-show-printables ( -- )
  total @ 16 divis? if .printables then
;

: try-qword-spaces ( -- )
  total @ 8 divis? if space then 
;

: do-a-byte ( -- byte )
  walk add-print
  .color .byte
;

public{

: pdump ( addr len -- )
  cr total off
  
  clear begin
    dup while
    try-show-printables
    try-qword-spaces
    do-a-byte
  repeat

  .printables cr 2drop
  ETX emit
;

}public
