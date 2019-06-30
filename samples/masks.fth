
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

  word s>n 1+ swap - 1- 
  1 swap << 1-
  $8348 w,
  $e7 c,
  c,
; immediate
