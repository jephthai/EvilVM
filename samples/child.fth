: consume key? if key drop tail then ;

here ,file bins\mem.shellcode
16 + value mem-code
variable shmem
shmem off

loadlib api-ms-win-core-synch-l1-2-0.dll
value synch.dll

synch.dll 1 dllfun WakeByAddressAll WakeByAddressAll
synch.dll 4 dllfun WaitOnAddress WaitOnAddress

: test  mem-code shmem clone ;
: >child?  shmem 2 + c@ 0= ;  
: <child?  shmem c@ ;
: >child   shmem 3 + c! 255 shmem 2 + c!  shmem 2 + WakeByAddressAll drop ;
: <child   shmem 1+ c@ 0 shmem c! shmem WakeByAddressAll drop ;

: read-child
  consume begin 
    key? 0= while
    <child? if <child emit else 1 ms then
  repeat 
  consume
;

variable going 

: wait  begin >child? 0= key? 0= and while 1 ms repeat ;

: stream
  bounds do
    going on begin
      going @ while
      >child? if i c@ >child going off then
      <child? if <child emit going off then
      key? if consume unloop return then
    repeat
  loop
;

: interact ( -- )
  readline loadfile if
    consume
    .pre
    .s bounds do
      going on begin
        going @ while
	>child? if i c@ >child going off then
	<child? if <child emit going off then
	key? if consume unloop return then
      repeat
    loop
    ." Done loading file\n"
    .post
  then
;

: wait  begin >child? 0= key? 0= and while 1 ms repeat ;
: xmit  bounds do wait i c@ >child loop ;
: send  .pre readline stream read-child .post ;
: test  test .pre read-child .post ;
