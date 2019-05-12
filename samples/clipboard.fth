{ ." 

  clipboard.fth
  
  Monitor the clipboard and print out its text contents whenever
  they become available.  Exit the loop by submitting any input
  (detected using key?).
  
  Run monitor-clipboard to enter the loop.

" ETX emit }!


loadlib user32.dll
value user32

1 value CF_TEXT

user32 0 dllfun GetForegroundWindow GetForegroundWindow
user32 1 dllfun OpenClipboard OpenClipboard
user32 1 dllfun GetClipboardData GetClipboardData
user32 0 dllfun CloseClipboard CloseClipboard
user32 0 dllfun GetClipboardSequenceNumber GetClipboardSequenceNumber
user32 1 dllfun IsClipboardFormatAvailable IsClipboardFormatAvailable

: consume begin key? while key drop repeat ;

: monitor-clipboard
  .pre 
  consume begin
    \ get clipboard data and print it in the log
    GetForegroundWindow
    dup OpenClipboard drop

    CF_TEXT IsClipboardFormatAvailable if
      \ grab and log some text
      cr -bold @time .time +bold -rev space
      CF_TEXT GetClipboardData c->str trim type
    then

    \ clean up resources and loop
    CloseClipboard drop
    CloseHandle drop

    \ wait for a copy event
    GetClipboardSequenceNumber begin
      dup GetClipboardSequenceNumber = 
      key? 0= and while
      250 ms
    repeat

    \ abort when a key is pressed
    drop key? 0= while
  repeat
  consume .post
;

