loadlib cabinet.dll
value cabinet.dll

$2 value COMPRESS_ALGORITHM_MSZIP
$3 value COMPRESS_ALGORITHM_XPRESS
$4 value COMPRESS_ALGORITHM_XPRESS_HUFF
$5 value COMPRESS_ALGORITHM_LZMS

cabinet.dll 3 dllfun CreateCompressor CreateCompressor
cabinet.dll 1 dllfun CloseCompressor CloseCompressor
cabinet.dll 6 dllfun Compress Compress
cabinet.dll 4 dllfun QueryCompressorInformation QueryCompressorInformation
cabinet.dll 4 dllfun SetCompressorInformation SetCompressorInformation

variable compressor
variable outbytes

: compress ( addr u -- addr u )
  \ create a compressor
  COMPRESS_ALGORITHM_LZMS 0 compressor CreateCompressor 0= if
    .err return
  then

  \ set enormous block size (saved 10% size in testing!)
  1024 1024 * here !
  compressor @ 1 here 4 SetCompressorInformation drop
  
  \ compress the data
  compressor @ -rot dup allocate >r r@ over outbytes ( c a1 u1 a2 u1 p )
  Compress drop

  \ get region for compressed data
  r> outbytes @

  \ free resources
  compressor @ CloseCompressor 0= if .err then
;

