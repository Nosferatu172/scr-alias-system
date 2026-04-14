#!/usr/bin/env ruby
# Script Name: detxt.rb
# Desc: Remove timestamp prefixes from filenames

require "optparse"
require "colorize"
require "fileutils"

# -----------------------
# Ctrl+C
# -----------------------
Signal.trap("INT") do
  puts "\n⛔ Interrupted.".colorize(:red)
  exit 130
end

# -----------------------
# Helpers
# -----------------------
def strip_timestamp(name)
  name.sub(/^\d{8}_\d{6}(?:_\d+)?_/, "")
end

def txt_files(dir)
  Dir.children(dir).select { |f| f.downcase.end_with?(".txt") }
end

# -----------------------
# Options
# -----------------------
opts = {}

OptionParser.new do |o|
  o.on("-d DIR", "Target directory") { |d| opts[:dir] = d }
  o.on("--dry-run", "Preview only") { opts[:dry] = true }

  o.on("-h", "Help") do
    puts <<~H

    🧹 detxt - Remove timestamp prefixes

    Usage:
      detxt -d <dir>
      detxt -d <dir> --dry-run

    Removes patterns like:
      20251011_024345_123456_

    H
    exit
  end
end.parse!

# -----------------------
# Validate
# -----------------------
dir = opts[:dir] || Dir.pwd

unless Dir.exist?(dir)
  puts "❌ Directory not found: #{dir}".colorize(:red)
  exit 1
end

files = txt_files(dir)

if files.empty?
  puts "❌ No .txt files found.".colorize(:red)
  exit
end

# -----------------------
# Process
# -----------------------
files.each do |f|
  new_name = strip_timestamp(f)

  next if new_name == f # nothing to change

  old_path = File.join(dir, f)
  new_path = File.join(dir, new_name)

  if File.exist?(new_path)
    puts "⚠️ Skipping (exists): #{new_name}".colorize(:yellow)
    next
  end

  if opts[:dry]
    puts "🧪 [DRY] #{f} → #{new_name}".colorize(:yellow)
  else
    FileUtils.mv(old_path, new_path)
    puts "🔁 #{f} → #{new_name}".colorize(:green)
  end
end
