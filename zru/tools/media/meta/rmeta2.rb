#!/usr/bin/env ruby
# Script Name: meta2.rb
# ID: SCR-ID-20260404035133-GP8K2DPWD6
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: meta2

# Ultra-Fast Universal Metadata Cleaner (Optimized for High-Core CPUs like i9-14900K)

require 'fileutils'
require 'time'
require 'thread'
require 'etc'

# --- CONFIG ---
LOG_DIR = "/mnt/c/zru/meta/logs"
UNDO_DIR = "#{LOG_DIR}/undo"
THREADS = [Etc.nprocessors * 2, 32].min  # aggressive threading cap

FileUtils.mkdir_p(LOG_DIR)
FileUtils.mkdir_p(UNDO_DIR)

SKIP_EXT = %w[.exe .dll .sys]

# --- GLOBAL STATS ---
$processed = 0
$failed = 0
$mutex = Mutex.new
$start_time = Time.now

# --- HELPERS ---
def prompt(msg)
  print "#{msg} "
  gets.strip
end

def timestamp
  Time.now.utc.iso8601.gsub(':', '-')
end

def log_action(logfile, content)
  File.open(logfile, 'a') { |f| f.puts(content) }
end

def update_stats(success)
  $mutex.synchronize do
    if success
      $processed += 1
    else
      $failed += 1
    end
  end
end

# --- PLUGIN SYSTEM ---
class Handler
  def supports?(file); false; end
  def process(file); raise NotImplementedError; end
end

# --- VIDEO/AUDIO HANDLER ---
class FFmpegHandler < Handler
  MEDIA_EXT = %w[.mp4 .mkv .mov .avi .wmv .flv .webm .mp3 .wav .flac .aac .m4a .ogg]

  def supports?(file)
    MEDIA_EXT.include?(File.extname(file).downcase)
  end

  def process(file)
    tmp = "#{file}.tmp"
    cmd = "ffmpeg -loglevel error -i \"#{file}\" -map_metadata -1 -c copy \"#{tmp}\" -y"
    success = system(cmd)
    FileUtils.mv(tmp, file, force: true) if success && File.exist?(tmp)
    success
  end
end

# --- IMAGE HANDLER (LOSSLESS + FAST) ---
class ImageHandler < Handler
  IMAGE_EXT = %w[.jpg .jpeg .png .webp .bmp .tiff .gif]

  def supports?(file)
    IMAGE_EXT.include?(File.extname(file).downcase)
  end

  def process(file)
    ext = File.extname(file).downcase

    case ext
    when ".jpg", ".jpeg"
      system("jpegtran -copy none -optimize -perfect \"#{file}\" > \"#{file}.tmp\" && mv \"#{file}.tmp\" \"#{file}\"")
    when ".png"
      system("convert \"#{file}\" -strip \"#{file}\"")
    else
      system("mogrify -strip \"#{file}\"")
    end
  end
end

# --- PDF HANDLER ---
class PDFHandler < Handler
  def supports?(file)
    File.extname(file).downcase == ".pdf"
  end

  def process(file)
    tmp = "#{file}.tmp.pdf"
    cmd = "qpdf --linearize --object-streams=generate \"#{file}\" \"#{tmp}\""
    success = system(cmd)
    FileUtils.mv(tmp, file, force: true) if success && File.exist?(tmp)
    success
  end
end

# --- DOCX HANDLER ---
class DocxHandler < Handler
  def supports?(file)
    File.extname(file).downcase == ".docx"
  end

  def process(file)
    system("exiftool -all= -overwrite_original \"#{file}\"")
  end
end

# --- FALLBACK ---
class ExiftoolHandler < Handler
  def supports?(file); true; end
  def process(file)
    system("exiftool -all= -overwrite_original \"#{file}\"")
  end
end

HANDLERS = [
  FFmpegHandler.new,
  ImageHandler.new,
  PDFHandler.new,
  DocxHandler.new,
  ExiftoolHandler.new
]

# --- CORE PROCESS ---
def process_file(file, backup_dir, log_file, dry_run)
  return if SKIP_EXT.include?(File.extname(file).downcase)

  handler = HANDLERS.find { |h| h.supports?(file) }
  backup_path = File.join(backup_dir, file)

  unless dry_run
    FileUtils.mkdir_p(File.dirname(backup_path))
    FileUtils.cp(file, backup_path)
  end

  success = dry_run ? true : handler.process(file)

  update_stats(success)

  log_action(log_file, "#{file} | backup: #{backup_path}") if success
end

# --- PROGRESS MONITOR ---
def progress_thread(total)
  Thread.new do
    loop do
      sleep 1
      elapsed = Time.now - $start_time
      rate = ($processed / elapsed).round(2)

      print "\rProcessed: #{$processed}/#{total} | Failed: #{$failed} | #{rate} files/sec"
    end
  end
end

# --- MULTITHREADED ENGINE ---
def process_directory(dir, recursive, dry_run)
  log_file = File.join(LOG_DIR, "log-#{timestamp}.txt")
  backup_dir = File.join(UNDO_DIR, "backup-#{timestamp}")

  pattern = recursive ? "**/*" : "*"
  files = Dir.glob(File.join(dir, pattern)).select { |f| File.file?(f) }

  total = files.size
  queue = Queue.new
  files.each { |f| queue << f }

  progress = progress_thread(total)

  workers = THREADS.times.map do
    Thread.new do
      loop do
        file = queue.pop(true) rescue nil
        break unless file
        process_file(file, backup_dir, log_file, dry_run)
      end
    end
  end

  workers.each(&:join)
  progress.kill

  puts "\n✅ DONE"
  puts "Processed: #{$processed} | Failed: #{$failed}"
  puts "Log: #{log_file}"
end

# --- UNDO ---
def undo_changes
  backups = Dir.glob(File.join(UNDO_DIR, "backup-*"))
  return puts "No backups." if backups.empty?

  latest = backups.sort.last
  puts "Restoring from #{latest}"

  Dir.glob("#{latest}/**/*").each do |file|
    next unless File.file?(file)

    original = file.sub(latest + "/", "")
    FileUtils.mkdir_p(File.dirname(original))
    FileUtils.cp(file, original, preserve: true)
  end

  puts "Restore complete"
end

# --- MENU ---
loop do
  puts "\n===== Ultra Metadata Cleaner ====="
  puts "Threads: #{THREADS}"
  puts "1. Clean directory"
  puts "2. Undo"
  puts "3. Exit"

  case prompt("Choose:")
  when "1"
    dir = prompt("Directory:")
    next puts "Invalid" unless Dir.exist?(dir)

    recursive = prompt("Recursive? (y/n):").downcase.start_with?("y")
    dry = prompt("Dry run? (y/n):").downcase.start_with?("y")

    process_directory(dir, recursive, dry)

  when "2"
    undo_changes

  when "3"
    break

  else
    puts "Invalid"
  end
end
