#!/usr/bin/env ruby

require 'optparse'
require 'find'

options = {
  cwd: false,
  dir: nil,
  word: nil,
  new: nil
}

# --------------------------------------------------
# CLI PARSER
# --------------------------------------------------

parser = OptionParser.new do |opts|
  opts.banner = <<~BANNER

    🧠 GRIP (Ruby) — Recursive Interactive Grep + Replace

    Supports literal phrases including:
      [ ] ( ) !! < > { } - + _ = \\ | " : ; ? , .

    Examples:
      grip -a -w "foo[bar]" -new "baz!!"
      grip -d /path -w "hello world"

  BANNER

  opts.on('-h', '--h', '--help', 'Show help') do
    puts opts
    exit
  end

  opts.on('-a', '--a', '-cwd', 'Use current working directory') do
    options[:cwd] = true
  end

  opts.on('-d PATH', 'Target directory path') do |d|
    options[:dir] = d
  end

  opts.on('-w WORD', '--word WORD', '--w WORD', 'Search phrase (literal safe)') do |w|
    options[:word] = w
  end

  opts.on('-new NEW', '--new NEW', 'Replacement phrase (literal safe)') do |n|
    options[:new] = n
  end
end

parser.parse!

# --------------------------------------------------
# RESOLVE DIRECTORY
# --------------------------------------------------

root =
  if options[:cwd]
    Dir.pwd
  elsif options[:dir]
    options[:dir]
  else
    puts "❌ Specify directory: -a or -d PATH"
    exit 1
  end

unless Dir.exist?(root)
  puts "❌ Invalid directory: #{root}"
  exit 1
end

# --------------------------------------------------
# INPUT FALLBACKS
# --------------------------------------------------

search = options[:word] || (print("🔍 Enter search phrase: "); gets&.chomp)
replace = options[:new]  || (print("✏️ Enter replacement: "); gets&.chomp)

if search.nil? || search.empty?
  puts "❌ No search phrase provided"
  exit 1
end

if replace.nil?
  puts "❌ No replacement provided"
  exit 1
end

# Escape for literal matching
pattern = Regexp.new(Regexp.escape(search), Regexp::IGNORECASE)

# Auto mode if both provided
auto_mode = options[:word] && options[:new]

# --------------------------------------------------
# FILE SCAN
# --------------------------------------------------

def binary_file?(path)
  File.open(path, "rb") do |f|
    chunk = f.read(1024)
    return chunk&.include?("\x00")
  end
rescue
  true
end

matches = []

puts "\n🔎 Scanning: #{root}"

Find.find(root) do |path|
  next if File.directory?(path)
  next if binary_file?(path)

  begin
    File.readlines(path, encoding: 'UTF-8', invalid: :replace, undef: :replace).each_with_index do |line, idx|
      if line.match?(pattern)
        matches << [path, idx + 1, line.chomp]
      end
    end
  rescue
    next
  end
end

puts "📊 Found #{matches.size} matches."

if matches.empty?
  puts "No matches found."
  exit
end

# --------------------------------------------------
# INTERACTIVE REPLACE
# --------------------------------------------------

replace_all = auto_mode

matches.each do |path, lineno, line|
  new_line = line.gsub(pattern, replace)
  next if line == new_line

  puts "\n📄 #{path}:#{lineno}"
  puts " - #{line}"
  puts " + #{new_line}"

  choice =
    if replace_all
      'y'
    else
      print("Replace? [y]es / [n]o / [a]ll / [q]uit: ")
      gets.chomp.downcase
    end

  case choice
  when 'q'
    puts "❌ Aborted."
    exit
  when 'a'
    replace_all = true
    choice = 'y'
  end

  next unless choice == 'y'

  begin
    lines = File.readlines(path, encoding: 'UTF-8', invalid: :replace, undef: :replace)
    lines[lineno - 1] = lines[lineno - 1].gsub(pattern, replace)
    File.write(path, lines.join)
    puts "✅ Replaced."
  rescue => e
    puts "⚠️ Failed: #{e}"
  end
end
