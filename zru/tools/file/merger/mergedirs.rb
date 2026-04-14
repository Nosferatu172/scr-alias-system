#!/usr/bin/env ruby
# Script Name: mergedirs.rb
# ID: SCR-ID-20260329032646-JX9KBBQEO5
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mergedirs

require 'fileutils'
require 'time'
require 'json'
require 'optparse'
require 'digest'
require 'ruby-progressbar'
require 'colorize'

# ==========================
# FInding itself Phase
# ==========================
SCRIPT_DIR = File.dirname(File.realpath(__FILE__))

LOG_DIR = File.join(SCRIPT_DIR, "logs")
BACKUP_DIR = File.join(SCRIPT_DIR, "backup")

FileUtils.mkdir_p(LOG_DIR)
FileUtils.mkdir_p(BACKUP_DIR)

FileUtils.mkdir_p(LOG_DIR)
FileUtils.mkdir_p(BACKUP_DIR)

# ===========================

def timestamp
  Time.now.utc.strftime('%Y%m%d-%H%M%S')
end

def log_action(log_path, entry, format)
  case format
  when 'json'
    File.open(log_path, 'a') { |f| f.puts(entry.to_json) }
  when 'csv'
    File.open(log_path, 'a') do |f|
      if f.size == 0
        f.puts "time,action,file,from,to"
      end
      f.puts [entry[:time], entry[:action], entry[:file], entry[:from], entry[:to]].join(',')
    end
  else
    File.open(log_path, 'a') { |f| f.puts(entry.inspect) }
  end
end

def backup_file(file_path, backup_subdir)
  return unless File.file?(file_path)
  FileUtils.mkdir_p(backup_subdir)
  FileUtils.cp(file_path, File.join(backup_subdir, File.basename(file_path)))
end

def sha256(path)
  Digest::SHA256.hexdigest(File.read(path))
end

def colorize_action(action)
  case action
  when 'copied' then action.colorize(:green)
  when 'overwrite-newer' then action.colorize(:yellow)
  when 'backup-overwrite', 'conflict-backup' then action.colorize(:light_yellow)
  when 'renamed-copy' then action.colorize(:cyan)
  when 'skipped-duplicate', 'kept-older' then action.colorize(:light_black)
  else action.colorize(:default)
  end
end

options = {
  log_format: 'json',
  dry_run: false,
  include_ext: nil,
  exclude_ext: nil,
  conflict_mode: 'backup' # default
}

OptionParser.new do |opts|
  opts.banner = "Usage: dirmerge.rb [options]"

  opts.on("--log-format FORMAT", "Log format: json or csv") { |v| options[:log_format] = v.downcase }
  opts.on("--dry-run", "Dry run mode (no changes made)") { options[:dry_run] = true }
  opts.on("--include-ext x,y,z", Array, "Only include these extensions (comma separated)") { |v| options[:include_ext] = v.map(&:downcase) }
  opts.on("--exclude-ext x,y,z", Array, "Exclude these extensions (comma separated)") { |v| options[:exclude_ext] = v.map(&:downcase) }
  opts.on("--conflict-mode MODE", "Conflict resolution: backup, newest, rename, checksum") { |v| options[:conflict_mode] = v.downcase }
  opts.on("-h", "--help", "Prints this help") { puts opts; exit }
end.parse!

puts "Enter source directory 1:".colorize(:light_blue)
src1 = gets.strip
puts "Enter source directory 2:".colorize(:light_blue)
src2 = gets.strip
puts "Enter destination merge directory:".colorize(:light_blue)
dest = gets.strip

backup_subdir = File.join(BACKUP_DIR, timestamp)
FileUtils.mkdir_p(backup_subdir)
log_path = File.join(LOG_DIR, "merge-#{timestamp}.#{options[:log_format]}")

# Gather all files from both sources respecting include/exclude filters
files = []
[src1, src2].each do |src|
  Dir.glob(File.join(src, '**', '*')).each do |file|
    next unless File.file?(file)

    ext = File.extname(file).delete('.').downcase
    next if options[:include_ext] && !options[:include_ext].include?(ext)
    next if options[:exclude_ext] && options[:exclude_ext].include?(ext)

    files << [src, file]
  end
end

total_files = files.size

puts "Found #{total_files} files to process.".colorize(:light_magenta)
progressbar = ProgressBar.create(
  total: total_files,
  format: '%a %B %p%% %t',
  smoothing: 0.6
)

files.each do |src, file|
  relative_path = file.sub(/^#{Regexp.escape(src)}\/?/, '')
  dest_path = File.join(dest, relative_path)

  entry = {
    time: Time.now.utc.iso8601,
    action: nil,
    file: relative_path,
    from: file,
    to: dest_path
  }

  if File.exist?(dest_path)
    case options[:conflict_mode]
    when 'newest'
      src_mtime = File.mtime(file)
      dest_mtime = File.mtime(dest_path)
      if src_mtime > dest_mtime
        entry[:action] = 'overwrite-newer'
        backup_file(dest_path, File.join(backup_subdir, File.dirname(relative_path))) unless options[:dry_run]
        FileUtils.cp(file, dest_path) unless options[:dry_run]
      else
        entry[:action] = 'kept-older'
      end
    when 'rename'
      new_name = File.join(dest, File.dirname(relative_path), File.basename(file, '.*') + "_#{timestamp}" + File.extname(file))
      entry[:action] = 'renamed-copy'
      entry[:to] = new_name
      FileUtils.mkdir_p(File.dirname(new_name)) unless options[:dry_run]
      FileUtils.cp(file, new_name) unless options[:dry_run]
    when 'checksum'
      if sha256(file) == sha256(dest_path)
        entry[:action] = 'skipped-duplicate'
      else
        entry[:action] = 'backup-overwrite'
        backup_file(dest_path, File.join(backup_subdir, File.dirname(relative_path))) unless options[:dry_run]
        FileUtils.cp(file, dest_path) unless options[:dry_run]
      end
    else # default: backup
      entry[:action] = 'conflict-backup'
      backup_file(dest_path, File.join(backup_subdir, File.dirname(relative_path))) unless options[:dry_run]
      FileUtils.cp(file, dest_path) unless options[:dry_run]
    end
  else
    entry[:action] = 'copied'
    FileUtils.mkdir_p(File.dirname(dest_path)) unless options[:dry_run]
    FileUtils.cp(file, dest_path) unless options[:dry_run]
  end

  log_action(log_path, entry, options[:log_format])

  print "#{colorize_action(entry[:action])}: #{relative_path}\n"
  progressbar.increment
end

puts "\n#{options[:dry_run] ? '[Dry Run Completed]'.colorize(:light_yellow) : '[Merge Completed]'.colorize(:green)}"
puts "Logs saved to #{log_path}".colorize(:light_blue)
puts "Backup directory: #{backup_subdir}".colorize(:light_blue) unless options[:dry_run]
