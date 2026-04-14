#!/usr/bin/env ruby
# Script Name: mover-23.rb
# ID: SCR-ID-20260329032714-L0X8RHO0ZQ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mover-23

require 'fileutils'
require 'digest'
require 'csv'
require 'time'

# Function to convert .mp4 to .mp3 using ffmpeg
def convert_mp4_to_mp3(mp4_path, mp3_path, dry_run: false)
  unless dry_run
    system("ffmpeg -i \"#{mp4_path}\" -q:a 0 -map a \"#{mp3_path}\" -y")
  end
end

# Function to compute SHA256 hash of a file
def file_hash(path)
  Digest::SHA256.file(path).hexdigest
end

# Prompt for dry-run mode
print "Dry-run mode? (yes/no): "
dry_run_input = gets.chomp.strip.downcase
dry_run = (dry_run_input == "yes")

# Prompt for directories
print "Enter source directory: "
source_dir = gets.chomp.strip

print "Enter destination directory: "
dest_dir = gets.chomp.strip

# Setup log directory and files
log_dir = "/mnt/c/ruf/logs/mover-23"
FileUtils.mkdir_p(log_dir)

timestamp = Time.now.utc.iso8601

# Open CSV files
moved_log   = CSV.open(File.join(log_dir, "moved.csv"), "a+")
skipped_log = CSV.open(File.join(log_dir, "skipped.csv"), "a+")
deleted_log = CSV.open(File.join(log_dir, "deleted.csv"), "a+")

# Headers if empty
[moved_log, skipped_log, deleted_log].each do |csv|
  csv << ["timestamp", "source", "destination", "reason"] if csv.count == 0
end

FileUtils.mkdir_p(dest_dir)

seen_names = {}
seen_hashes = {}

audio_files = Dir.glob(File.join(source_dir, '**', '*.{mp3,mp4}'))

audio_files.each do |file_path|
  ext = File.extname(file_path).downcase
  base_name = File.basename(file_path, ext)
  dest_file = "#{base_name}.mp3"
  dest_path = File.join(dest_dir, dest_file)

  # Skip if name already used or file exists
  if seen_names[base_name] || File.exist?(dest_path)
    skipped_log << [timestamp, file_path, dest_path, "Duplicate by name"]
    puts "Skipped by name: #{dest_file}"
    next
  end

  if ext == ".mp4"
    puts "Converting #{file_path} → #{dest_path}"
    convert_mp4_to_mp3(file_path, dest_path, dry_run: dry_run)
  else
    puts "Copying #{file_path} → #{dest_path}"
    FileUtils.cp(file_path, dest_path) unless dry_run
  end

  if !dry_run && File.exist?(dest_path)
    hash_val = file_hash(dest_path)
    if seen_hashes[hash_val]
      puts "Removing duplicate by hash: #{dest_file}"
      FileUtils.rm(dest_path)
      deleted_log << [timestamp, file_path, dest_path, "Duplicate by content"]
    else
      seen_hashes[hash_val] = dest_file
      seen_names[base_name] = true
      moved_log << [timestamp, file_path, dest_path, "Moved"]
    end
  elsif dry_run
    moved_log << [timestamp, file_path, dest_path, "Would be moved"]
    seen_names[base_name] = true
  end
end

# Cleanup _#.mp3 files
puts "Cleaning suffix duplicates (e.g., *_1.mp3)..."
Dir.glob(File.join(dest_dir, "*_*.mp3")).each do |dup_path|
  match = dup_path.match(/(.+)_\d+\.mp3$/)
  next unless match

  original_path = match[1] + ".mp3"
  if File.exist?(original_path)
    puts "Deleting #{dup_path} (duplicate of #{original_path})"
    FileUtils.rm(dup_path) unless dry_run
    deleted_log << [timestamp, dup_path, original_path, "Suffix duplicate"]
  end
end

[moved_log, skipped_log, deleted_log].each(&:close)

puts dry_run ? "Dry run completed." : "Done!"
