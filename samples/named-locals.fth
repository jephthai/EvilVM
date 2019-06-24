\ an attempt at named locals, involves compiler magic
\
\ Notes:
\
\   ( ) There is a limited amount of local variable frame space, but calls can nest
\   ( ) Local variables involve a function call, so they're not as cheap as global variables
\   ( ) Local variable blocks CANNOT be nested within one word definition
\ 

create name-space 8192 allot

variable oldhere
variable oldlast
variable oldthis

\ first, create some space for local stack frames
create local-stack 8192 allot
\ 8192 allocate value local-stack

\ this is the location and size of current stack frame
variable local-top   local-stack local-top !
variable local-base  local-stack 1024 + local-base !
variable local-count local-count off

\ allocate a stack frame with indicated number of variables
variable varcount
: frame ( n -- )
  dup varcount !
  cell local-top +!  \ add new frame length to stack
  dup local-top @ !   \ store size of the new frame
  cells local-base +!  \ move frame pointer
  varcount @ 0 do
    local-base @ varcount @ i 1+ - cells + !
  loop
;

\ reclaim stack frame
: unframe ( -- )
  local-top @ @      \ get size of current frame
  cells local-base -! \ move the frame pointer
  cell local-top -!    \ pop frame from local stack
;

: *loc ( n -- a )
  cells local-base @ + ;

: deflocal
  create , [does] @ litq ['] . ,call [;]
;

\ NOTE this could be further optimized by inlining the call to *loc
\      but I'll leave that for another day
\
\ NOTE I'm also not sure why I can't do this a prettier way.  I may
\      need to address implementation of create / does / etc.
\
\ NOTE One reason this is so annoying is that we're compiling an
\      extension to the compiler that will create compilers for
\      local variables by name.  I guess it's not reasonable to
\      expect it to be simple.

: ,local ( n a u )
  header >r dup c, mem,

  \ deposit code for addressing a local var
  ( index )            postpone lit   ['] litq    postpone ,call
  ( *loc  ) ['] *loc   postpone litq  ['] ,call   postpone ,call
  
  r> 195 c, final
  here last - last 9 + d!
  4 last 8 + c!
;

: /word ( addr u -- addr' u' addr u )
  dup 0 do ( addr u )
    over i + c@ white? if \ found it
      over i + ( addr u a' )
      over i - ( addr u a' u' )
      rot drop ( addr a' u' )
      rot i ( a' u' addr u )
      unloop return
    then
  loop
  2dup + -rot 0 -rot 
;

create namespace 128 allot
variable localcount

: .rsp 0 i,[ 4889e7 ] hex . cr dec ;

\ make temporary dictionary space, define locals, and compile frame setup
: locals ( -- )
  \ move the dictionary to a temporary spot
  here oldhere !
  last oldlast !
  this oldthis !
  name-space !here 

  \ compile some local variable compilers
  localcount off
  namespace @readline trim 
  begin 
    ltrim dup while
    /word ( laddr' lu' waddr wu )
    localcount @ -rot ,local  
    1 localcount +!
  repeat
  2drop
  
  \ go back to compiling the function
  oldhere @ !here                                                    

  \ functions only make a local frame if they're compiled to do so
  localcount @ litq [c] frame
; immediate

\ compile removal of the last frame
: end-locals
  [c] unframe
  oldlast @ !last
  oldthis @ !this
; immediate
