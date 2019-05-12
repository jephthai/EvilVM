
\ file documentation
{ ." 

This is a snippet that facilitates interrogation of the TEB,
indexed via the GS register

Run .teb to see the TEB contents
Run N gsx to get value at offset N

" ETX emit }! 

: gsx    ( gs-offset -- value ) i,[ 65488b3f ] ; \ mov rdi, [gs:rdi]
: .qword ( offset -- offset+8 ) dup gsx +bold ." 0x" hex . -bold dec 8 + ;
: .dword ( offset -- offset+4 ) dup gsx $ffffffff +bold . -bold 4 + ;
hex
: .teb
  0 .pre -bold
  ." SEH Frame:      " .qword cr
  ." Stack Base:     " .qword cr
  ." Stack Limit:    " .qword cr
  ." SubSystemTib:   " .qword cr
  ." Fiber Data:     " .qword cr
  ." Arbitrary Slot: " .qword cr
  ." Linear &TEB:    " .qword cr
  ." Env ptr:        " .qword cr
  ." Process ID:     " .qword cr
  ." Thread ID:      " .dword cr drop
  ." &PEB:           " 60 .qword cr drop
  ." Last Error:     " 68 .dword cr drop
  ." Last Status:    " 1250 .dword cr drop
  ." Stack Memory:   " 1478 .qword cr drop
  .post
;
dec
