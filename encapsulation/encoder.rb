#!/usr/bin/env ruby

$root = File.expand_path(File.dirname(__FILE__))
Dir.chdir($root)

require 'optparse'

class Encoder
  attr_accessor :code

  def initialize(source)
    @source = source
  end

  def encode(config)
    if config =~ /rand/
      key = rand(256).ord
    else
      key = [config.split[0]].pack("H*")
      key = key[0].ord
    end

    prefix = ["31c9b500b100b000488d1d11000000d0c88a2330c4882348ffc3e2f331c931c0"].pack("H*")
    $stderr.puts("RHEX Encoder: Key is #{sprintf("%02x", key)}")
    $stderr.puts("RHEX Encoder: Prefix is #{prefix.length} bytes")
    $stderr.puts("RHEX Encoder: Shellcode is #{@source.length} bytes")
    high = (@source.length & 0xff00) >> 8
    low  = @source.length & 0xff
    prefix[3] = high.chr
    prefix[5] = low.chr
    prefix[7] = key.chr

    @code = prefix
    
    @source.each_byte do |byte|
      bit = (key & 1) << 7
      key = bit | (key >> 1)
      @code << (byte ^ key).chr
    end
  end
end

if __FILE__ == $0
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: encoder.rb [options]"
    opts.separator ""

    opts.on("-s", "--shellcode FILE", "File to encode") do |s|
      options[:file] = s
    end

    opts.on("-k", "--key k", "Single byte key in hex") do |s|
      options[:key] = s
    end

  end.parse!

  unless options.key? :file
    puts "ERROR: Must specify input file with -s option"
    exit 1
  end

  unless options.key? :key
    puts "ERROR: Must specify XOR key with -k option"
    exit 1
  end
  
  if options[:file] == "-"
    f = STDIN
    f.binmode
  else
    STDERR.puts("Opening file #{ARGV[0]}")
    f = File.open(options[:file], "rb")
  end

  e = Encoder.new(f.read)
  f.close
  e.encode options[:key]
  print e.code
end
