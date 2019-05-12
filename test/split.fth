\ require split.fth

0 value ws

: purge ['] S.free ws each ws free-list ;

readline The quick brown fox jumps over the lazy dog

split --> ws

{ cr S.type } ws each cr

purge

readline red green yellow blue magenta cyan white

split --> ws

1 { S.eval dup . 1+ } ws each drop cr

purge
