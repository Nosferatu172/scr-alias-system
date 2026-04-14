#!/usr/bin/env ruby
# Script Name: capitalize_filenames.rb
# ID: SCR-ID-20260329032532-VMBX12M60W
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: capitalize_filenames

require 'csv'
require 'fileutils'

class FilenameCapitalizer
  def initialize
    @log_directory = '/mnt/c/zru/filenames/'
    @log_file = "#{@log_directory}capitalizer.log"

    # Ensure the log directory exists, and create it if not
    unless Dir.exist?(@log_directory)
      Dir.mkdir(@log_directory)
      puts "Created missing directory: #{@log_directory}"
    end
  end

  def log_action(message)
    # Open the log file in append mode and log the action
    File.open(@log_file, 'a') do |log|
      log.puts "#{Time.now} - #{message}"
    end
  end

  def process_filenames(directory)
    # First pass: lowercase everything
    Dir.foreach(directory) do |file|
      next if file == '.' || file == '..'

      old_file_path = File.join(directory, file)
      new_file_name = file.downcase
      new_file_path = File.join(directory, new_file_name)

      # Skip if the filename is already lowercase
      next if old_file_path == new_file_path

      # Rename the file to lowercase
      begin
        File.rename(old_file_path, new_file_path)
        log_action("Lowercased: #{file} -> #{new_file_name}")
        puts "Lowercased: #{file} -> #{new_file_name}"
      rescue StandardError => e
        puts "Error renaming file #{file}: #{e.message}"
      end
    end

    # Second pass: capitalize first letter of each word
    Dir.foreach(directory) do |file|
      next if file == '.' || file == '..'

      old_file_path = File.join(directory, file)
      new_file_name = file.split.map(&:capitalize).join(' ')
      new_file_path = File.join(directory, new_file_name)

      # Skip if the filename is already properly capitalized
      next if old_file_path == new_file_path

      # Rename the file
      begin
        File.rename(old_file_path, new_file_path)
        log_action("Capitalized: #{file} -> #{new_file_name}")
        puts "Capitalized: #{file} -> #{new_file_name}"
      rescue StandardError => e
        puts "Error renaming file #{file}: #{e.message}"
      end
    end
  end

  def undo(directory)
    # Read the CSV file and revert the changes
    if File.exist?('rename_history.csv')
      CSV.foreach('rename_history.csv', headers: true) do |row|
        old_name = row['old_name']
        new_name = row['new_name']
        old_file_path = File.join(directory, old_name)
        new_file_path = File.join(directory, new_name)

        begin
          File.rename(new_file_path, old_file_path)
          log_action("Reverted: #{new_name} -> #{old_name}")
          puts "Reverted: #{new_name} -> #{old_name}"
        rescue StandardError => e
          puts "Error reverting file #{new_name}: #{e.message}"
        end
      end
    else
      puts "No rename history found to undo."
    end
  end

  def main
    loop do
      puts "--- Filename Capitalizer ---"
      puts "1. Enter directory path to capitalize filenames"
      puts "2. Undo last action"
      puts "3. Exit"
      print "Choose an option (1, 2, or 3): "
      input = gets.chomp

      case input
      when '1'
        # Prompt for directory input on a new line to allow longer paths
        print "Enter the directory path to process filenames: "
        directory_to_process = gets.chomp
        process_filenames(directory_to_process)
      when '2'
        # Prompt for directory input on a new line to allow longer paths
        print "Enter the directory path to undo changes: "
        directory_to_undo = gets.chomp
        undo(directory_to_undo)
      when '3'
        puts "Exiting..."
        break
      else
        puts "Invalid option. Please choose 1, 2, or 3."
      end
    end
  end
end

# Run the script
capitalizer = FilenameCapitalizer.new
capitalizer.main
