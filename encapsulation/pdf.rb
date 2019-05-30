#!/usr/bin/env ruby

STDERR.puts("Adding PDF header")
f = File.open(ARGV[0], "rb")
puts("%PDF-#{f.read()}")
f.close
