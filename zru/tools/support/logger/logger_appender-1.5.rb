#!/usr/bin/env ruby
# Script Name: logger_appender-1.5.rb
# ID: SCR-ID-20260329032248-L6BU7KKA6B
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: logger_appender-1.5

require 'fileutils'
require 'time'

# === CONFIG ===
DEFAULT_TARGET_DIR = '/mnt/c/zru/'
DEFAULT_LOG_BASE = '/mnt/c/zru/logs'
BACKUP_DIR = File.join(DEFAULT_LOG_BASE, 'backup', 'logger-appender')

# === HELPERS ===
def create_identifier_block(script_name)
  log_folder = File.join(DEFAULT_LOG_BASE, script_name.gsub(/\.rb$/, ''))
  log_path = File.join(log_folder, 'script-identifier.txt')
  <<~RUBY

    require 'fileutils'
    script_name = File.basename(__FILE__)
    target_path = "#{log_path}"
    FileUtils.mkdir_p(File.dirname(target_path))
    identifier_info = "Script: \#{script_name}\nPath: \#{target_path}\nTime: \#{Time.now}\n"
    File.write(target_path, identifier_info)
    puts "[Identifier written to \#{target_path}]"
  RUBY
end

def inject_identifier_code(file_path)
  script_name = File.basename(file_path)
  content = File.read(file_path)
  backup_path = File.join(BACKUP_DIR, script_name)

  FileUtils.mkdir_p(File.dirname(backup_path))

  unless File.exist?(backup_path)
    File.write(backup_path, content)
    puts "[Backup Created] #{backup_path}"
  else
    puts "[Backup Exists] Skipping overwrite: #{backup_path}"
  end

  identifier_code = create_identifier_block(script_name)
  updated_content = identifier_code + "\n" + content
  File.write(file_path, updated_content)
  puts "[Injected] #{script_name}"
end

def undo_identifier_injection(file_path)
  script_name = File.basename(file_path)
  backup_path = File.join(BACKUP_DIR, script_name)

  if File.exist?(backup_path)
    original_content = File.read(backup_path)
    File.write(file_path, original_content)
    puts "[Restored] #{script_name} from #{backup_path}"
  else
    puts "[No Backup Found] for #{script_name}"
    puts "Expected backup at: #{backup_path}"
  end
end

def scan_and_inject(dir)
  Dir.glob(File.join(dir, '*.rb')).each do |file|
    inject_identifier_code(file)
  end
end

def scan_and_undo(dir)
  Dir.glob(File.join(dir, '*.rb')).each do |file|
    undo_identifier_injection(file)
  end
end

# === EXECUTION ===
puts "Choose action:"
puts "1. Inject log identifier"
puts "2. Undo changes (restore backups)"
puts "3. Inject into custom folder"
print "> "
choice = gets.strip

case choice
when '1'
  scan_and_inject(DEFAULT_TARGET_DIR)
when '2'
  scan_and_undo(DEFAULT_TARGET_DIR)
when '3'
  print "Enter full path to target folder: "
  folder = gets.strip
  scan_and_inject(folder)
else
  puts "Invalid choice. Exiting."
end
