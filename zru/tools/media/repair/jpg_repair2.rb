#!/usr/bin/env ruby
# Script Name: jpg_repair2.rb
# ID: SCR-ID-20260329032901-01QQJHSGY9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: jpg_repair2

# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'fileutils'
require 'parallel'
require 'open3'
require 'time'

# === Session Paths ===
timestamp = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
SESSION_DIR = File.join("/mnt/c/zru/logs/jpg-repair", timestamp)
BACKUP_DIR = File.join(SESSION_DIR, "backups")
LOG_FILE = File.join(SESSION_DIR, "jpg_repair_log.txt")

# === Ensure Directories Exist ===
FileUtils.mkdir_p(BACKUP_DIR)
File.write(LOG_FILE, "")

# === Logging ===
def log(msg)
  puts msg
  File.open(LOG_FILE, "a:utf-8") { |f| f.puts msg }
end

# === JPEG Validity Check ===
def valid_jpeg?(file)
  stdout, _ = Open3.capture2("jpeginfo -c \"#{file}\"")
  stdout.include?("OK")
end

# === Strip EXIF ===
def strip_exif(file)
  system("exiftool -overwrite_original -all= \"#{file}\" > /dev/null 2>&1")
end

# === Backup Path ===
def backup_path(file)
  File.join(BACKUP_DIR, File.basename(file) + ".bak")
end

# === Re-encode Using ImageMagick ===
def reencode_jpeg(file)
  tmp = file + ".reencoded.jpg"
  if system("convert \"#{file}\" \"#{tmp}\"")
    FileUtils.mv(tmp, file, force: true)
    log "[↻] Re-encoded: #{file}"
  else
    log "[x] Failed to re-encode: #{file}"
  end
end

# === Core Repair Function ===
def repair_jpeg(file)
  begin
    data = File.open(file, "rb") { |f| f.read.force_encoding("ASCII-8BIT") }

    changed = false
    unless data.start_with?("\xFF\xD8".b)
      log "[!] SOI header missing: #{file}"
      changed = true
      data = "\xFF\xD8".b + data
    end

    unless data.end_with?("\xFF\xD9".b)
      log "[!] EOI footer missing: #{file}"
      changed = true
      data += "\xFF\xD9".b
    end

    if changed
      bak = backup_path(file)
      File.write(bak, data, mode: "wb") unless File.exist?(bak)
      File.write(file, data, mode: "wb")
    end

    unless valid_jpeg?(file)
      log "[~] Invalid JPEG after header fix: #{file}. Trying to strip EXIF..."
      strip_exif(file)
    end

    unless valid_jpeg?(file)
      log "[!] Still invalid. Trying re-encode..."
      reencode_jpeg(file)
    end

    if valid_jpeg?(file)
      log "[✓] Repaired successfully: #{file}"
    else
      log "[x] Still broken after all steps: #{file}"
    end

  rescue => e
    log "[!] Error on #{file}: #{e.class} - #{e.message}"
  end
end

# === Undo ===
def undo_repair(original_path)
  bak = backup_path(original_path)
  if File.exist?(bak)
    FileUtils.cp(bak, original_path)
    log "[↩] Restored backup to: #{original_path}"
  else
    log "[x] No backup found for: #{original_path}"
  end
end

# === Repair All ===
def scan_and_repair(dir)
  puts "\nScanning: #{dir}"
  files = Dir.glob("#{dir}/**/*.{jpg,jpeg,JPG,JPEG}")
  puts "[=] Found #{files.size} file(s). Repairing using #{Parallel.processor_count} cores..."
  Parallel.each(files, in_processes: Parallel.processor_count) do |file|
    repair_jpeg(file)
  end
end

# === Undo All ===
def undo_all(dir)
  puts "\nUndoing all repairs in: #{dir}"
  Dir.glob(File.join(BACKUP_DIR, "*.bak")).each do |bak|
    original = File.join(dir, File.basename(bak).sub(/\.bak$/, ''))
    undo_repair(original)
  end
end

# === Main Menu ===
puts "== JPEG Repair Utility =="
puts "Session Directory: #{SESSION_DIR}"
puts "Type 'exit' anytime to quit."

print "Enter directory to scan: "
input = gets.chomp.strip
exit if input.downcase == 'exit'

unless Dir.exist?(input)
  puts "[x] Directory not found."
  exit
end

loop do
  puts "\nOptions:"
  puts " 1 - Scan & Repair"
  puts " 2 - Undo Repairs"
  puts " e - Exit"
  print "Choose: "
  choice = gets.chomp.strip

  case choice
  when '1'
    scan_and_repair(input)
  when '2'
    undo_all(input)
  when 'e', 'exit'
    puts "Exiting. Log saved to #{LOG_FILE}"
    break
  else
    puts "Invalid option."
  end
end
