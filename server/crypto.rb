module Ippwn
  module Crypto

    class Utility
      def Utility.hexdump(text)
        print("\x1b[36;1m")
        offset = 0
        0.upto(text.length - 1) do |i|
          printf("\n%04x ", offset) if offset % 16 == 0
          printf("%02x ", text[i].ord)
          offset += 1
        end
        puts("")
        print("\x1b[0m")
      end
    end

    class SpritzC
      attr_accessor :s, :i, :j, :k, :a, :z, :w

      N = 256
      MID_THRESHOLD = (N / 2.0).floor

      def initialize()
        init()
      end

      def init()
        @i = @j = @k = @a = @z = 0
        @w = 1
        @s = (0..255).to_a
      end

      def key_setup(key)
        init()
        absorb(key)
      end

      def encrypt(key, msg)
        key_setup(key)
        bytes = []
        msg.each_byte { |i| bytes << (i ^ drip()) }
        return bytes.pack("C*")
      end

      def decrypt(key, text)
        return encrypt(key, text)
      end

      def absorb(text)
        text.each_byte { |i| absorb_byte(i) }
      end

      def absorb_byte(byte)
        absorb_nybble(byte & 0x0f)
        absorb_nybble((byte & 0xf0) >> 4)
      end

      def absorb_nybble(nybble)
        shuffle() if @a == MID_THRESHOLD
        swap(@a, MID_THRESHOLD + nybble)
        @a = (@a + 1) & 0xff
      end

      def absorb_stop()
        shuffle() if @a == MID_THRESHOLD
        @a = (@a + 1) & 0xff
      end

      def shuffle()
        whip(2 * N)
        crush()
        whip(2 * N)
        crush()
        whip(2 * N)
        @a = 0
      end

      def whip(r)
        r.times { update() }
        @w = 0xff & (@w + 2)
      end

      def crush()
        0.upto(MID_THRESHOLD - 1) do |v|
          if @s[v] > @s[N - 1 - v]
            swap(v, N - 1 - v)
          end
        end
      end

      def squeeze(r)
        shuffle() if @a > 0
        return Array.new(r) { drip() }
      end

      def drip()
        shuffle() if @a > 0
        update()
        return output()
      end

      def print_state(pfx = "")
        puts(pfx + ": " + [@i, @j, @k, @a, @z, @w].map(&:to_s).join(" "))
      end

      def update()
        @i = 0xff & (@i + @w)
        @j = 0xff & (@k + @s[0xff & (@j + @s[@i])])
        @k = 0xff & (@i + @k + @s[@j])
        self.swap(@i, @j)
      end

      # original:  z = S[j + S[i + S[z + k]]]
      # C-variant: z = S[j + S[i + S[z + k]]] ^ S[N - 1 - i]
      def output()
        a = 0xff & @s[0xff & (@j + @s[0xff & (@i + @s[0xff & (@z + @k)])])]
        b = 0xff & @s[0xff & (N - 1 - @i)]
        @z = a ^ b
        return @z
      end

      def swap(a, b)
        (@s[a] , @s[b]) = [@s[b], @s[a]]
      end
    end

    class SpritzTest
      def initialize
        @spritz = SpritzC.new()
        return true
      end

      def output(text, name)
        puts("\n#{name} text:")
        rows = text.length > 40 ? text.scan(/(.{0,40})/m).flatten : [text]
        
        rows.each do |row|
          if row.length > 0
            colors = ["\x1b[22m", "\x1b[1m"]
            hex    = row.unpack("H*")[0].scan(/(..)/).flatten
            first  = row.gsub(/[^\x20-\x7e]/, ".")
            
            puts("\x1b[36;1m" + first.chars.join(" ") + "\x1b[0m")
            puts("\x1b[35;1m" + hex.zip(colors * (hex.length / 2)).join("") + "\x1b[0m")
          end
        end
      end
      
      def test_text(text, key)
        output(text, "Plain")
        cipher = @spritz.encrypt(key, text)
        output(cipher, "Cipher")
        if @spritz.decrypt(key, cipher) == text
          puts("\nDecryption \x1b[32;1mmatches\x1b[0m, code is working\n\n")
        else
          puts("\nDecryption \x1b[32;1mdoes not match\x1b[0m, code is borked\n\n")
        end                                                
      end
      
      def run(key)
        test_text("The duck flies at midnight", key)
        test_text("I must not fear. Fear is the mind-killer. Fear is the little-death that brings total obliteration. I will face my fear. I will permit it to pass over me and through me. And when it has gone past I will turn the inner eye to see its path. Where the fear has gone there will be nothing. Only I will remain.", key)

        test_text("\033[35;1mEvil#\033[36;1mForth\033[0m\n\033[32;1m ok \033[0m\n",
                  "\x1c\xab\x2b\x1d\xa7\xf8\xd7\x98\x4a\x28\x8b\x54\x58\x71\xb0\x52")
      end

      def gen(key)
        @spritz.key_setup(key)
        16384.times do
          printf("%02x", @spritz.drip())
        end
        puts
      end
    end

  end
end

if __FILE__ == $0
  test = Ippwn::Crypto::SpritzTest.new()

  if ARGV.length != 2
    puts("usage: crypto.rb [run | gen] <key>")
    exit(1)
  end

  case ARGV[0]
  when "run"
    test.run(ARGV[1])
  when "gen"
    test.gen(ARGV[1])
  else
    puts("usage: crypto.rb [run | gen] <key>")
    exit(2)
  end
end
