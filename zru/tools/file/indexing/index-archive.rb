#!/usr/bin/env ruby
# Script Name: index-archive.rb
# ID: SCR-ID-20260329032541-7VVMDN7AM4
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: index-archive

require 'csv'
require 'fileutils'
require 'colorize'

# Prompt user for target directory
def prompt_for_directory
  puts "Enter the full path of the folder you want to index:".light_blue
  print "Path: ".yellow
  target_folder = gets.strip

  if target_folder.downcase == 'exit'
    puts "Exiting the script.".red
    exit
  end

  unless Dir.exist?(target_folder)
    puts "Folder does not exist. Exiting.".red
    exit
  end

  target_folder
end

def confirm_exit
  print "Do you want to exit? (y/n): ".yellow
  choice = gets.strip.downcase
  exit if choice == 'y'
end

# Main logic
target_folder = prompt_for_directory

# Create 'logs' folder if it doesn't exist
logs_folder = "#{target_folder}/logs"
FileUtils.mkdir_p(logs_folder)

# Create timestamped CSV file
timestamp = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
csv_filename = "#{logs_folder}/index_log_#{timestamp}.csv"

# Write file list to CSV
CSV.open(csv_filename, "w") do |csv|
  csv << ["Filename", "Path"]
  Dir.glob("#{target_folder}/**/*").each do |file|
    next if File.directory?(file) || file.start_with?(logs_folder)
    csv << [File.basename(file), file]
  end
end

puts "Indexing complete! Log saved to: #{csv_filename}".green

# Offer to delete previous logs
print "Would you like to delete any previous log files? (y/n): ".yellow
delete_choice = gets.strip.downcase

if delete_choice == 'y'
  log_files = Dir.glob("#{logs_folder}/*.csv")

  if log_files.empty?
    puts "No log files found to delete.".red
  else
    puts "\nHere are your log files:".light_magenta
    log_files.each_with_index do |file, index|
      puts "[#{index + 1}] #{File.basename(file)}".light_yellow
    end

    print "\nEnter numbers to delete (separate by commas) or type 'exit' to cancel: ".yellow
    input = gets.strip
    exit if input.downcase == 'exit'

    numbers_to_delete = input.split(",").map(&:to_i)

    numbers_to_delete.each do |num|
      if num.between?(1, log_files.length)
        file_to_delete = log_files[num - 1]
        File.delete(file_to_delete)
        puts "Deleted: #{File.basename(file_to_delete)}".green
      else
        puts "Invalid selection: #{num}".red
      end
    end
  end
else
  puts "No files were deleted.".blue
end

# Confirm exit after task
confirm_exit
