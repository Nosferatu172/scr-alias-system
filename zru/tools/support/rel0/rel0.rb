# Script Name: rel0.rb
# ID: SCR-ID-20260317120159-LEJKL79781
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rel0

require 'fileutils'
require 'time'

class FileDeleter
  def initialize
    @log_folder = '/mnt/c/zru/rel0/logs/' # You can set your log folder here
    FileUtils.mkdir_p(@log_folder) unless Dir.exist?(@log_folder)
  end

  def ask(prompt)
    print "#{prompt} "
    gets.chomp
  end

  def list_files(directory)
    Dir.entries(directory).select { |f| !['.', '..'].include? f }
  end

  def log_removal(files)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    log_file = File.join(@log_folder, "remove_log_#{timestamp}.txt")
    File.open(log_file, 'w') do |f|
      files.each { |file| f.puts(file) }
    end
    log_file
  end

  def remove_files(directory)
    files = list_files(directory)
    return puts "No files to remove." if files.empty?

    puts "\nFiles in #{directory}:"
    files.each { |file| puts "  #{file}" }

    confirmation = ask("Are you sure you want to remove these files? (y/n)")

    if confirmation.downcase == 'y'
      # Log the files being removed
      log_file = log_removal(files)

      # Remove files and store logs
      files.each do |file|
        file_path = File.join(directory, file)
        if File.exist?(file_path)
          FileUtils.mv(file_path, File.join(@log_folder, file)) # Move to backup log folder for undo
        end
      end

      puts "Files removed. Logs saved to #{log_file}"
    else
      puts "Operation canceled."
    end
  end

  def undo(directory)
    log_files = Dir.entries(@log_folder).select { |f| f.start_with?('remove_log_') }
    return puts "No log files found to undo." if log_files.empty?

    puts "Available logs for undo:"
    log_files.each_with_index do |log_file, idx|
      puts "#{idx + 1}. #{log_file}"
    end

    log_choice = ask("Enter the number of the log file you want to undo, or type 'exit' to cancel: ").to_i - 1

    if log_choice >= 0 && log_choice < log_files.length
      log_file = log_files[log_choice]
      log_path = File.join(@log_folder, log_file)
      files_to_restore = File.readlines(log_path).map(&:strip)

      files_to_restore.each do |file|
        backup_path = File.join(@log_folder, file)
        if File.exist?(backup_path)
          FileUtils.mv(backup_path, directory) # Restore files
        end
      end

      puts "Files restored from log: #{log_file}"
    else
      puts "Invalid choice or exit."
    end
  end

  def run
    directory = ask("Enter the directory to manage: ").strip
    return puts "Directory not found." unless Dir.exist?(directory)

    loop do
      action = ask("\nChoose an action:\n1. Remove files\n2. Undo last removal\n3. Exit\nEnter choice: ").to_i

      case action
      when 1
        remove_files(directory)
      when 2
        undo(directory)
      when 3
        puts "Exiting program."
        break
      else
        puts "Invalid option, please try again."
      end
    end
  end
end

# Run the script
file_deleter = FileDeleter.new
file_deleter.run
