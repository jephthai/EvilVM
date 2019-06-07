#!/usr/bin/env ruby

#
# The server speaks only basic, unencrypted TCP.  If we want to encrypt our TCP
# transport, we can use this this shim to add encryption and decryption.
#

$root = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << "#{$root}"

require 'socket'
require 'crypto.rb'

$sess = 0
$target = "127.0.0.1"
$dport = 1919
$connections = {}
$inkey = "\xf1\x77\x80\x02\xea\x2a\x5f\x72\xd2\x0b\x28\x1e\x38\xa9\xc9\x4b"
$outkey = "\x1c\xab\x2b\x1d\xa7\xf8\xd7\x98\x4a\x28\x8b\x54\x58\x71\xb0\x52"

def pputs(msg, col=35)
  msg.gsub!("", "\x1b[1m")
  msg.gsub!("", "\x1b[22m")
  puts("\x1b[#{col}m#{msg}\x1b[0m")
end

class Session
  attr_accessor :sock, :svr, :incrypto, :outcrypto, :sid

  def initialize(sock, dest, dport)
    @sid = $sess
    $sess += 1

    @sock = sock
    @svr = TCPSocket.new(dest, dport)

    @incrypto = Ippwn::Crypto::SpritzC.new()
    @incrypto.key_setup($inkey)

    @outcrypto = Ippwn::Crypto::SpritzC.new()
    @outcrypto.key_setup($outkey)
  end

  def receive(data)
    pputs("session #{@sid} received #{data.length} bytes")
    @svr.write(decrypt(data))
  end

  def send(data)
    pputs("session #{@sid} sent #{data.length} bytes", 36)
    @sock.write(encrypt(data))
  end

  def encrypt(data)
    return data.unpack("C*").map { |i| i ^ @incrypto.drip() }.pack("C*")
  end

  def decrypt(data)
    return data.unpack("C*").map { |i| i ^ @outcrypto.drip() }.pack("C*")
  end

  def shutdown()
    [@sock, @svr].each do |sock|
      begin
        sock.close
      rescue Exception => e 
        pputs("error #{e.message} closing socket #{sock}")
      end
    end
  end
end

class Server
  def initialize(port = 1922, dest, dport)
    @listen = TCPServer.new(port)
    @dest = dest
    @dport = dport
  end

  def run(connections)
    while true
      sock = @listen.accept
      session = Session.new(sock, @deset, @dport)
      connections[session.sock] = session
      connections[session.svr] = session
    end
  end
end

def remove_session(conns, sock)
  session = conns[sock]
  pputs("removing session #{session.sid}", 33)
  session.shutdown()
  conns.delete(session.sock)
  conns.delete(session.svr)
end  

if __FILE__ == $0
  
  conns  = {}
  server = Server.new(1922, $target, $dport)

  Thread.new do
    server.run(conns)
  end

  while true
    sockets = conns.keys

    if sockets == []
      sleep(0.1)
      next
    end

    sockets.each { |sock| remove_session(conns, sock) if sock.closed? }

    rs, ws, es = Socket.select(sockets, [], sockets, 5)

    next unless rs

    es.each do |sock|
      pputs("socket #{sock} is in the error list", 31)
      remove_session(conns, sock)
    end

    rs.each do |sock|
      data = sock.recv(4096)
      session = conns[sock]

      if data.length == 0
        remove_session(conns, sock)
      else
        session.receive(data) if sock == session.sock
        session.send(data)    if sock == session.svr
      end
    end
    
  end
end
