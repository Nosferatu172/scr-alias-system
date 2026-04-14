#!/usr/bin/env ruby
# Script Name: mp3_repair2.rb
# ID: SCR-ID-20260329032913-CCECXXFYAB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mp3_repair2

require 'fileutils'
require 'open3'

# Define the directories
input_directory = '/mnt/c/Users/tyler/Music/clm/'
output_directory = '/mnt/c/Users/tyler/Music/clm/repaired/'

# Ensure output directory exists
FileUtils.mkdir_p(output_directory)

# Function to repair a file using ffmpeg
def repair_file(input_path, output_path)
  command = "ffmpeg -i '#{input_path}' -c copy '#{output_path}'"
  stdout, stderr, status = Open3.capture3(command)

  if status.success?
    puts "Successfully repaired #{input_path}"
  else
    puts "Error repairing #{input_path}: #{stderr}"
  end
end

# Iterate over all mp3 files in the input directory
Dir.glob("#{input_directory}/*.mp3") do |file|
  # Prepare the output path
  output_file = File.join(output_directory, File.basename(file))

  # Repair the file
  repair_file(file, output_file)
end

puts "All files repaired!"
