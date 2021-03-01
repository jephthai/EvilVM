
{ ." 

  keyboard.fth

  Implements keystroke injection.  There are several interfaces for this module.
  Send an ASCII character as a keypress with the press function:
  
    $90 press
  
  From the interpreter, read a line of input and type it out:
  
    typeline Hello world!
  
  Press a virtual key (VK) like so:
  
    VK_DELETE vkey
  
  Compile code to type text at runtime:
  
    : test  key\" Hello world!\\n\" ;
  
  And do key combinations (e.g., shortcuts) with the combo-key wrapper:
  
    { key\" r\" } VK_LWIN combo-key  (types WIN-R)
  
\x03" }!

$01 value VK_LBUTTON        
$02 value VK_RBUTTON        
$03 value VK_CANCEL         
$04 value VK_MBUTTON        
$08 value VK_BACK           
$09 value VK_TAB            
$0c value VK_CLEAR          
$0d value VK_RETURN         
$10 value VK_SHIFT          
$11 value VK_CONTROL        
$12 value VK_MENU           
$13 value VK_PAUSE          
$14 value VK_CAPITAL        
$1b value VK_ESCAPE         
$20 value VK_SPACE          
$21 value VK_PRIOR          
$22 value VK_NEXT           
$23 value VK_END            
$24 value VK_HOME           
$25 value VK_LEFT           
$26 value VK_UP             
$27 value VK_RIGHT          
$28 value VK_DOWN           
$29 value VK_SELECT         
$2a value VK_PRINT          
$2b value VK_EXECUTE        
$2c value VK_SNAPSHOT       
$2d value VK_INSERT         
$2e value VK_DELETE         
$2f value VK_HELP           
$5b value VK_LWIN           
$5c value VK_RWIN           
$5d value VK_APPS           
$60 value VK_NUMPAD0        
$61 value VK_NUMPAD1        
$62 value VK_NUMPAD2        
$63 value VK_NUMPAD3        
$64 value VK_NUMPAD4        
$65 value VK_NUMPAD5        
$66 value VK_NUMPAD6        
$67 value VK_NUMPAD7        
$68 value VK_NUMPAD8        
$69 value VK_NUMPAD9        
$6a value VK_MULTIPLY       
$6b value VK_ADD            
$6c value VK_SEPARATOR      
$6d value VK_SUBTRACT       
$6e value VK_DECIMAL        
$6f value VK_DIVIDE         
$70 value VK_F1             
$71 value VK_F2             
$72 value VK_F3             
$73 value VK_F4             
$74 value VK_F5             
$75 value VK_F6             
$76 value VK_F7             
$77 value VK_F8             
$78 value VK_F9             
$79 value VK_F10            
$7a value VK_F11            
$7b value VK_F12            
$7c value VK_F13            
$7d value VK_F14            
$7e value VK_F15            
$7f value VK_F16            
$80 value VK_F17            
$81 value VK_F18            
$82 value VK_F19            
$83 value VK_F20            
$84 value VK_F21            
$85 value VK_F22            
$86 value VK_F23            
$87 value VK_F24            
$90 value VK_NUMLOCK        
$91 value VK_SCROLL         
$a0 value VK_LSHIFT         
$a1 value VK_RSHIFT         
$a2 value VK_LCONTROL       
$a3 value VK_RCONTROL       
$a4 value VK_LMENU          
$a5 value VK_RMENU          
$ba value VK_OEM_1          
$dc value VK_OEM_5          
$bb value VK_OEM_PLUS       
$bc value VK_OEM_COMMA      
$bd value VK_OEM_MINUS      
$be value VK_OEM_PERIOD     
$de value VK_OEM_7          
$e5 value VK_PROCESSKEY     
$f6 value VK_ATTN           
$f7 value VK_CRSEL          
$f8 value VK_EXSEL          
$f9 value VK_EREOF          
$fa value VK_PLAY           
$fb value VK_ZOOM           
$fc value VK_NONAME         
$fd value VK_PA1            
$fe value VK_OEM_CLEAR      

$1 value KEYEVENTF_EXTENDEDKEY
$2 value KEYEVENTF_KEYUP

loadlib user32.dll
value user32.dll

user32.dll 4 dllfun keybd_event keybd_event
user32.dll 2 dllfun MapVirtualKey MapVirtualKeyA
user32.dll 1 dllfun VkKeyScan VkKeyScanA

$0 value NOSHIFT
$1 value SHIFT

create table 256 allot
\ blank the shift table
0 table 256 fill

\ mark all the shifted chars
{ s" ~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?" bounds do
  SHIFT i c@ table + c!
loop }!

: shift?   ( key -- bool )     table + c@ ;
: key-down ( vk sc -- )        0 0 keybd_event drop ;
: key-up   ( vk sc -- )        KEYEVENTF_KEYUP 0 keybd_event drop ;
: map-key  ( ascii -- vk sc )  VkKeyScan dup 0 MapVirtualKey ;

: caps 
  VK_SHIFT 0 0 0 keybd_event drop
;

: uncaps
  VK_SHIFT 0 2 0 keybd_event drop
;

: vkey ( vk -- )
  0 2dup key-down 30 ms key-up
;

: keystroke ( vk sc -- ) 
  map-key 2dup key-down 30 ms key-up
;

: combo-key ( fn -- )
  >r r@ 0 key-down
  execute
  r> 0 key-up
;

: press    ( key -- )         
  dup shift? if
    ['] keystroke VK_SHIFT combo-key
  else
    keystroke
  then
;

: keytype ( addr u -- )
  bounds do i c@ press loop
;

: typeline
  readline keytype
;

: key" postpone " [c] keytype ; immediate 
