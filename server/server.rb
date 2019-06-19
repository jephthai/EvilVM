#!/usr/bin/env ruby
#
# A server console for EvilVM.  This is still really messy -- it's just been working
# so well for me since the first draft, I haven't gotten around to reorganizing it.
# It manages a gaggle of connections to running EvilVM agents.  It only supports
# communications over TCP -- other protocols need server shims in front of this
# console.
#

require 'optparse'

here = File.dirname(__FILE__)
$root = File.expand_path(here + "/../")
$LOAD_PATH << $root + "/server/"

puts("Root dir is #{$root}")

begin
  require 'rmagick'
  $rmagick = true
rescue Exception => e
  puts("NOTE: `rmagick' not installed, screenshots will be written to disk, not displayed")
  $rmagick = false
end

require "time"
require "socket"
require "readline"
require "thread"
require "queue.rb"
require "colors.rb"
require "digest"
require 'pry'
require 'minim.rb'
require 'base64'
require 'tempfile'

def putshl(msg, chars)
  print("\x1b[35m")
  groups = msg.scan(/((.)\2*)/)
  groups.each do |(group, char)|
    if chars.include?(char)
      print("\x1b[1m#{group}\x1b[22m")
    else
      print(group)
    end
  end
  print("\x1b[0m\n")
end

def do_banner
  puts("")
  putshl("                                         ##",                  "#")
  putshl("                                         ##",                  "#")
  putshl("                                         ##",                  "#")
  putshl("                               __________##__________ ",       "#")
  putshl("                               ###################### ",       "#")
  putshl("                                     .## ## ##,      ",        "#")
  putshl("                                    .##` ## '##,            ", "#")
  putshl("    ______________________         .##`  ##  '##,           ", "#")
  putshl("    ######################        .##`   ##   '##,          ", "#")
  putshl("                                .##`     ##     '##,",         "#")
  putshl("                              <##`  _____##_____  '##>",       "#")
  putshl("                                    ############       ",      "#")
  putshl("  Welcome to EVIL                        ##     ",             "#")
  putshl("     you are here early                  ##     ",             "#")
  putshl("    Let's fault some segs together       ##     ",             "#")
  puts("")
end

$mutex = Mutex.new

def assign_color(string)
  hash = Digest::MD5.hexdigest(string)[0..16].to_i(16)
  return Colors::List[hash % Colors::List.length]
end

class CircleBuffer
  attr_accessor :slots, :size, :idex

  def initialize(size)
    @slots = [nil] * size
    @size  = size
    @idex  = 0
  end

  def <<(item)
    @slots[@idex] = item
    @idex = (@idex + 1) % size
  end

  def list()
    ret = []
    i = @idex
    loop do
      ret << @slots[i]
      i = (i + 1) % size
      break if i == @idex
    end
    return ret
  end
end

