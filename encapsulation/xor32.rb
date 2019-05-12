$root = File.expand_path(File.dirname(__FILE__))
Dir.chdir($root)

def log(msg)
  msg.gsub!("", "\x1b[36;1m")
  msg.gsub!("", "\x1b[0m")
  STDERR.puts msg
end

class Encoder
  attr_accessor :code

  def initialize(source)
    @source = source
    @code = ""
  end

  def rotate(value)
    bit = (value & 1) << 63
    return bit | (value >> 1)
  end

  def encode(key)
    @source.each_byte do |byte|
      57.times { key = rotate(key) }
      @code << (byte ^ (key & 0xff)).chr
    end
    return @code
  end
end

if __FILE__ == $0
  key = rand(2**64)
  STDERR.puts(sprintf("key %16x\n", key))
  STDIN.binmode
  e = Encoder.new(STDIN.read)
  e.encode key

  f = File.open("defines.asm", "wb")
  f.puts "%assign CODE_LEN #{e.code.length}"
  f.puts "%assign KEY32  #{key}"
  f.puts
  f.close

  f = File.open("code.asm", "wb")
  f.puts("code:")
  e.code.unpack("C*").each_slice(12) do |row|
    bytes = row.map { |i| sprintf("0x%02x", i) }
    f.puts "  db #{bytes.join(", ")}"
  end
  f.close
  
  log("Started with #{e.code.length} bytes of input")
  log("Assembling...")
  shellcode = `bash -c 'nasm -f bin -o >(cat) xor32.asm'`
  log("Obtained #{shellcode.length} bytes of encoded shellcode")
  STDOUT.binmode
  STDOUT.write(shellcode)
end
