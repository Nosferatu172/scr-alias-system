#!/usr/bin/env ruby
# Script Name: mp4_repair.rb
# ID: SCR-ID-20260329032917-83JPOHG2YI
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mp4_repair

def repair_mp4(file_path)
  repaired_file = file_path.sub(/\.mp4$/i, '_fixed.mp4')
  # ffmpeg command to fix the file by copying streams (no re-encoding)
  command = "ffmpeg -i \"#{file_path}\" -c copy -map 0 \"#{repaired_file}\" -y"

  puts "Repairing: #{file_path}"
  system(command)
  
  if $?.success?
    puts "Repaired file saved as: #{repaired_file}"
  else
    puts "Failed to repair: #{file_path}"
  end
end

puts "Enter the directory path containing MP4 files:"
dir = gets.chomp

unless Dir.exist?(dir)
  puts "Directory does not exist!"
  exit 1
end

mp4_files = Dir.glob(File.join(dir, '*.mp4'))

if mp4_files.empty?
  puts "No MP4 files found in the directory."
  exit 0
end

mp4_files.each do |file|
  repair_mp4(file)
end
