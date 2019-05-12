loadlib wininet.dll
value wininet.dll

wininet.dll 5 dllfun InternetOpen InternetOpenA
wininet.dll 6 dllfun InternetOpenUrl InternetOpenUrlA
wininet.dll 4 dllfun InternetReadFile InternetReadFile
wininet.dll 5 dllfun HttpQueryInfo HttpQueryInfoA
wininet.dll 1 dllfun InternetCloseHandle InternetCloseHandle

private

readline Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36
drop value user-agent

variable inet
variable request
variable len
variable idex

: up-internet ( -- )
  user-agent 0 0 0 0 InternetOpen inet ! ;

: open-url ( addr u -- )
  drop inet @ swap 0 -1 0 here InternetOpenUrl request ! ;

: len-url ( -- addr len )
  0 idex ! 
  1024 len !
  request @ 5 pad len idex HttpQueryInfo drop
  pad len @ 
;

\ convert a string to a number, assuming base 10, no error checking
: len->int ( addr u -- u )
  0 -rot over + swap do
    10 * i c@ 48 - +
  loop
;

: read-url ( u -- addr u )
  2dup request @ -rot here InternetReadFile drop ;

: down-internet
  request @ InternetCloseHandle drop
  inet @ InternetCloseHandle drop ;

public{

: http-get ( -- addr u )
  up-internet
  readline open-url
  len-url len->int 
  dup .pre ." Downloading " . ." bytes\n"
  dup allocate swap 
  read-url 
  down-internet
  .post
;

}public
