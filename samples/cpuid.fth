\ require named-locals.fth
\ require masks.fth

private

create name 16 allot

: cpuid    ( eax -- a b c d ) i,[ 31c031c94889f80fa24983ec18498944241049895c240849890c244889d7 ] ;
: serial   3 cpuid 32 << or nip nip ;
: basic    0 name 16 fill 0 cpuid rot name d! name 4 + d! name 8 + d! drop name .cstring ;

: vers-fields
       dup [mask] 20 28
  swap dup [mask] 16 20
  swap dup [mask] 12 14
  swap dup [mask] 8 12
  swap dup [mask] 4 8
  swap     [mask] 0 4
;  

: version  ( -- famex type model stepping )
  1 cpuid drop 2drop vers-fields

  locals famex modex type family model stepping
	 \ processor type
	 type @ case
	   0 of s" Original OEM" endof
	   1 of s" Intel Overdrive" endof
	   2 of s" Dual Processor" endof
	   3 of s" Reserved" endof
	 endcase

	 \ processor family
	 family @ dup 15 = 
	 if famex @ + then

	 \ processor model 
	 model @ family @ dup 6 = swap 16 = or 
	 if modex @ 4 << + then

	 \ processor stepping
	 stepping @
  end-locals

  ." Stepping " . ." model " . ." family " . ." type " type
;

: serial     3 cpuid 32 << or hex . dec 2drop ;
: extended1  7 cpuid hex ." EDX: 0x" . ." ECX: 0x" . ." EBX: 0x" . dec drop ;
: extended2  $80000001 cpuid hex ." EDX: 0x" . ." ECX: 0x" . dec 2drop ;

: em ( fn -- )
  +bold execute -bold
;

: b. ['] . em ;

public{

: cpuinfo
  .pre -bold
  ." Basic Info:     " ['] basic em cr
  ." Version Info:   " ['] version em cr
  ." Serial#:        " ['] serial em cr
  ." Extended Feat1: " ['] extended1 em cr
  ." Extended Feat2: " ['] extended2 em cr
  .post
;
  
}public
