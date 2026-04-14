#!/usr/bin/env ruby
# Enhanced Text File Manager (Archive & Split)
# Cross-platform: Windows, WSL Kali Linux, Linux, macOS
# Features: Archive with tags, split files, duplicate detection, backups
# Created by: Tyler Jensen

require "colorize"
require "fileutils"
require "time"
require "optparse"
require "csv"
require "digest"

# -----------------------
# Cross-Platform Environment Detection
# -----------------------
module Platform
  def self.windows?
    (/mingw|mswin|cygwin/ =~ RUBY_PLATFORM) != nil
  end

  def self.linux?
    RUBY_PLATFORM.include?("linux")
  end

  def self.macos?
    RUBY_PLATFORM.include?("darwin")
  end

  def self.wsl?
    return false unless linux?
    version_file = "/proc/version"
    return false unless File.exist?(version_file)

    version = File.read(version_file).downcase
    return true if version.include?("microsoft") || version.include?("wsl")

    ENV['WSL_DISTRO_NAME'] || ENV['WSLENV'] ? true : false
  end

  def self.name
    return "WSL (#{ENV['WSL_DISTRO_NAME'] || 'Unknown'})" if wsl?
    return "Windows" if windows?
    return "macOS" if macos?
    return "Linux" if linux?
    "Unknown"
  end

  def self.path_separator
    windows? ? "\\" : "/"
  end

  def self.normalize_path(path)
    return path unless path
    path = File.expand_path(path) if path.start_with?('~')
    # Always use forward slashes for Ruby compatibility
    path.gsub("\\", "/")
  end
end

# -----------------------
# UTF-8 Setup for Cross-Platform
# -----------------------
begin
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
rescue
  # Fallback for older Ruby versions
end

# Windows Terminal ANSI support
if Platform.windows? && !Platform.wsl?
  begin
    `chcp 65001 >nul 2>&1` rescue nil
  rescue
    # Ignore setup failures
  end
end

# -----------------------
# Ctrl+C Handler
# -----------------------
Signal.trap("INT") do
  puts "\n⛔ Interrupted.".colorize(:red)
  exit 130
end

# -----------------------
# Configuration Management
# -----------------------
CONFIG_FILE = File.join(__dir__, "enhanced_text_manager.csv")

def setup_config(file)
  puts "📁 First-time setup required\n".colorize(:yellow)

  puts "Enter SOURCE directory (where .txt files are):"
  source = STDIN.gets&.strip

  puts "\nEnter ARCHIVE directory (where to save copies):"
  archive = STDIN.gets&.strip

  if source.to_s.empty? || archive.to_s.empty?
    puts "❌ Paths cannot be empty.".colorize(:red)
    exit 1
  end

  # Normalize paths for cross-platform
  source = Platform.normalize_path(source)
  archive = Platform.normalize_path(archive)

  CSV.open(file, "w") do |csv|
    csv << ["source", source]
    csv << ["archive", archive]
  end

  puts "\n✅ Configuration saved → #{file}".colorize(:green)
  puts "Source: #{source}"
  puts "Archive: #{archive}"
end

def load_paths(file)
  return [nil, nil] unless File.exist?(file)

  config = {}
  CSV.foreach(file) do |row|
    config[row[0]] = row[1] if row.length >= 2
  end

  source = config["source"]
  archive = config["archive"]

  # Normalize paths when loading
  source = Platform.normalize_path(source) if source
  archive = Platform.normalize_path(archive) if archive

  [source, archive]
end

# -----------------------
# Core Utilities
# -----------------------
def timestamp
  Time.now.strftime("%Y%m%d_%H%M%S_%6N")
end

def txt_files(dir)
  return [] unless Dir.exist?(dir)
  Dir.children(dir).select { |f| f.downcase.end_with?(".txt") }.sort
end

def file_hash(path)
  Digest::SHA256.file(path).hexdigest
rescue
  nil
end

def existing_hashes(dir)
  hashes = {}
  return hashes unless Dir.exist?(dir)

  Dir.children(dir).each do |f|
    next unless f.downcase.end_with?(".txt")
    path = File.join(dir, f)
    hash = file_hash(path)
    hashes[hash] = f if hash
  end

  hashes
end

def safe_readlines(path)
  encodings = ['utf-8', 'windows-1252', 'iso-8859-1']
  encodings.each do |enc|
    begin
      return File.readlines(path, encoding: enc, invalid: :replace, undef: :replace)
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      next
    end
  end
  []
rescue
  []
end

def pick_file(files)
  puts "Select a file:\n".colorize(:cyan)
  puts "  0) ALL FILES"
  files.each_with_index do |f, i|
    puts "  #{i+1}) #{f}"
  end

  print "\nChoice: "
  c = STDIN.gets&.to_i

  return :all if c == 0
  return nil if c.nil? || c < 1 || c > files.length

  files[c - 1]
