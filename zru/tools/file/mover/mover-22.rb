#!/usr/bin/env ruby
# Script Name: mover-22.rb
# ID: SCR-ID-20260329032708-K6JD2YF8I9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mover-22

require 'fileutils'
require 'etc'
require 'thread'

# Prompt user
print "Enter source directory: "
source_dir = gets.chomp

print "Enter destination directory: "
dest_dir = gets.chomp

puts "Which file types do you want to copy?"
puts "1. MP3"
puts "2. MP4"
puts "3. Both"
print "Enter choice (1/2/3): "
choice = gets.chomp.to_i

extensions = case choice
             when 1 then ['mp3']
             when 2 then ['mp4']
             when 3 then ['mp3', 'mp4']
             else
               puts "Invalid choice. Defaulting to MP3."
               ['mp3']
             end

FileUtils.mkdir_p(dest_dir)

# Get all files
all_files = extensions.flat_map do |ext|
  Dir.glob(File.join(source_dir, '**', "*.#{ext}"))
end

# Setup thread pool
cpu_count = Etc.nprocessors
queue = Queue.new
all_files.each { |file| queue << file }

threads = []
cpu_count.times do
  threads << Thread.new do
    while !queue.empty?
      begin
        file_path = queue.pop(true)
        file_name = File.basename(file_path)
        dest_path = File.join(dest_dir, file_name)

        # Avoid overwrites
        if File.exist?(dest_path)
          base = File.basename(file_name, ".*")
          ext = File.extname(file_name)
          count = 1
          loop do
            new_name = "#{base}_#{count}#{ext}"
            dest_path = File.join(dest_dir, new_name)
            break unless File.exist?(dest_path)
            count += 1
          end
        end

        FileUtils.cp(file_path, dest_path)
        puts "Copied #{file_path} → #{dest_path}"
      rescue ThreadError
        # Queue empty
      end
    end
  end
end

threads.each(&:join)

puts "Done! Copied #{all_files.size} file#{'s' if all_files.size != 1} using #{cpu_count} threads."
