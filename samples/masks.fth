
\ A library for compiling masks more efficiently and succinctly

\ This will read ahead two numbers and compile the following code:
\
\   shr rdi, [low]
\   and rdi, 2 ** [high] - 1

: [mask] ( num [low] [high] -- field )
  word s>n dup
  $c148 w,
  $ef c,
  c,

  word s>n 1+ swap - dup

  8 >= if
    \ a 32-bit mask
    1- 1 swap << 1-
    $8148 w,
    $e7 c,
    d,
  else
    \ an 8-bit mask or smaller
    1- 1 swap << 1-
    $8348 w,
    $e7 c,
    c,
  then

; immediate