end

def tag_prompt
  puts "Enter tag (spaces become underscores):"
  print "> "
  t = STDIN.gets&.strip
  exit if t.to_s.empty?
  t.gsub(/\s+/, "_")
end

# -----------------------
# Archive Operations
# -----------------------
def archive_one(src_dir, arch_dir, file, options = {})
  full_path = File.join(src_dir, file)
  hash = file_hash(full_path)

  existing = existing_hashes(arch_dir)

  if existing[hash] && !options[:force]
    puts "⚠️  Duplicate found: #{existing[hash]}".colorize(:yellow)
    return false
  end

  tag = options[:tag] || tag_prompt
  base = File.basename(file, ".txt")
  dest = "#{timestamp}_#{base}_#{tag}.txt"

  if options[:dry_run]
    puts "📦 Would archive: #{file} → #{dest}".colorize(:blue)
    return true
  end

  FileUtils.cp(full_path, File.join(arch_dir, dest))
  puts "📦 Archived: #{file} → #{dest}".colorize(:green)
  true
end

def archive_all(src_dir, arch_dir, files, options = {})
  seen = existing_hashes(arch_dir)
  archived = 0

  files.each do |f|
    hash = file_hash(File.join(src_dir, f))

    if seen[hash] && !options[:force]
      puts "⚠️  Skipping duplicate: #{f}".colorize(:yellow)
      next
    end

    base = File.basename(f, ".txt")
    dest = "#{timestamp}_#{base}.txt"

    if options[:dry_run]
      puts "📦 Would archive: #{f} → #{dest}".colorize(:blue)
    else
      FileUtils.cp(File.join(src_dir, f), File.join(arch_dir, dest))
      puts "📦 Archived: #{f} → #{dest}".colorize(:green)
    end

    archived += 1
  end

  archived
end

# -----------------------
# Split Operations
# -----------------------
def split_file(input_file, output_dir, lines_per_file = 5, options = {})
  lines = safe_readlines(input_file).reject(&:empty?)

  if lines.empty?
    puts "❌ File is empty or unreadable".colorize(:red)
    return 0
  end

  num_files = (lines.length.to_f / lines_per_file).ceil
  base_name = File.basename(input_file, ".txt")

  puts "📄 Splitting #{lines.length} lines into #{num_files} files..."

  created = 0
  num_files.times do |i|
    start_idx = i * lines_per_file
    chunk = lines[start_idx, lines_per_file]

    chunk_name = "#{timestamp}_#{base_name}_part#{i+1}.txt"
    chunk_path = File.join(output_dir, chunk_name)

    if options[:dry_run]
      puts "📦 Would create: #{chunk_name} (#{chunk.length} lines)".colorize(:blue)
    else
      File.write(chunk_path, chunk.join("\n") + "\n")
      puts "📦 Created: #{chunk_name} (#{chunk.length} lines)".colorize(:green)
    end

    created += 1
  end

  created
end

# -----------------------
# Command Line Interface
# -----------------------
options = {}

OptionParser.new do |o|
  o.banner = <<~BANNER

    📦 Enhanced Text File Manager
    Platform: #{Platform.name}
    ================================

  BANNER

  o.on('-h', '--help', 'Show detailed help') do
    puts <<~HELP

    📦 Enhanced Text File Manager
    Platform: #{Platform.name}
    ================================

    ARCHIVE MODE:
      Archive .txt files with timestamps and tags

      -a, --all           Archive ALL .txt files (no prompts)
      -i, --interactive   Interactive file selection
      -f FILE             Archive specific file
      -t TAG              Use TAG for filename (skip prompt)
      --force             Archive even if duplicate exists

    SPLIT MODE:
      Split large .txt files into smaller chunks

      -s, --split         Enable split mode
      -f FILE             File to split
      -l LINES            Lines per chunk (default: 5)
      -o DIR              Output directory

    CONFIGURATION:
      -e, --edit          Edit source/archive directories
      -c, --config        Show current configuration
      --dry-run           Preview actions without changes

    EXAMPLES:
      Archive all files:     enhanced_text_manager.rb -a
      Interactive archive:   enhanced_text_manager.rb -i
      Archive specific:      enhanced_text_manager.rb -f myfile.txt -t backup
      Split file:           enhanced_text_manager.rb -s -f bigfile.txt -l 10
      Edit config:          enhanced_text_manager.rb -e
      Show config:          enhanced_text_manager.rb -c

    CONFIG FILE: #{CONFIG_FILE}

    HELP
    exit
  end

  # Archive options
  o.on('-a', '--all', 'Archive all .txt files') { options[:all] = true }
  o.on('-i', '--interactive', 'Interactive mode') { options[:interactive] = true }
  o.on('-f FILE', 'Specific file to process') { |f| options[:file] = f }
  o.on('-t TAG', 'Tag for filename') { |t| options[:tag] = t }
  o.on('--force', 'Force archive even if duplicate') { options[:force] = true }

  # Split options
  o.on('-s', '--split', 'Split mode') { options[:split] = true }
  o.on('-l LINES', 'Lines per split chunk') { |l| options[:lines] = l.to_i }
  o.on('-o DIR', 'Output directory for splits') { |d| options[:output] = d }

  # Config options
  o.on('-e', '--edit', 'Edit configuration') { options[:edit] = true }
  o.on('-c', '--config', 'Show configuration') { options[:config] = true }
  o.on('--dry-run', 'Preview only') { options[:dry_run] = true }