class Channel
  attr_accessor :sock, :emitter, :output, :ident, :lines, :lineno, :mon, :files

  def initialize(sock)
    @buffer = ""
    @sock   = sock
    @output = QueueWithTimeout.new
    @ident  = nil
    @lines  = CircleBuffer.new(16)
    @files  = {}
    @mode   = 0

    @clear_on_load = false

    @emitter = Thread.new do
      line = ""
      while true
        begin
          byte = sock.read(1)
        rescue
          notify("ERROR reading socket, closing channel", prompt: false, error: true)
          break
        end

        break if byte == nil

        if byte.ord == 10
          @lines << line
          if line =~ /(IDENT:.*@.*:[0-9a-f\-]+)/
            @ident = line
          end
          line = ""
        elsif byte.ord == 24
          # agent indicates an error
          print("\n\x1b[31;1mERROR detected, issuing ETB to reset\x1b[0m")
          sock.write("\x17")
          next
        elsif byte.ord == 2
          # start of text -- data is in some different format
          case sock.read(1).ord
          when 1
            # hexdump of assembly that needs disassembly
            disassemble_code
            next
          when 2
            # raw image data
            handle_image
            next
          when 3
            # download raw data
            handle_download
            next
          end
        elsif byte != 13
          line << byte
        end
        @output << byte
      end
    end

    puts("")
    @sock.write(": *iv* #{gen_iv()} ;\n")
    @sock.write(Minimizer.new().minimize("#{$root}/api/core.fth"))
    load_file("#{$root}/samples/payload-net.fth")
    @sock.write("\r\nident\r\n")
    @clear_on_load = true
  end

  def handle_download
    len = 0
    8.times { |i| len |= (sock.read(1).ord) << (i * 8) }

    data = sock.read(len)
    file = Tempfile.new('download')
    file.write(data)
    file.close()
    puts("\x1b[33mDownloaded \x1b[1m#{len} byte\x1b[22m file to \x1b[1m#{file.path}\x1b[0m")
  end
  
  def handle_image
    width = 0
    height = 0
    length = 0
    raw = nil

    8.times { |i| width |= (sock.read(1).ord) << (i * 8) }
    8.times { |i| height |= (sock.read(1).ord) << (i * 8) }
    8.times { |i| length |= (sock.read(1).ord) << (i * 8) }

    bytes = sock.read(length)

    # use libwim to decompress LZMS algorithm
    begin
      proc = IO.popen("#{$root}/server/decompress", "rb+")
      proc.write(bytes)
      raw = proc.read()
      proc.close()
    rescue Exception => e
      puts("\x1b[s\x1b[31;1mError decompressing... did you `make` in #{$root}/server?\x1b[u")
      return
    end

    if $rmagick

      # we can pop up a window showing the screenshot, talk about
      # awesome U/X!
      
      image = Magick::Image.new(width, height)
      image.import_pixels(0,0,width,height,"I",raw)
      image.flip!
    
      puts("Displaying it")
      Thread.new do 
        image.level(0,224 * 256).display()
      end
    end

    # generate a "hard copy" as a PGM
    outfile = Tempfile.new(['screenshot-', '.pgm'])
    outfile.write("P5\n")
    outfile.write("# screenshot #{DateTime.now}\n")
    outfile.write("#{width} #{height}\n255\n")

    height.times do |row|
      # BMPs are upside down, so we rearrange it, sigh
      offset = (height - row - 1) * width
      outfile.write(raw[offset...offset+width])
    end

    outfile.close
    puts("\n\x1b[s\x1b[33;1mWrote screenshot to #{outfile.path}\x1b[u")
  end

  def disassemble_code
    code = ""
    address = 0
    length = 0

    8.times { |i| address |= (sock.read(1).ord) << (i * 8) }
    8.times { |i| length |= (sock.read(1).ord) << (i * 8) }

    length.times do code += sock.read(1) end

    output = Tempfile.new('code')
    begin
      output.write(code)
      output.close()
      $mutex.synchronize do
        disassembly = `ndisasm -o #{address} -b 64 #{output.path}`
        puts("\n\x1b[33m---- BEGIN DISASSEMBLY ----\n\x1b[1m")
        puts(disassembly)
        puts("\x1b[22m\n----- END DISASSEMBLY -----\x1b[0m\n")
      end
    ensure
      output.unlink
    end
  end

  def gen_iv()
    iv = ""
    16.times { iv << sprintf("%020d ", rand(2**64 - 1)) }
    return iv
  end

  def stream_file(file)
    data = File.read(file)
    @sock.write("\r#{data.length} ,stream\r#{data}")
  end

  def moniker()
    col = ""
    if @ident
      unless @mon
        (name, rgb) = assign_color(@ident)
        (r, g, b) = [rgb].pack("H*").unpack("CCC")
        name.gsub!(" ", "-")
        color  = sprintf("%03d;%03d;%03d", r, g, b)
        @mon = "\x1b[40;1;38;2;#{color}m\x1b[1m [#{name}] \x1b[0m"
      end
      col = @mon
    end
    return col
  end

  def deliver(msg)
    @sock.write(msg)
  end
  
  def describe()
    begin
      dom, port, host, ip = @sock.peeraddr
      mon = sprintf("%-42s", moniker())
      return "#{mon} #{ip}\x1b[35;1m:\x1b[0m#{port}"
    rescue
      return "\x1b[31;1mBROKEN\x1b[0m"
    end
  end

  def alive?()
    return !@sock.closed?
  end
  
  def kill()
    @sock.write("bye\n")
    @sock.close()
  end

  def notify(msg, newline: false, prompt: false, error: false)
    color = error ? "31" : "33"
    puts("") if newline
    print("\x1b[#{color}mNOTE: #{moniker}: \x1b[#{color}m#{msg}\x1b[0m\n")
    print($prompt) if prompt
  end
  
  def load_file(file, force = false)
    path = nil
    
    if File.exists?(file)
      path = file
    elsif File.exists?("#{$root}/samples/#{file}")
      path = "#{$root}/samples/#{file}"
    elsif File.exists?("#{$root}/#{file}")
      path = "#{$root}/#{file}"
    else
      notify("File \x1b[1m#{file}\x1b[22m not found", prompt: true, error: true)
    end

    if @files[path] and not force
      notify("File \x1b[1m#{path}\x1b[22m already loaded", newline: true, prompt: true, error: true)
    else
      data = File.read(path)
      lines = data.split(/\n/).take_while { |i| i.start_with?("\\") }
      
      lines.each do |comment|
        fields = comment.split()
        if fields[1] == "require"
          load_file(fields[2], force)
        end
      end
      
      data = "reset-lines\n" + data if @clear_on_load
      @sock.write(data)
      
      notify("File \x1b[1m#{path}\x1b[22m loaded")
      @files[path] = true
    end
  end
end

options = { :port => 1919, :bind => "0.0.0.0" }

OptionParser.new do |opts|
  opts.banner = "\nUsage: server.rb [options]"
  opts.separator ""
  opts.separator " EvilVM server console.  Listens on a TCP port and provides a text UI / "
  opts.separator " command line for interacting with connected agents.  Agents that need "
  opts.separator " to connect with protocols other than TCP will require running a shim "
  opts.separator " specific to that protocol, as the server supports only TCP streams."
  opts.separator ""

  opts.separator "Options:"
  opts.on("-p", "--port PORT", "Specify TCP port for listening") do |p|
    options[:port] = p
  end
  
  opts.on("-b", "--bind ADDR", "Specify IP address to bind") do |a|
    options[:bind] = a
  end

  opts.on("-h", "--help", "This help text") do
    puts opts
    exit 1
  end

  opts.separator ""
