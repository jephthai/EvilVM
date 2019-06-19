\ require pdump.fth
\ require structs.fth
\ require compress.fth

$317 value WM_PRINT
$10 value PRF_CHILDREN
$4 value PRF_CLIENT
$8 value PRF_ERASEBKGND
$2 value PRF_NONCLIENT
$20 value PRF_OWNED

$8 value HORZRES
$a value VERTRES
$cc0020 value SRCCOPY
$0 value DIB_RGB_COLORS
$1 value BI_RGB

loadlib user32.dll
value user32.dll

loadlib gdi32.dll
value gdi32.dll

user32.dll 0 dllfun GetDesktopWindow GetDesktopWindow
user32.dll 2 dllfun GetWindowRect GetWindowRect
user32.dll 1 dllfun GetDC GetDC
user32.dll 2 dllfun ReleaseDC ReleaseDC
user32.dll 4 dllfun SendMessage SendMessageA
user32.dll 4 dllfun SendNotifyMessage SendNotifyMessageA
user32.dll 1 dllfun GetCursorPos GetCursorPos

gdi32.dll  4 dllfun CreateDC CreateDCA
gdi32.dll  1 dllfun DeleteDC DeleteDC
gdi32.dll  1 dllfun CreateCompatibleDC CreateCompatibleDC
gdi32.dll  3 dllfun CreateCompatibleBitmap CreateCompatibleBitmap
gdi32.dll  2 dllfun SelectObject SelectObject
gdi32.dll  1 dllfun DeleteObject DeleteObject
gdi32.dll  2 dllfun GetDeviceCaps GetDeviceCaps
gdi32.dll  9 dllfun BitBlt BitBlt
gdi32.dll  7 dllfun GetDIBits GetDIBits

struct BITMAPINFOHEADER
  DWORD    field biSize
  DWORD    field biWidth
  DWORD    field biHeight
  WORD     field biPlanes
  WORD     field biBitCount
  DWORD    field biCompression
  DWORD    field biSizeImage
  DWORD    field biXPelsPerMeter
  DWORD    field biYPelsPerMeter
  DWORD    field biClrUsed
  DWORD    field biClrImportant
  DWORD    field bmiColors
end-struct

struct POINT
  DWORD    field POINTx
  DWORD    field POINTy
end-struct

variable screen
variable memory
variable width
variable height
variable bitmap
variable oldbmp
variable buffer

create info BITMAPINFOHEADER 2 * allot

\ ugly non-error-checked code for taking a desktop screenshot
: screenshot
  s" DISPLAY" drop 0 0 0 CreateDC screen !
  screen @ CreateCompatibleDC memory !
  screen @ HORZRES GetDeviceCaps width !
  screen @ VERTRES GetDeviceCaps height !
  screen @ width @ height @ CreateCompatibleBitmap bitmap !
  memory @ bitmap @ SelectObject oldbmp !
  memory @ 0 0 width @ height @ screen @ 0 0 SRCCOPY BitBlt drop
  memory @ oldbmp @ SelectObject bitmap !
  
  0 info BITMAPINFOHEADER fill
  BITMAPINFOHEADER 4 + info biSize set
  memory @ bitmap @ 0 0 0 info DIB_RGB_COLORS GetDIBits drop
  info biHeight get info biWidth get * 4 * allocate buffer !
  memory @ bitmap @ 0 info biHeight get buffer @ info DIB_RGB_COLORS GetDIBits drop

  memory @ DeleteDC drop
  screen @ DeleteDC drop
;

: semi [char] ; emit ;
: pixel ( x y -- col ) info biHeight get swap - 1- info biWidth get * + 4 * buffer @ + d@ ;
: split-channels ( n -- b g r ) 3 0 do dup $ff and swap 8 >> loop drop ;
: ansi ( r g b -- num ) 3 0 do semi 0 .r loop ;
: draw ." \x1b[48;2" ansi ." m  " ;
: gray ( r g b -- code ) + + 32 / 232 + ;
: draw24 ." \x1b[48;5;" 0 .r ." m  " ;

12 value factor

variable red[]
variable green[]
variable blue[]

: virtual-pixel ( x y -- )
  red[] off
  green[] off
  blue[] off

  factor * dup factor + swap do
    dup factor * dup factor + swap do
      i j pixel
      dup $ff and blue[] +! 8 >>
      dup $ff and green[] +! 8 >>
      $ff and red[] +!
    loop
  loop
  
  drop

  blue[] @ factor dup * /
  green[] @ factor dup * /
  red[] @ factor dup * /
;

: test
  [to] factor
  cr info biHeight get factor / 0 do 
    info biWidth get factor /  0 do 
      i j virtual-pixel draw
    loop 
    clear cr 
  loop
;

: free-screenshot
  buffer @ free
  buffer off
;

variable point
POINT allocate point !

256 value win-x
192 value win-y

: cursor-window
  point @ GetCursorPos drop
  point @ POINTx get win-x 2 / - 0 max info biWidth get win-x - min
  point @ POINTy get win-y 2 / - 0 max info biHeight get win-y - min
  .s
;

: show-hot-zone
  screenshot
  cursor-window
  dup win-y + swap do
    dup dup win-x + swap do
      i point @ POINTx get = 
      j point @ POINTy get = or if
	." \x1b[31;7m  \x1b[0m"
      else
	i j pixel split-channels gray draw24
      then
    loop
    clear cr
  loop
  drop
  free-screenshot
;

: page     ." \x1b[2J\x1b[1;1H" ;
: >home    ." \x1b[1;1H" ;
: -cursor  ." \x1b[?25l" ;
: +cursor  ." \x1b[?25h" ;

: show-screen
  screenshot
  8 test
  free-screenshot
;

: monitor-mouse
  page -cursor consume
  begin
    key? until
    >home
    show-screen
    \ show-hot-zone
    250 ms
  repeat
  +cursor consume
;

variable stuff

: .quad
  here ! here 8 type
;

: .pixel
  3 0 do dup $ff and swap 8 >> loop drop
  + + 3 / 
;

variable total
variable region
variable offset

variable clen
variable cbuf

: view-desktop
  screenshot

  width @ height @ * dup total !
  allocate dup region !
  offset !

  ." Total: " total @ . cr
  

  buffer @
  total @ 0 do
    dup d@ .pixel $f8 and offset @ c!
    1 offset +!
    4 +
  loop

  region @ total @ 
  .s
  compress 2dup

  ." Sending data " .s
  2 emit 2 emit
  width @ .quad
  height @ .quad
  dup .quad
  type

  drop free 
  free-screenshot
  region @ free
;