end.parse!

# -----------------------
# Configuration Handling
# -----------------------
if options[:edit]
  File.delete(CONFIG_FILE) if File.exist?(CONFIG_FILE)
  setup_config(CONFIG_FILE)
  exit
end

unless File.exist?(CONFIG_FILE)
  setup_config(CONFIG_FILE)
end

SRC, ARCH = load_paths(CONFIG_FILE)

# Ensure directories exist
FileUtils.mkdir_p(ARCH) if ARCH

# -----------------------
# Show Configuration
# -----------------------
if options[:config]
  puts "\n📁 Current Configuration:\n".colorize(:cyan)
  puts "Platform: #{Platform.name}"
  puts "Source:   #{SRC || 'Not set'}"
  puts "Archive:  #{ARCH || 'Not set'}"
  puts "Config:   #{CONFIG_FILE}"
  puts ""
  exit
end

# -----------------------
# Validate Configuration
# -----------------------
unless SRC && ARCH
  puts "❌ Configuration incomplete. Run with -e to setup.".colorize(:red)
  exit 1
end

unless Dir.exist?(SRC)
  puts "❌ Source directory not found: #{SRC}".colorize(:red)
  exit 1
end

# -----------------------
# Main Logic
# -----------------------

if options[:split]
  # SPLIT MODE
  puts "📄 Split Mode".colorize(:blue)
  puts "Platform: #{Platform.name}"

  target_file = options[:file]
  unless target_file
    files = txt_files(SRC)
    if files.empty?
      puts "❌ No .txt files found.".colorize(:red)
      exit 1
    end

    puts "Select file to split:"
    target_file = pick_file(files)
    unless target_file
      puts "❌ Invalid selection.".colorize(:red)
      exit 1
    end
  end

  input_path = File.join(SRC, target_file)
  unless File.exist?(input_path)
    puts "❌ File not found: #{target_file}".colorize(:red)
    exit 1
  end

  output_dir = options[:output] ? Platform.normalize_path(options[:output]) : ARCH
  FileUtils.mkdir_p(output_dir)

  lines_per = options[:lines] || 5

  puts "\n🔧 Splitting: #{target_file}"
  puts "Lines per file: #{lines_per}"
  puts "Output: #{output_dir}"

  created = split_file(input_path, output_dir, lines_per, dry_run: options[:dry_run])

  puts "\n✅ Created #{created} files" unless options[:dry_run]

elsif options[:all]
  # ARCHIVE ALL MODE
  puts "📦 Archive All Mode".colorize(:blue)
  puts "Platform: #{Platform.name}"
  puts "Source: #{SRC}"
  puts "Archive: #{ARCH}"

  files = txt_files(SRC)
  if files.empty?
    puts "❌ No .txt files found.".colorize(:red)
    exit 1
  end

  puts "\n📊 Found #{files.length} files"

  archived = archive_all(SRC, ARCH, files, options)

  puts "\n✅ Archived #{archived} files" unless options[:dry_run]

elsif options[:interactive] || options[:file]
  # INTERACTIVE/SPECIFIC FILE MODE
  puts "📋 Interactive Mode".colorize(:blue)
  puts "Platform: #{Platform.name}"
  puts "Source: #{SRC}"
  puts "Archive: #{ARCH}"

  files = txt_files(SRC)
  if files.empty?
    puts "❌ No .txt files found.".colorize(:red)
    exit 1
  end

  if options[:file]
    # Specific file mode
    unless files.include?(options[:file])
      puts "❌ File not found: #{options[:file]}".colorize(:red)
      exit 1
    end
    target_file = options[:file]
  else
    # Interactive selection
    target_file = pick_file(files)
    if target_file == :all
      archived = archive_all(SRC, ARCH, files, options)
      puts "\n✅ Archived #{archived} files" unless options[:dry_run]
      exit
    elsif target_file.nil?
      puts "❌ Invalid selection.".colorize(:red)
      exit 1
    end
  end

  archive_one(SRC, ARCH, target_file, options)

else
  # HELP MODE
  puts "❌ No action specified. Use -h for help.".colorize(:red)
  exit 1
end

puts "\n🎉 Operation complete!" unless options[:dry_run]