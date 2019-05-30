#!/usr/bin/env ruby
#
# Compress a shellcode using a table of common 8-byte subsequences.
# This isn't all that magical, but it does have a measurable effect on
# the output.  Testing with the EvilVM compiler agent reduces the size on the order of 

$root = File.expand_path(File.dirname(__FILE__))
Dir.chdir($root)

class Mask
  attr_accessor :data, :length, :bits, :radix
  
  def initialize(data)
    @radix = 48
    @bits = [0] * (data.length / @radix)
    STDERR.puts("Initialized bit map of #{@bits.length} bytes")
    @data = data
    @length = data.length
  end
  
  def [](x)
    return @data[x]
  end

  def index(a, b)
    spot = @data.index(a, b)
    spot = nil if spot and collides?(spot, b)
    return spot
  end

  def set(n)
    @bits[n / @radix] |= (1 << (n % @radix))
  end

  def test(n)
    return (@bits[n / @radix] & (1 << (n % @radix))) != 0
  end

  def remove(offset, length)
    offset.upto(offset + length - 1) { |bit| set bit }
  end

  def remove_all(sub)
    offset = 0
    while spot = index(sub, offset)
      remove(spot, sub.length)
      offset = spot + sub.length
    end
  end

  def collides?(offset, length)
    offset.upto(offset + length - 1) { |bit| return true if test bit }
    return false
  end
end

def count_sub(code, sub, offset)
  count = 0
  while hop = code.index(sub, offset)
    offset = hop + sub.length
    count += 1
  end
  return count
end

def frequent_groups(code, len, threshold)
  seqs = {}

  0.upto(code.length - len - 1) do |offset|
    next if code.collides?(offset, len)
    seq = code[offset ... offset + len]
    next if seq =~ /^\x00+$/
    unless seqs.key? seq
      seqs[seq] = count_sub(code, seq, offset)
    end
  end

  seqs.select! do |seq, count|
    if seq.length * count > threshold
      code.remove_all(seq)
    end
    seq.length * count > threshold
  end
  
  return seqs
end

def log(msg)
  msg.gsub!("", "\x1b[36;1m")
  msg.gsub!("", "\x1b[0m")
  STDERR.puts msg
end

if ARGV.length == 0
  puts "usage: compress.rb <shellcode>"
  exit 1
end

if ARGV[0] == "-"
  f = STDIN
  f.binmode
else
  f = File.open(ARGV[0], "rb")
end

code = Mask.new(f.read)
f.close if ARGV[0] != "-"

table = ["\x00" * 8]
candidates = 0
savings = 0
[8].each do |len|
  log "\x1b[35;1mTesting substrings of length #{len}\x1b[0m"
  groups = frequent_groups(code, len, 31)
  groups = groups.to_a.sort { |i,j| j[1] <=> i[1] }.take(255)
  groups.each do |seq, count|
    if count * len > 0
      table << seq
      log "  Sequence #{seq.unpack("H*")[0]} occurs #{count} times and uses #{count * len} bytes"
      candidates += 1
      savings += (count * len) - (count * 2)
    else
      log "Uninteresting"
    end
  end
end

log("candidate count is #{candidates}")

output = ""

offset = 0
while offset < code.data.length
  done = false

  table.each_with_index do |seq, index|
    next if index == 0
    if not done and code[offset ... (offset + seq.length)] == seq
      output += index.chr
      output += "6"
      offset += 8
      done = true
      break
    end
  end

  if not done and code[offset].ord == 0x36
    output += "\x006"
    offset += 1
    done = true
  elsif not done
    output += code[offset]
    offset += 1
    done = true
  end
end

f = File.open("defines.asm", "wb")
f.puts "%assign table_len #{table.length}"
f.puts "%assign orig_len  #{code.data.length}"
f.puts "%assign short_len #{output.length}"
f.puts
f.close

f = File.open("compressed.asm", "wb")
f.puts "table:"
table.each do |entry|
  hex = "0x" + entry.reverse.unpack("H*")[0]
  f.puts "  dq #{hex}"
end
f.puts
f.puts "code:"

output.unpack("C*").each_slice(12) do |row|
  bytes = row.map { |i| sprintf("0x%02x", i) }
  f.puts "  db #{bytes.join(", ")}"
end
f.close

log("Started with #{code.data.length} bytes of input")
log("Wrote #{output.length} bytes of compressed output")
log("Assembling...")
shellcode = `bash -c 'nasm -f bin -o >(cat) compress.asm'`
log("Obtained #{shellcode.length} bytes of compressed shellcode")
log("Saved #{code.data.length - shellcode.length} bytes via compression!")

STDOUT.write shellcode
