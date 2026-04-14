#!/usr/bin/env ruby
# Script Name: mp3_repair1.rb
# ID: SCR-ID-20260329032908-BHGTXQ8P0G
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mp3_repair1

require 'find'
require 'shellwords'
require 'fileutils'

# Configuration
input_dir = "/mnt/c/Users/tyler/Music/mp3"
output_dir = "/mnt/c/Users/tyler/Music/mp3/repaired"

# Create output directory if it doesn't exist
FileUtils.mkdir_p(output_dir)

# Collect all MP3 files
mp3_files = []
Find.find(input_dir) do |path|
  if path.downcase.end_with?(".mp3")
    mp3_files << path
  end
end

puts "Found #{mp3_files.size} MP3 files."

# Process each file
mp3_files.each_with_index do |file, index|
  relative_path = file.sub(input_dir, "")
  output_path = File.join(output_dir, relative_path)

  # Create nested directories in output if needed
  FileUtils.mkdir_p(File.dirname(output_path))

  puts "[#{index + 1}/#{mp3_files.size}] Re-encoding: #{file}"

  # Clean ffmpeg re-encode to ensure compatibility
  command = [
    "ffmpeg",
    "-hide_banner",
    "-loglevel", "error", # keeps it quiet
    "-i", Shellwords.escape(file),
    "-c:a", "libmp3lame",
    "-b:a", "192k", # or change to 320k for max quality
    "-y", # overwrite without prompt
    Shellwords.escape(output_path)
  ].join(" ")

  system(command)
end

puts "Done! All fixed files saved in: #{output_dir}"
