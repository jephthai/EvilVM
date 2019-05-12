\ an attempt to make local variables for wusses

\ first, create some space for local stack frames
8192 allocate value local-stack

\ this is the location and size of current stack frame
variable local-top   local-stack local-top !
variable local-base  local-stack 1024 + local-base !
variable local-count local-count off

\ allocate a stack frame with indicated number of variables
: locals ( n -- )
  cell local-top +!  \ add new frame length to stack
  dup local-top @ !   \ store size of the new frame
  cells local-base +!  \ move frame pointer
;

\ reclaim stack frame
: exit-locals ( -- )
  local-top @        \ get size of current frame
  cells local-base -! \ move the frame pointer
  cell local-top -!    \ pop frame from local stack
;

\ write to a local var by ID
: loc! ( v n -- )
  cells local-base @ + ! ;

\ read from a local var by ID
: loc@ ( n -- v )
  cells local-base @ + @ ;

\ ------------------------------------------------------------------------
\ Examples
\ ------------------------------------------------------------------------

: box-size ( w h d -- vol surf edges )
  6 locals
    2 loc! \ the depth
    1 loc!  \ the height
    0 loc!   \ the width

    \ calculate volume
    0 loc@ 1 loc@ 2 loc@ * * 3 loc!

    \ calculate surface area
    0 loc@ 1 loc@ * 2 *
    0 loc@ 2 loc@ * 2 * +
    1 loc@ 2 loc@ * 2 * + 4 loc!

    \ calculate edge length
    0 loc@ 4 *
    1 loc@ 4 * +
    2 loc@ 4 * + 5 loc!

    \ leave results on stack
    3 loc@ 4 loc@ 5 loc@
  exit-locals
;
