#!/usr/bin/env ruby
# Script Name: filesorter.rb
# ID: SCR-ID-20260329033005-NFV0S307HN
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: filesorter

require 'fileutils'
require 'json'
require 'time'

EXTENSION_MAP = {
  'Music' => ['.mp3', '.wav', '.flac'],
  'Videos' => ['.mp4', '.mkv', '.avi'],
  'Images' => ['.jpg', '.jpeg', '.png', '.gif'],
  'Documents' => ['.pdf', '.docx', '.txt'],
  'Archives' => ['.zip', '.rar', '.7z'],
  'Scripts' => ['.py', '.rb', '.sh'],
  'Executables' => ['.exe', '.msi']
}

LOG_DIR = '/mnt/c/zru/sorter/logs/'

def get_target_dir
  loop do
    print "📂 Enter directory to sort (or 'exit'): "
    input = gets.chomp.strip
    exit if input.downcase == 'exit'
    return input if Dir.exist?(input)
    puts "❌ Invalid directory. Try again."
  end
end

def sort_files(directory)
  moved_files = []

  puts "📦 Sorting files in: #{directory}"
  Dir.foreach(directory) do |file|
    path = File.join(directory, file)
    next unless File.file?(path)

    ext = File.extname(file).downcase
    moved = false

    EXTENSION_MAP.each do |folder, extensions|
      if extensions.include?(ext)
        folder_path = File.join(directory, folder)
        FileUtils.mkdir_p(folder_path)
        new_path = File.join(folder_path, file)
        FileUtils.mv(path, new_path)
        moved_files << { from: path, to: new_path }
        puts "✅ Moved: #{file} → #{folder}/"
        moved = true
        break
      end
    end

    puts "⚠️  Skipped: #{file} (unknown type)" unless moved
  end

  unless moved_files.empty?
    FileUtils.mkdir_p(LOG_DIR)
    log_name = "log_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(File.join(LOG_DIR, log_name), JSON.pretty_generate(moved_files))
    puts "📝 Log saved: #{log_name}"
  else
    puts "📭 No files moved."
  end
end

def undo_last_sort
  return puts "❌ No logs to undo." unless Dir.exist?(LOG_DIR)

  logs = Dir.entries(LOG_DIR).select { |f| f.end_with?('.json') }.sort.reverse
  return puts "❌ No logs to undo." if logs.empty?

  last_log = File.join(LOG_DIR, logs.first)
  moves = JSON.parse(File.read(last_log))

  moves.reverse.each do |move|
    if File.exist?(move['to'])
      FileUtils.mkdir_p(File.dirname(move['from']))
      FileUtils.mv(move['to'], move['from'])
      puts "🔁 Restored: #{File.basename(move['to'])}"
    end
  end

  File.delete(last_log)
  puts "🧼 Log removed: #{File.basename(last_log)}"
end

def main
  loop do
    puts "\n📌 Choose an action:"
    puts "1. Sort files in directory"
    puts "2. Undo last sort"
    puts "3. Exit"
    print "Enter choice (1/2/3): "
    choice = gets.chomp.strip

    case choice
    when '1'
      dir = get_target_dir
      sort_files(dir)
    when '2'
      undo_last_sort
    when '3'
      puts "👋 Goodbye!"
      break
    else
      puts "❌ Invalid choice."
    end
  end
end

main
