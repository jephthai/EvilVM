
\ This is not a completely full-featured exception system.  The only mechanism
\ supported is to ensure that some code will run in the event of an error.
\ There is no resumption after an error, though, so it's not like the common
\ try ... catch ... continue idiom you'd see in other languages.
\
\ The main utility is just ensuring that resources are freed, even if an error
\ occurs during a function (e.g., closing handles, freeing buffers, etc.).
\
\ This is really experimental, so it should not be considered a canonical
\ addition to the language.
\

create hstack 16 cells allot
create rstack 16 cells allot

variable errorflag
variable htop
variable rtop

hstack htop !
rstack 8 - rtop !

: error?
  errorflag @
;

: push-handler ( addr -- )
  handler @ htop @ !
  8 htop +!
  handler !

  8 rtop +!
  () rtop !
;

: pop-handler
  8 htop -!
  htop @ @ handler !
;

: pop-resources
  rtop @ free-list
  8 rtop -!
;

: raise
  i,[ cc ]
;

: try
  0 litq here 8 - [c] push-handler [i] errorflag [i] off
; immediate

: ensure
  [branch] swap
  here swap !
  [i] errorflag [i] on
  -jump
  [c] pop-handler
; immediate

: handle-error
  errorflag @ if
    i,[ 4889f849873c244983c408ffe0 ]
  then
;

: done
  [c] pop-resources
  [c] handle-error
; immediate

variable r1
variable r2

: attempt ( code cleanup -- )
  >r execute r> rtop @ cons rtop !
;

: 0assert
  0 <> if raise then
;

: +assert
  0 < if raise then
;

: -assert
  0 > if raise then
;

: true-assert
  0= if raise then
;

: cleanup ( -- )
  rtop @ begin
    dup while
    dup car execute
    cdr
  repeat
  drop
;

: silence
  boot here - $e9 c, d,
; immediate

