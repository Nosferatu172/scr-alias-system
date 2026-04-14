#!/usr/bin/env ruby
# Script Name: rmeta.rb
# ID: SCR-ID-20260329032658-72PBGBDCQJ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rmeta

require 'fileutils'
require 'time'

# Configuration
LOG_DIR = "/mnt/c/zru/meta/logs"
UNDO_DIR = "#{LOG_DIR}/undo"
FileUtils.mkdir_p(LOG_DIR)
FileUtils.mkdir_p(UNDO_DIR)

# Prompt user
def prompt(message)
  print "#{message} "
  gets.strip
end

# Timestamp for log naming
def timestamp
  Time.now.utc.iso8601.gsub(':', '-')
end

# Logging
def log_action(logfile, content)
  File.open(logfile, 'a') { |f| f.puts(content) }
end

# Remove metadata from file
def remove_metadata(file, backup_dir, log_file)
  basename = File.basename(file)
  ext = File.extname(file).downcase
  backup_path = File.join(backup_dir, basename)
  temp_file = "#{file}.temp#{ext}"

  # Backup original
  FileUtils.cp(file, backup_path)

  # ffmpeg command
  cmd = case ext
        when ".mp3"
          "ffmpeg -i \"#{file}\" -map_metadata -1 -c:a copy \"#{temp_file}\" -y"
        when ".mp4"
          "ffmpeg -i \"#{file}\" -map_metadata -1 -c copy \"#{temp_file}\" -y"
        else
          puts "Unsupported format: #{file}"
          return
        end

  puts "Processing: #{file}"
  system(cmd)

  if File.exist?(temp_file)
    FileUtils.mv(temp_file, file, force: true)
    log_action(log_file, "#{file} | backup: #{backup_path}")
    puts "✅ Metadata removed: #{file}"
  else
    puts "❌ Failed to process: #{file}"
  end

  # Cleanup temp file if something went wrong
  File.delete(temp_file) if File.exist?(temp_file)
end

# Process all supported files in directory
def process_directory(target_dir, recursive)
  time_log = File.join(LOG_DIR, "log-#{timestamp}.txt")
  backup_dir = File.join(UNDO_DIR, "backup-#{timestamp}")
  FileUtils.mkdir_p(backup_dir)

  pattern = recursive ? "**/*.{mp3,MP3,mp4,MP4}" : "*.{mp3,MP3,mp4,MP4}"
  files = Dir.glob(File.join(target_dir, pattern))

  if files.empty?
    puts "No MP3 or MP4 files found in #{target_dir}"
    return
  end

  files.each do |file|
    next unless File.file?(file)
    remove_metadata(file, backup_dir, time_log)
  end

  puts "\n✅ Metadata removal complete. Log saved to: #{time_log}"
end

# Undo last change
def undo_changes
  backups = Dir.glob(File.join(UNDO_DIR, "backup-*")).sort
  if backups.empty?
    puts "No backups found to undo."
    return
  end

  latest = backups.last
  puts "Restoring backup from: #{latest}"
  Dir.glob(File.join(latest, "*")).each do |backup_file|
    original_path = File.join(Dir.pwd, File.basename(backup_file))
    FileUtils.cp(backup_file, original_path, preserve: true)
    puts "🔁 Restored: #{original_path}"
  end
end

# --- MAIN MENU LOOP ---
loop do
  puts "\n===== 🎵 Metadata Cleaner for MP3/MP4 ====="
  puts "1. Remove metadata from directory"
  puts "2. Undo last change"
  puts "3. Exit"
  choice = prompt("Choose an option (1/2/3):")

  case choice
  when "1"
    dir = prompt("Enter directory to process:")
    if Dir.exist?(dir)
      recursive = prompt("Include subdirectories? (y/n):").downcase.start_with?("y")
      process_directory(dir, recursive)
    else
      puts "❌ Invalid directory."
    end
  when "2"
    undo_changes
  when "3"
    puts "👋 Goodbye!"
    break
  else
    puts "❌ Invalid choice. Please try again."
  end
end