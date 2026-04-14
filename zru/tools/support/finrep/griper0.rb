#!/usr/bin/env ruby
# GRIP - Cross-platform recursive grep and replace tool
# Enhanced for WSL Kali Linux and Windows Terminal compatibility
#
# Features:
# - Automatic platform detection (Windows, WSL, Linux, macOS)
# - Robust encoding handling for different file types
# - Binary file detection and skipping
# - Automatic backups before replacement
# - Unicode support with proper terminal setup
# - Performance optimized scanning
# - Safe file operations with error recovery

require 'optparse'
require 'find'
require 'fileutils'

# --------------------------------------------------
# ENV DETECTION
# --------------------------------------------------

module Env
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
    # Multiple ways to detect WSL
    version_file = "/proc/version"
    return false unless File.exist?(version_file)

    version = File.read(version_file).downcase
    return true if version.include?("microsoft") || version.include?("wsl")

    # Check for WSL environment variables
    return true if ENV['WSL_DISTRO_NAME'] || ENV['WSLENV']

    false
  end

  def self.wsl_version
    return nil unless wsl?
    ENV['WSL_DISTRO_NAME'] || 'WSL'
  end

  def self.name
    return "WSL (#{wsl_version})" if wsl?
    return "Windows" if windows?
    return "macOS" if macos?
    return "Linux" if linux?
    "Unknown"
  end

  def self.supports_unicode?
    # Windows Terminal and modern terminals support Unicode
    return true if wsl?
    return true if macos?
    return true if linux?
    # Windows CMD/PowerShell may have limited Unicode support
    return false if windows?
    true
  end
end

# Force UTF-8 defaults with better fallback
begin
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
rescue
  # Fallback for older Ruby versions
end

# Set console codepage on Windows for better Unicode support
if Env.windows? && !Env.wsl?
  begin
    `chcp 65001 >nul 2>&1` if RUBY_PLATFORM =~ /mingw|mswin/
  rescue
    # Ignore if chcp fails
  end
end

# --------------------------------------------------
# HELP FORMATTER
# --------------------------------------------------

options = {
  cwd: false,
  dir: nil,
  word: nil,
  new: nil
}

parser = OptionParser.new do |opts|
  opts.banner = <<~BANNER

    🧠 GRIP — Adaptive Recursive Grep + Replace

    Platform: #{Env.name}

    Supports literal phrases:
      [ ] ( ) !! < > { } - + _ = \\ | " : ; ? , .

    Examples:
      grip -a -w "foo[bar]" -new "baz!!"
      grip -d /path -w "hello"

  BANNER

  opts.on('-h', '--h', '--help', 'Show help') do
    puts opts
    exit
  end

  opts.on('-a', '--a', '-cwd', 'Use current working directory') do
    options[:cwd] = true
  end

  opts.on('-d PATH', 'Target directory path') do |d|
    options[:dir] = d
  end

  opts.on('-w WORD', '--word WORD', '--w WORD', 'Search phrase') do |w|
    options[:word] = w
  end

  opts.on('-new NEW', '--new NEW', 'Replacement phrase') do |n|
    options[:new] = n
  end
end

parser.parse!

# --------------------------------------------------
# HELPERS
# --------------------------------------------------

def normalize_path(path)
  return path if path.nil?

  # Expand ~ to home directory
  path = File.expand_path(path) if path.start_with?('~')

  # Normalize path separators
  if Env.windows?
    path = path.gsub("/", "\\")
  else
    path = path.gsub("\\", "/")
  end

  # Remove trailing separator unless it's a root path
  path = path.chomp(File::SEPARATOR) unless path =~ /^[A-Za-z]:#{Regexp.escape(File::SEPARATOR)}$/ || path == File::SEPARATOR

  path
end

def setup_terminal
  # Enable ANSI colors in Windows Terminal
  if Env.windows? && !Env.wsl?
    begin
      # Try to enable ANSI escape sequences
      require 'win32ole' rescue nil
      if defined?(WIN32OLE)
        begin
          shell = WIN32OLE.new('WScript.Shell')
          shell.RegWrite('HKCU\\Console\\VirtualTerminalProcessing', 1, 'REG_DWORD')
        rescue
          # Ignore registry access errors
        end
      end
    rescue
      # Ignore setup failures
    end
  end
end

def binary_file?(path)
  return true unless File.exist?(path)
  return true if File.size(path) == 0

  begin
    File.open(path, "rb") do |f|
      chunk = f.read(1024)
      return true if chunk.nil?
      # Check for null bytes (binary indicator)
      return true if chunk.include?("\x00")
      # Check for high ratio of non-printable characters
      non_printable = chunk.chars.count { |c| c.ord < 32 && c != "\n" && c != "\r" && c != "\t" }
      return true if non_printable > chunk.size * 0.3
    end
  rescue
    true
  end

  false
end

def safe_readlines(path)
  encodings = if Env.windows? && !Env.wsl?
    ['bom|utf-8', 'windows-1252', 'iso-8859-1']
  else
    ['utf-8', 'iso-8859-1', 'windows-1252']
  end

  encodings.each do |enc|
    begin
      return File.readlines(path, encoding: enc, invalid: :replace, undef: :replace, replace: '')
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      next
    end
  end

  # Final fallback
  begin
    File.readlines(path, encoding: 'ascii-8bit', invalid: :replace, undef: :replace)
  rescue
    []
  end
