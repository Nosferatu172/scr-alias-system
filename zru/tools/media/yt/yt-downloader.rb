#!/usr/bin/env ruby
# YouTube Downloader Launcher
# Automatically runs the enhanced version

require 'fileutils'

SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
ENHANCED_SCRIPT = File.join(SCRIPT_DIR, 'banshee3.rb')

if File.exist?(ENHANCED_SCRIPT)
  exec("ruby \"#{ENHANCED_SCRIPT}\"")
else
  puts "❌ Enhanced downloader not found: #{ENHANCED_SCRIPT}"
  puts "Please ensure enhanced_yt_downloader.rb exists in the same directory."
  exit 1
end
