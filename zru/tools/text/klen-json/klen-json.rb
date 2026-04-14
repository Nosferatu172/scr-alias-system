#!/usr/bin/env ruby
# Script Name: 
# ID: SCR-ID-20260329013201-F0AR0OAJRG
# Assigned with: 
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: 
require 'fileutils'

WINPROFILE = ENV["WINPROFILE"]

# Default directories
DEFAULT_DIRS = [
  "#{WINPROFILE}/Music/clm/",
  "#{WINPROFILE}/Videos/clm/"
]

print "Enter directory to clean (*.info.json), leave blank for defaults:\n> "
user_input = gets.strip

target_dirs = user_input.empty? ? DEFAULT_DIRS : [user_input]

target_dirs.each do |dir|
  unless Dir.exist?(dir)
    puts "⚠️ Directory does not exist: #{dir}"
    next
  end

  Dir.glob(File.join(dir, "**", "*.info.json")).each do |file|
    begin
      File.delete(file)
      puts "✅ Deleted: #{file}"
    rescue => e
      puts "❌ Failed to delete #{file}: #{e.message}"
    end
  end
end

puts "🧹 Cleanup complete."
