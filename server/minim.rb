#!/usr/bin/env ruby

class Minimizer
  def initialize
    @skip = [ "\\", "(" ]

    @pairs = {}

    @ignores = [
      "[char]",
      "postpone"
    ]

    @skip_override = [ "()" ]
  end

  def tokenize(string)
    tokens = []
    word = ""
    skip = nil
    ignore = false
    
    string.each_byte do |byte|
      char = byte.chr

      if skip
        word += char
        if char == skip[1]
          if @skip_override.any? { |i| word.start_with?(i) }
            tokens << word
          end

          if @skip.none? { |i| word.start_with?(i) }
            tokens << word
          end

          word = ""
          skip = nil
        end
        next
      end
      
      if [" ", "\t", "\n", "\r"].member?(char)
        next if word.length == 0

        if ignore
          tokens << word
          word = ""
          ignore = false
        elsif @pairs.keys.member?(word)
          skip = @pairs[word]
          word += char
        else
          @pairs["\\"] = ["\\", "\n"]   if word == "\\"
          @pairs["("]  = ["(", ")"]     if word == "("
          @pairs[".\""] = [".\"", "\""] if word == ".\""
          @pairs["\""] = ["\"", "\""]   if word == ".\""
          @pairs["dllfun"] = ["dllfun", "\n"]   if word == ".\""
          tokens << word
          ignore = true if @ignores.member?(word)
          word = ""
        end
      else
        word += char
      end
    end

    return tokens
  end

  def minimize(file)
    tokens = tokenize(File.read(file))
    return tokens.join(" ") + " "
  end
end

# test code here
if __FILE__ == $0
  if ARGV.length != 1
    puts("usage: minim.rb <file>")
  else
    puts Minimizer.new().minimize(ARGV[0])
  end
end
