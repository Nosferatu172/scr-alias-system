#!/usr/bin/env ruby
# Script Name: capitalize_filenames-large.rb
# ID: SCR-ID-20260329032526-IFBTXN39GP
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: capitalize_filenames-large

require 'fileutils'
require 'csv'

LOG_DIR = File.expand_path("/mnt/c/zru/filenames/logs/")
LOG_CSV = File.join(LOG_DIR, "rename_log.csv")

FileUtils.mkdir_p(LOG_DIR)

def title_case(filename)
  filename.downcase.gsub(/\b[a-z]/) { |match| match.upcase }
end

def log_action(changes)
  CSV.open(LOG_CSV, 'a') do |csv|
    changes.each { |change| csv << change }
  end
end

def rename_files_in_directory(directory)
  renamed = []
  Dir.entries(directory).each do |file|
    next if file == '.' || file == '..'
    old_path = File.join(directory, file)
    next unless File.file?(old_path)

    new_name = title_case(file)
    new_path = File.join(directory, new_name)

    next if old_path == new_path

    # Case-insensitive filesystem fix
    if old_path.downcase == new_path.downcase
      temp_path = File.join(directory, "__temp__#{rand(100000)}")
      File.rename(old_path, temp_path)
      File.rename(temp_path, new_path)
    else
      File.rename(old_path, new_path)
    end

    puts "Renamed: #{file} -> #{new_name}"
    renamed << [Time.now.to_f, old_path, new_path]
  end
  log_action(renamed) unless renamed.empty?
end

def undo_last_changes
  return puts "No log found." unless File.exist?(LOG_CSV)

  history = CSV.read(LOG_CSV)
  return puts "Nothing to undo." if history.empty?

  last_time = history.map { |row| row[0].to_f }.max
  to_undo = history.select { |row| row[0].to_f == last_time }

  to_undo.reverse_each do |_, old_path, new_path|
    if File.exist?(new_path)
      File.rename(new_path, old_path)
      puts "Reverted: #{new_path} -> #{old_path}"
    else
      puts "Missing: #{new_path} (couldn't revert)"
    end
  end

  # Remove undone entries from the log
  remaining = history.reject { |row| row[0].to_f == last_time }
  CSV.open(LOG_CSV, 'w') { |csv| remaining.each { |row| csv << row } }
end

def main
  puts "--- Filename Capitalizer (with CSV + Fixes) ---"

  loop do
    puts "\nChoose an option:"
    puts "1. Enter a directory path"
    puts "2. Undo last changes"
    puts "3. Exit"
    print "> "
    choice = gets.strip

    case choice
    when '1'
      print "\nEnter directory path:\n> "
      dir = gets.strip
      if Dir.exist?(dir)
        rename_files_in_directory(dir)
      else
        puts "Directory does not exist!"
      end
    when '2'
      undo_last_changes
    when '3'
      puts "Goodbye!"
      break
    else
      puts "Invalid option. Try again."
    end
  end
end

main
