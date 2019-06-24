0 !echo

\ Implements Knuth's Comparison Counting sorting algorithm
\ TAOCP Vol. 3 (II ed), pg. 76, algorithm C

: len 16 ;

variable ii \ counter for outer loop
variable jj \ counter for inner loop

create input  503 ,  87 , 512 ,  61 , 908 , 170 , 897 , 275 , 
              653 , 426 , 154 , 509 , 612 , 677 , 765 , 703 ,
	      does> swap cells + ;

create output len cells allot does> swap cells + ;
create counts len cells allot does> swap cells + ;

: reset   len 0 do 0 i counts ! loop ;
: +count  1 swap @ counts +! ; 
: less?   2dup @ input @ >r @ input @ r> < ;
: smaller less? if nip else drop then ;
: next    -1 swap +! ;
: display cr len 0 do i output @ . loop cr ;

: inner   jj @ 0 >= if ii jj smaller +count jj next recurse then ;
: outer   ii @ 0 >= if ii @ jj ! inner ii next recurse then ;
: arrange len 0 do i input @ i counts @ 1- output ! loop ;
: sort    reset len 1- ii ! outer arrange ;

  
sort display
bye