end

def safe_write(path, content)
  begin
    # Ensure content is properly encoded
    content = content.encode('UTF-8', invalid: :replace, undef: :replace) if content.respond_to?(:encode)

    File.write(path, content, encoding: 'utf-8')
    true
  rescue => e
    puts "⚠️ Write failed for #{path}: #{e}"
    false
  end
end

def normalize_line_endings(content)
  if Env.windows?
    content.gsub("\n", "\r\n")
  else
    content.gsub("\r\n", "\n")
  end
end

# --------------------------------------------------
# RESOLVE DIRECTORY
# --------------------------------------------------

root =
  if options[:cwd]
    Dir.pwd
  elsif options[:dir]
    options[:dir]
  else
    puts "❌ Specify directory: -a or -d PATH"
    exit 1
  end

root = normalize_path(root)

unless Dir.exist?(root)
  puts "❌ Invalid directory: #{root}"
  exit 1
end

# --------------------------------------------------
# SETUP
# --------------------------------------------------

setup_terminal()

# --------------------------------------------------
# INPUT VALIDATION
# --------------------------------------------------

if search.nil? || search.empty?
  puts "❌ No search phrase provided"
  exit 1
end

if replace.nil?
  puts "❌ No replacement provided"
  exit 1
end

# Escape special regex characters but keep word boundaries
pattern = Regexp.new(Regexp.escape(search), Regexp::IGNORECASE)
auto_mode = options[:word] && options[:new]

# --------------------------------------------------
# SCAN WITH PROGRESS
# --------------------------------------------------

matches = []
file_count = 0
start_time = Time.now

puts "\n🧠 Platform: #{Env.name}"
puts "🔎 Scanning: #{root}"
puts "📝 Search: #{search}"
puts "🔄 Replace: #{replace}" unless auto_mode

Find.find(root) do |path|
  # Skip directories
  next if File.directory?(path)

  # Skip binary files
  next if binary_file?(path)

  # Skip common binary extensions
  ext = File.extname(path).downcase
  next if ['.exe', '.dll', '.so', '.dylib', '.bin', '.jpg', '.png', '.gif', '.pdf', '.zip', '.tar', '.gz'].include?(ext)

  file_count += 1

  begin
    lines = safe_readlines(path)

    lines.each_with_index do |line, idx|
      if line.match?(pattern)
        matches << [path, idx + 1, line.chomp]
      end
    end
  rescue => e
    puts "⚠️ Skipped #{path}: #{e.message}" if auto_mode
  end
end

scan_time = Time.now - start_time
puts "📊 Scanned #{file_count} files in #{'%.2f' % scan_time}s"
puts "🎯 Found #{matches.size} matches"

if matches.empty?
  puts "No matches found."
  exit
end

# --------------------------------------------------
# REPLACE WITH BACKUP
# --------------------------------------------------

replace_all = auto_mode
replaced_count = 0
backup_dir = File.join(root, ".grip_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}")

matches.each do |path, lineno, line|
  new_line = line.gsub(pattern, replace)
  next if line == new_line

  puts "\n📄 #{normalize_path(path)}:#{lineno}"
  puts " - #{line}"
  puts " + #{new_line}"

  choice =
    if replace_all
      'y'
    else
      print("Replace? [y]es / [n]o / [a]ll / [q]uit: ")
      begin
        input = gets
        input ? input.chomp.downcase : 'n'
      rescue Interrupt
        puts "\n❌ Aborted by user."
        exit 1
      end
    end

  case choice
  when 'q', 'quit'
    puts "❌ Aborted."
    exit
  when 'a', 'all'
    replace_all = true
    choice = 'y'
  end

  next unless choice == 'y'

  begin
    # Create backup on first replacement
    if replaced_count == 0
      begin
        Dir.mkdir(backup_dir) unless Dir.exist?(backup_dir)
        puts "💾 Backups: #{normalize_path(backup_dir)}"
      rescue => e
        puts "⚠️ Could not create backup directory: #{e}"
        backup_dir = nil
      end
    end

    # Backup original file
    if backup_dir
      backup_path = File.join(backup_dir, File.basename(path))
      begin
        FileUtils.cp(path, backup_path)
      rescue => e
        puts "⚠️ Backup failed for #{path}: #{e}"
      end
    end

    # Read and modify
    lines = safe_readlines(path)
    lines[lineno - 1] = lines[lineno - 1].gsub(pattern, replace)

    # Write back with proper encoding
    content = normalize_line_endings(lines.join)
    success = safe_write(path, content)

    if success
      puts "✅ Replaced."
      replaced_count += 1
    else
      puts "❌ Failed to write."
    end

  rescue => e
    puts "⚠️ Error processing #{path}: #{e}"
  end
end

puts "\n🎉 Done. #{replaced_count} replacements made."
puts "💾 Backups saved to: #{normalize_path(backup_dir)}" if backup_dir && replaced_count > 0
