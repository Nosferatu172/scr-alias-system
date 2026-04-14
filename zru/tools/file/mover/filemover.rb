#!/usr/bin/env ruby
# Script Name: filemover.rb
# ID: SCR-ID-20260329032702-W7SJGAAUI0
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: filemover

require 'fileutils'

WINPROFILE = ENV["WINPROFILE"]

# Move a file from source to destination
def move_file(source, destination)
  begin
    FileUtils.mv(source, destination)
    puts "File moved successfully from #{source} to #{destination}"
  rescue StandardError => e
    puts "Error moving file: #{e.message}"
  end
end

# Example usage
source_path = "#{WINPROFILE}/Documents/"
destination_path = "/mnt/d/Wyvern/Documents/"

move_file(source_path, destination_path)
