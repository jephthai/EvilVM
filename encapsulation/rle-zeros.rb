#!/usr/bin/env ruby

$root = File.expand_path(File.dirname(__FILE__))
Dir.chdir($root)

require 'tempfile'

def log(msg)
  msg.gsub!("", "\x1b[35;1m")
  msg.gsub!("", "\x1b[0m")
  STDERR.puts msg
end

if ARGV.length == 0
  log "usage: rle-zeros.rb <shellcode>"
  exit 1
end

if ARGV[0] == "-"
  f = STDIN
  f.binmode
else
  f = File.open(ARGV[0], "rb")
end

source = f.read()
f.close

log("Read #{source.length} bytes of original shellcode")

output = ""

growers = 0
offset = 0
while offset < source.length
  if source[offset].ord == 0
    count = 0
    while offset < source.length and source[offset].ord == 0 and count < 255
      count += 1
      offset += 1
    end
    growers += 1 if count == 1
    output += [count, 0].pack("CC")
  else
    output += source[offset]
    offset += 1
  end
end

log("There were #{growers} single-byte sequences that will grow")
log("Compressed to #{output.length} bytes")
log("Saved #{source.length - output.length} bytes via compression")

f = File.open("defines.asm", "wb")
f.puts "%assign orig_len  #{source.length}"
f.puts "%assign short_len #{output.length}"
f.puts "%assign slack #{growers}"
f.puts
f.close

f = File.open("rled.asm", "wb")
f.puts "code:"
output.unpack("C*").each_slice(12) do |row|
  bytes = row.map { |i| sprintf("0x%02x", i) }
  f.puts "  db #{bytes.join(", ")}"
end
f.close

output = Tempfile.new('binary')
begin
  log("Assembling...")
  system(`bash -c 'nasm -f bin -o #{output.path} rle.asm'`)
  f = File.open(output.path, "rb")
  shellcode = f.read
  f.close
  log("Obtained #{shellcode.length} bytes of compressed shellcode")
  STDOUT.write shellcode
ensure
  output.unlink
end

log("IMPORTANT be sure to allocate at least #{shellcode.length + growers * 2 + 1} bytes for expansion!")
