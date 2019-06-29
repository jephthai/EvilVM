\ require structs.fth
\ require compress.fth

0 value GRAYSCALE_8BIT
1 value COLOR_8BIT

$8 value HORZRES
$a value VERTRES
$cc0020 value SRCCOPY
$0 value DIB_RGB_COLORS
$1 value BI_RGB

loadlib gdi32.dll
value gdi32.dll

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

variable screen
variable memory
variable width
variable height
variable initial
variable bitmap
variable oldbmp
variable buffer

0 value image-format

create info BITMAPINFOHEADER 2 * allot

\ ugly non-error-checked code for taking a desktop screenshot
: screenshot
  s" DISPLAY" drop 0 0 0 CreateDC screen !
  screen @ CreateCompatibleDC memory !
  screen @ HORZRES GetDeviceCaps width !
  screen @ VERTRES GetDeviceCaps height !
  screen @ width @ height @ CreateCompatibleBitmap initial !
  memory @ initial @ SelectObject oldbmp !
  memory @ 0 0 width @ height @ screen @ 0 0 SRCCOPY BitBlt drop
  memory @ oldbmp @ SelectObject bitmap !
  
  0 info BITMAPINFOHEADER fill
  BITMAPINFOHEADER 4 + info biSize set
  memory @ bitmap @ 0 0 0 info DIB_RGB_COLORS GetDIBits drop
  info biHeight get info biWidth get * 4 * allocate buffer !
  memory @ bitmap @ 0 info biHeight get buffer @ info DIB_RGB_COLORS GetDIBits drop

  oldbmp @ DeleteObject drop
  memory @ DeleteDC drop
  screen @ DeleteDC drop
;

: free-screenshot
  initial @ DeleteObject drop
  buffer @ free
  buffer off
;

: .quad
  here ! here 8 type
;

\ a bunch of filters to choose from for converting color pixels to grayscale
: decomp+     max max ;
: decomp~     2dup < if swap then -rot 2dup < if swap then nip max ;
: decomp-     min min ;
: redonly     nip nip ;
: greenonly   drop nip ;
: blueonly    2drop ;
: average     + + 3 / ;
: luminosity  1 >> + swap 1 >> + 1 >> ;
: luminosity2 1 >> + swap 2 >> + 3 * 5 / 255 min ;

' luminosity value convert-fn

: >grayscale
  3 0 do dup $ff and swap 8 >> loop drop
  convert-fn execute
;

variable total
variable region
variable offset

variable clen
variable cbuf

$f8 value fidelity

: @px ( x y -- color )
  swap width @ min swap height @ min
  width @ * + 2 << buffer @ + d@
;

: split-channels
  3 0 do dup $ff and swap 8 >> loop drop
;

: slow-rgb32->rgb8
  split-channels 
  5 >> 
  swap 5 >> 3 << or
  swap 6 >> 6 << or 
;

\ hand-coded ASM cuts execution time approximately in half
\   mov rax, rdi
\   and al, 0b11000000
\   shr ah, 5
\   shl ah, 3
\   or ah, al
\   ror eax, 16
\   shr al, 5
\   rol eax, 8
\   or al, ah
\   xor rdi, rdi
\   mov dil, al

: rgb32->rgb8 i,[ 4889f824c0c0ec05c0e40308c4c1c810c0e805c1c00808e04831ff4088c7 ] ; inline

: color-image
  width @ height @ * dup total !
  allocate dup region !
  offset !

  height @ 0 do
    width @ 0 do
      i j @px rgb32->rgb8
      offset @ c!
      1 offset +!
    loop
  loop

  COLOR_8BIT [to] image-format
;

: half-image
  width @ 1 >> height @ 1 >> * dup total !
  allocate dup region !
  offset !

  height @ 1 >> 0 do
    width @ 1 >> 0 do
      i 2 * j 2 *       @px >grayscale
      i 2 * 1+ j 2 *    @px >grayscale
      i 2 * j 2 * 1+    @px >grayscale
      i 2 * 1+ j 2 * 1+ @px >grayscale

      + + + 2 >> fidelity and offset @ c!

      1 offset +!
    loop
  loop

  width @ 1 >> width !
  height @ 1 >> height !

  GRAYSCALE_8BIT [to] image-format
;

: full-image
  width @ height @ * dup total !
  allocate dup region !
  offset !

  ." Image has " +bold total @ . -bold ." pixels\n"

  buffer @
  total @ 0 do
    dup d@ >grayscale fidelity and offset @ c!
    1 offset +!
    4 +
  loop

  GRAYSCALE_8BIT [to] image-format
;

' color-image value scaler

: view-desktop
  ." Taking screenshot... "

  screenshot

  ." Done.\n"

  '{ scaler execute }' elapsed
  ." Encoded image in " +bold . -bold ." ms\n"

  region @ total @ 
  '{ compress }' elapsed
  ." Compressed in " +bold . -bold ." ms\n"

  2dup dup ." Compressed to " +bold 10 >> . -bold ." KB with \x1b[1mLZMS\x1b[22m\n"

  ." Sending data stream... "
  2 emit 2 emit image-format emit
  width @ .quad
  height @ .quad
  dup .quad
  type

  ." Done. Reclaiming resources.\n"

  drop free 
  free-screenshot
  region @ free
;

: view-desktop
  .pre -bold
  '{ view-desktop }' elapsed
  ." Full operation in " +bold . -bold ." ms\n"
  .post
;