end.parse!

do_banner

puts("Binding server on #{options[:bind]}:#{options[:port]}")
server = TCPServer.new(options[:bind], options[:port].to_i)
channels = []
current = nil
$prompt = "\x1b[35;1m >\x1b[0m"

def new_prompt(current, channels)
  begin
    return "\x1b[32;1m#{channels.index(current)+1} #{current.moniker}\x1b[34;1m -> \x1b[0m"
  rescue Exception => e
    return "\x1b[32;1m > \x1b[0m"
  end
end

gateway = Thread.new do
  while true
    begin
      channel = Channel.new(server.accept())
      current = channels[0] if channels.length == 0
      channels << channel
      $mutex.synchronize do
        puts("\n\x1b[35;1mIntroducing channel #\x1b[32;1m#{channels.length}\x1b[0m")
      end
    rescue Exception => e
      $mutex.synchronize do
        puts("Error: #{e.message}")
      end
    end
  end
end

emitter = Thread.new do
  stack = [ 39, 35, 36, 32, 35, 31 ]
  cindex = 0
  while true
    if current
      begin
        byte = current.output.pop_with_timeout(0.5)
        if byte.ord == 14
          cindex = [0,[stack.length,cindex+1].min].max
          STDOUT.write("\x1b[#{stack[cindex]};1m") 
        elsif byte.ord == 15
          cindex = [0,[stack.length,cindex-1].min].max
          STDOUT.write("\x1b[#{stack[cindex]};1m")
        elsif byte.ord == 0x03
          # an ETX character means the agent is signalling the server
          # that it should re-prompt for input (end of text)
          print("#{$prompt}")
        else
          STDOUT.write(byte)
        end
      rescue Exception => e
        sleep(0.1)
      end
    else
      sleep(0.1)
    end
  end
 end

while true
  if channels.length == 0
    puts("Awaiting inbound connection...")
    while channels.length == 0
      sleep(0.2)
    end
    current = channels[0]
    $prompt = new_prompt(current, channels)
  end

  stage = nil

  begin
    while true
      current.deliver(stage) if stage
      stage = nil

      buf = Readline.readline($prompt, true)

      # really annoying to have empty lines in your history!
      Readline::HISTORY.pop if /^\s*$/ =~ buf

      # no need to have duplicates either
      Readline::HISTORY.pop if Readline::HISTORY.length > 1 and Readline::HISTORY[-2] == Readline::HISTORY[-1]

      if buf[0] == "\x0b"
        begin
          # use VT character as 'escape' for server commands
          fields = buf[1..-1].split().map(&:strip).select { |i| i.length > 0 }
          cmd = fields.shift()

          case cmd
          when "loadf"
            current.load_file(fields[0], true)
          when "load"
            current.load_file(fields[0])
          when "kill"
            current.kill()
            channels.delete(current)
          when "last"
            puts            
            current.lines.list.each { |i| puts i }
            puts
          when "switch"
            index = fields[0].to_i - 1
            if channels.length > index
              current = channels[index]
              $prompt = new_prompt(current, channels)
            else
              puts("\x1b[31;1mError: no such channel\x1b[0m")
            end
          when "list"
            channels.each_with_index do |c, i|
              output = "Client #\x1b[32;1m#{i + 1}\x1b[0m"
              output = sprintf("%20s #{c.describe}\x1b[0m", output)
              output += "*" if c == current
              puts output
            end
          when "stream"
            if File.exist?(fields[0])
              current.stream_file(fields[0])
            else
              puts("\x1b[31;1mError, file does not exist\x1b[0m")
            end
          when "quit"
            channels.each do |chan|
              begin
                chan.kill()
              rescue Exception => e
                puts("\x1b[31;1mError killing channel #{chan.describe}\x1b[0m")
              end
            end
            sleep 1
            exit 0
          else
            puts("\x1b[31;1m\nUnknown command: \x1b[33;1m#{cmd}\x1b[0m")
          end
        rescue SystemExit
          exit 0
        rescue Exception => e
          puts("\x1b[31;1mFailed server command: (\x1b[32;1m#{e.class}\x1b[31;1m) \x1b[33;1m#{e.message}\x1b[0m")
        end
      else
        # otherwise, the line gets passed to the socket
        stage = buf + "\n"
      end

      $prompt = new_prompt(current, channels)
    end
  rescue SystemExit
    exit 0
  rescue Errno::EPIPE
    channels.delete(current)
    current = nil
    current = channels[0] if channels.length > 0
    $prompt = new_prompt(current, channels)
    puts("\x1b[31;1mSocket died\x1b[0m")
  rescue Exception => e
    puts("\x1b[31;1mError in command processor: (\x1b[32;1m#{e.class}\x1b[31;1m) \x1b[33;1m#{e.message}\x1b[0m")
  end
end
