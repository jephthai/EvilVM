\ require structs.fth

loadlib user32.dll
value user32.dll

user32.dll 1 dllfun GetLastInputInfo GetLastInputInfo 
kernel32 0 dllfun GetTickCount GetTickCount

struct LASTINPUTINFO
  DWORD    field cbSize
  DWORD    field dwTime
end-struct

LASTINPUTINFO allocate value lastinput
0 lastinput LASTINPUTINFO fill
LASTINPUTINFO lastinput cbSize set

: @idle
  GetTickCount lastinput GetLastInputInfo drop
  lastinput dwTime get -
;

: idle
  .pre
  -bold ." User has been idle "
  @idle
  +bold 1000 /mod 0 .r $2e emit . -bold ." seconds\n"
  .post
;

: wait-idle ( seconds -- )
  begin
    @idle over > 
    key? or until
    500 ms
  repeat
  consume
  idle
;
