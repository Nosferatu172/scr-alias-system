#!/usr/bin/env ruby
# Enhanced YouTube Media Downloader
# Cross-platform: Windows, WSL Kali Linux, Native Kali Linux, macOS
# Features: Multi-input sources, batch processing, format selection, resume, archive
# Created by: Tyler Jensen

require "fileutils"
require "json"
require "etc"
require "time"
require "csv"
require "benchmark"
require "thread"
require "open3"
require "shellwords"
require "optparse"

begin
  require "colorize"
rescue LoadError
  # Fallback for systems without colorize
end

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

  def self.executable_extension
    windows? ? ".exe" : ""
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
# Helper: Color wrapper
# -----------------------
def c(text, color)
  return text unless text.respond_to?(:colorize)
  text.colorize(color)
end

# -----------------------
# Configuration Management
# -----------------------
SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))

module Config
  CONFIG_FILE = File.join(SCRIPT_DIR, "banshee3.json")

  DEFAULT_CONFIG = {
    "directories" => {
      "brave_export_dir" => "/mnt/c/scr/keys/tabs/brave/",
      "default_music_dir" => "/mnt/d/Music/clm/y-hold/",
      "default_videos_dir" => "/mnt/d/Music/clm/Videos/y-hold/",
      "music_artist_dir" => "/mnt/d/Music/clm/org/",
      "video_artist_dir" => "/mnt/d/Music/clm/Videos/org/",
      "cookies_dir" => "/mnt/c/scr/keys/cookies/",
      "archive_dir" => "/mnt/c/scr/keys/archives/yt/"
    },
    "download" => {
      "default_format" => "best",
      "max_threads" => 10,
      "retry_attempts" => 1,
      "timeout" => 300,
      "ffmpeg_location" => nil
    },
    "logging" => {
      "enabled" => true,
      "level" => "info"
    }
  }

  def self.load
    return DEFAULT_CONFIG unless File.exist?(CONFIG_FILE)

    begin
      config = JSON.parse(File.read(CONFIG_FILE))
      # Merge with defaults to ensure all keys exist
      DEFAULT_CONFIG.merge(config) do |key, old_val, new_val|
        old_val.is_a?(Hash) && new_val.is_a?(Hash) ? old_val.merge(new_val) : new_val
      end
    rescue
      puts c("⚠️  Config file corrupted, using defaults", :yellow)
      DEFAULT_CONFIG
    end
  end

  def self.save(config)
    File.write(CONFIG_FILE, JSON.pretty_generate(config))
  end

  def self.get(key_path)
    keys = key_path.split('.')
    config = load
    keys.each { |key| config = config[key] }
    config
  rescue
    nil
  end

  def self.set(key_path, value)
    keys = key_path.split('.')
    config = load
    target = config
    keys[0..-2].each { |key| target = target[key] ||= {} }
    target[keys.last] = value
    save(config)
  end
end

# -----------------------
# Windows User Detection (Enhanced)
# -----------------------
def detect_win_user
  # Priority order for Windows username detection
  env_vars = ["WINUSER", "WIN_USER", "USERNAME", "USER"]

  env_vars.each do |var|
    user = ENV[var].to_s.strip
    return user unless user.empty?
  end

  # Try cmd.exe by full path (WSL often doesn't have it in PATH)
  begin
    cmd_exe = "/mnt/c/Windows/System32/cmd.exe"
    if File.exist?(cmd_exe)
      out, _err, st = Open3.capture3(cmd_exe, "/c", "echo %USERNAME%")
      if st.success?
        u = out.to_s.strip
        return u unless u.empty? || u =~ /%USERNAME%/i
      end
    end
  rescue
  end

  # Try cmd.exe if it happens to be on PATH
  begin
    out, _err, st = Open3.capture3("cmd.exe", "/c", "echo %USERNAME%")
    if st.success?
      u = out.to_s.strip
      return u unless u.empty? || u =~ /%USERNAME%/i
    end
  rescue
  end

  # PowerShell fallback
  begin
    out, _err, st = Open3.capture3("powershell.exe", "-NoProfile", "-Command", "$env:UserName")
    if st.success?
      u = out.to_s.strip
      return u unless u.empty?
    end
  rescue
  end

  # Heuristic: pick a likely user dir under /mnt/c/Users
  begin
    if Dir.exist?("/mnt/c/Users")
      candidates = Dir.entries("/mnt/c/Users").reject { |n|
        n.start_with?(".") || ["All Users", "Default", "Default User", "Public"].include?(n)
      }

      preferred = candidates.find { |n| Dir.exist?("/mnt/c/Users/#{n}/Documents") }
      return preferred if preferred && !preferred.strip.empty?
      return candidates.first if candidates.any?
    end
  rescue
  end

  # Linux fallback
  Etc.getlogin || ENV["USER"] || "user"
end

WINUSER = detect_win_user

# -----------------------
# Directory Management
# -----------------------
def resolve_path(path_template)
  path_template.to_s.gsub("{WIN_USER}", WINUSER)
end

def get_directories
  config = Config.load
  dirs = config["directories"]
  dirs.transform_values { |path| resolve_path(path) }
end

# -----------------------
# Logging System
# -----------------------
LOG_DIR = File.join(SCRIPT_DIR, "logs")
INFO_JSON_DIR = File.join(LOG_DIR, "info_json")
CSV_DIR = File.join(LOG_DIR, "downloads_csv")
[LOG_DIR, INFO_JSON_DIR, CSV_DIR].each { |d| FileUtils.mkdir_p(d) }

def log_message(msg, level: "info", file: "downloader.log")
  return unless Config.get("logging.enabled")

  timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  log_entry = "[#{timestamp}] [#{level.upcase}] #{msg}\n"

  File.open(File.join(LOG_DIR, file), "a") { |f| f.write(log_entry) }

  # Also print to console based on level
  case level
  when "error"
    puts c("❌ #{msg}", :red)
  when "warn"
    puts c("⚠️  #{msg}", :yellow)
  when "info"
    puts c("ℹ️  #{msg}", :blue)
  when "success"
    puts c("✅ #{msg}", :green)
  end
end

# -----------------------
# Ctrl+C Handler
# -----------------------
$CANCELLED = false
$ACTIVE_THREADS = []

trap("INT") do
  puts c("\n⛔ Interrupted! Cancelling downloads...", :red)
  $CANCELLED = true

  # Wait for active threads to finish
  $ACTIVE_THREADS.each do |thread|
    thread.join(5) rescue nil
  end

  log_message("Download cancelled by user", level: "warn")
  exit 130
end

# -----------------------
# Dependency Checking
# -----------------------
def check_dependencies
  missing = []

  # Check yt-dlp
  unless system("yt-dlp --version >nul 2>&1")
    missing << "yt-dlp (install from https://github.com/yt-dlp/yt-dlp)"
  end

  # Check ffmpeg
  ffmpeg_paths = [
    "ffmpeg",
    "/usr/bin/ffmpeg",
    "/usr/local/bin/ffmpeg",
    "C:\\ffmpeg\\bin\\ffmpeg.exe",
    "D:\\scr\\core\\win\\ffmpeg\\bin\\ffmpeg.exe",
    "/mnt/c/ffmpeg/bin/ffmpeg.exe"
  ]

  ffmpeg_found = false
  ffmpeg_paths.each do |path|
    if system("#{path} -version >nul 2>&1")
      Config.set("download.ffmpeg_location", path)
      ffmpeg_found = true
      break
    end
  end

  unless ffmpeg_found
    missing << "ffmpeg (install from https://ffmpeg.org/)"
  end

  unless missing.empty?
    puts c("❌ Missing dependencies:", :red)
    missing.each { |dep| puts c("   - #{dep}", :red) }
    puts c("\nPlease install missing dependencies and try again.", :yellow)
    exit 1
  end

  log_message("All dependencies verified", level: "success")
end

# -----------------------
# URL Processing
# -----------------------
def normalize_url(line)
  return nil if line.nil? || line.strip.empty?

  # Remove comments and extra whitespace
  line = line.split('#').first.to_s.strip
  return nil if line.empty?

  # Skip non-URL lines
  return nil unless line =~ /\Ahttps?:\/\/\S+/i

  # Clean up the URL
  line.gsub(/\s+/, '').gsub(/[<>]/, '')
end

def load_urls_from_txt(path)
  return [] unless File.exist?(path)

  urls = []
  File.readlines(path, encoding: 'utf-8').each_with_index do |line, index|
    url = normalize_url(line)
    if url
      urls << url
    elsif !line.strip.empty?
      log_message("Skipped invalid line #{index + 1} in #{path}: #{line.strip}", level: "warn")
    end
  end

  urls.uniq
end

def load_urls_from_csv(path)
  return [] unless File.exist?(path)

  urls = []
  begin
    CSV.foreach(path, headers: true) do |row|
      # Try common URL column names
      url_columns = ['url', 'link', 'href', 'video_url', 'media_url']

      url = nil
      url_columns.each do |col|
        if row[col]
          url = normalize_url(row[col])
          break if url
        end
      end

      # Fallback to first column
      url ||= normalize_url(row[0]) if row[0]

      urls << url if url
    end
  rescue CSV::MalformedCSVError => e
    log_message("CSV parsing error in #{path}: #{e.message}", level: "error")
    return []
  end

  urls.uniq
end

def load_urls_from_file(path)
  if path.downcase.end_with?('.csv')
    load_urls_from_csv(path)
  else
    load_urls_from_txt(path)
  end
end

def input_urls_manually
  puts c("Enter URLs (one per line, empty line to finish):", :cyan)
  urls = []

  loop do
    print "> "
    line = STDIN.gets&.strip
    break if line.nil? || line.empty?

    url = normalize_url(line)
    if url
      urls << url
      puts c("Added: #{url}", :green)
    else
      puts c("Invalid URL, try again", :red)
    end
  end

  urls.uniq
end

# -----------------------
# File Selection
# -----------------------
def select_file_from_directory(dir, exts: [".txt", ".csv"])
  return nil unless Dir.exist?(dir)

  files = Dir.children(dir).select { |f|
    exts.any? { |ext| f.downcase.end_with?(ext) }
  }.sort

  return nil if files.empty?

  puts c("Available files in #{dir}:", :cyan)
  files.each_with_index do |file, i|
    puts "  #{i + 1}) #{file}"
  end

  print c("Select file number: ", :yellow)
  choice = STDIN.gets&.to_i

  return nil unless choice && choice.between?(1, files.length)

  File.join(dir, files[choice - 1])
end

def list_cookie_files(cookies_dir)
  return [] unless cookies_dir && Dir.exist?(cookies_dir)

  Dir.children(cookies_dir).select { |f|
    f.downcase.end_with?('.txt') || f.downcase.end_with?('.sqlite')
  }.sort
end

def select_cookie_file(cookies_dir)
  files = list_cookie_files(cookies_dir)

  return nil if files.empty?

  puts c("Available cookie files:", :cyan)
  files.each_with_index do |file, i|
    puts "  #{i + 1}) #{file}"
  end

  print c("Select cookie file (0 for none): ", :yellow)
  choice = STDIN.gets&.to_i

  return nil if choice.nil? || choice == 0
  return nil unless choice.between?(1, files.length)

  File.join(cookies_dir, files[choice - 1])
end

# -----------------------
# Download Command Building
# -----------------------
def build_download_cmd(url, output_dir, options = {})
  config = Config.load["download"]
  ffmpeg_path = config["ffmpeg_location"] || "ffmpeg"

  cmd = ["yt-dlp"]

  # Basic options
  cmd << "--no-warnings"
  cmd << "--no-progress" unless options[:progress]

  # Output template
  cmd << "-o" << "#{output_dir}/%(title)s.%(ext)s"

  # Format selection
  case options[:format]
  when "audio"
    cmd << "-x"  # Extract audio
    cmd << "--audio-format" << (options[:audio_format] || "mp3")
    cmd << "--audio-quality" << (options[:audio_quality] || "192K")
  when "video"
    cmd << "-f" << (options[:video_format] || "best[height<=1080]")
  else
    cmd << "-f" << (options[:format] || config["default_format"])
  end

  # FFmpeg location
  cmd << "--ffmpeg-location" << ffmpeg_path

  # Archive file for resume/skip
  if options[:archive_file]
    cmd << "--download-archive" << options[:archive_file]
  end

  # Cookies
  if options[:cookies_file]
    cmd << "--cookies" << options[:cookies_file]
  end

  # Retry and timeout
  cmd << "--retries" << config["retry_attempts"].to_s
  cmd << "--socket-timeout" << config["timeout"].to_s

  # Additional options
  cmd << "--write-info-json" if options[:write_info]
  cmd << "--write-thumbnail" if options[:write_thumbnail]
  cmd << "--embed-thumbnail" if options[:embed_thumbnail]
  cmd << "--embed-subs" if options[:embed_subs]

  # URL
  cmd << url

  cmd
end

# -----------------------
# Download Worker
# -----------------------
def download_worker(queue, output_dir, options = {})
  Thread.current[:active] = true
  $ACTIVE_THREADS << Thread.current

  until $CANCELLED || queue.empty?
    url = queue.pop(true) rescue nil
    next unless url

    log_message("Starting download: #{url}", level: "info")

    cmd = build_download_cmd(url, output_dir, options)

    success = false
    retry_count = 0
    max_retries = Config.get("download.retry_attempts") || 3

    while !success && retry_count < max_retries && !$CANCELLED
      begin
        log_message("Executing: #{cmd.join(' ')}", level: "info")

        # Run the command
        system(*cmd)

        if $?.success?
          success = true
          log_message("Successfully downloaded: #{url}", level: "success")
        else
          retry_count += 1
          log_message("Download failed (attempt #{retry_count}): #{url}", level: "warn")
          sleep(2) if retry_count < max_retries
        end
      rescue => e
        retry_count += 1
        log_message("Error downloading #{url}: #{e.message}", level: "error")
        sleep(2) if retry_count < max_retries
      end
    end

    unless success
      log_message("Failed to download after #{max_retries} attempts: #{url}", level: "error")
    end
  end

ensure
  Thread.current[:active] = false
  $ACTIVE_THREADS.delete(Thread.current)
end

# -----------------------
# Batch Download
# -----------------------
def download_batch(urls, output_dir, options = {})
  return if urls.empty?

  log_message("Starting batch download of #{urls.size} URLs to #{output_dir}", level: "info")

  # Create output directory
  FileUtils.mkdir_p(output_dir)

  # Setup archive file if requested
  archive_file = nil
  if options[:use_archive]
    archive_file = File.join(output_dir, "download_archive.txt")
    options[:archive_file] = archive_file
  end

  # Create work queue
  queue = Queue.new
  urls.each { |url| queue << url }

  # Determine thread count
  max_threads = options[:threads] || Config.get("download.max_threads") || 4
  thread_count = [max_threads, urls.size].min

  log_message("Using #{thread_count} threads", level: "info")

  # Start worker threads
  threads = Array.new(thread_count) do
    Thread.new { download_worker(queue, output_dir, options) }
  end

  # Wait for completion
  threads.each(&:join)

  log_message("Batch download completed", level: "success")
end

# -----------------------
# Main Menu System
# -----------------------
def show_main_menu
  puts c("\n" + "="*60, :cyan)
  puts c("🎬 Enhanced YouTube Media Downloader", :cyan)
  puts c("Platform: #{Platform.name}", :cyan)
  puts c("="*60, :cyan)
  puts ""
  puts c("1) Download from manual URL input", :green)
  puts c("2) Download from .txt file", :green)
  puts c("3) Download from .csv file", :green)
  puts c("4) Select file from brave export directory", :green)
  puts c("5) Batch process brave directory", :green)
  puts c("6) Configure settings", :yellow)
  puts c("7) Show current configuration", :yellow)
  puts c("8) Check dependencies", :yellow)
  puts c("0) Exit", :red)
  puts ""
end

def get_menu_choice
  print c("Select option: ", :yellow)
  choice = STDIN.gets&.strip&.to_i
  puts ""
  choice
end

def configure_settings
  puts c("Configuration Options:", :cyan)
  puts "1) Output directories"
  puts "2) Download preferences"
  puts "3) Logging settings"
  puts "0) Back"

  print c("Select: ", :yellow)
  choice = STDIN.gets&.strip&.to_i

  case choice
  when 1
    configure_directories
  when 2
    configure_download
  when 3
    configure_logging
  end
end

def configure_directories
  dirs = get_directories

  puts c("Current Directories:", :cyan)
  dirs.each { |key, path| puts "  #{key}: #{path}" }

  puts c("\nEnter new paths (leave empty to keep current):", :yellow)

  dirs.each do |key, current_path|
    print "#{key} [#{current_path}]: "
    new_path = STDIN.gets&.strip
    if !new_path.empty?
      Config.set("directories.#{key}", new_path)
      puts c("Updated #{key}", :green)
    end
  end

  puts c("Directories updated!", :green)
end

def configure_download
  puts c("Download Settings:", :cyan)
  puts "1) Default format"
  puts "2) Max threads"
  puts "3) Retry attempts"
  puts "4) Timeout"
  puts "0) Back"

  print c("Select: ", :yellow)
  choice = STDIN.gets&.strip&.to_i

  case choice
  when 1
    print "Default format [best]: "
    format = STDIN.gets&.strip
    Config.set("download.default_format", format) unless format.empty?
  when 2
    print "Max threads [4]: "
    threads = STDIN.gets&.strip&.to_i
    Config.set("download.max_threads", threads) if threads && threads > 0
  when 3
    print "Retry attempts [3]: "
    retries = STDIN.gets&.strip&.to_i
    Config.set("download.retry_attempts", retries) if retries && retries >= 0
  when 4
    print "Timeout (seconds) [300]: "
    timeout = STDIN.gets&.strip&.to_i
    Config.set("download.timeout", timeout) if timeout && timeout > 0
  end
end

def configure_logging
  enabled = Config.get("logging.enabled")
  level = Config.get("logging.level")

  puts "Logging enabled: #{enabled ? 'Yes' : 'No'}"
  puts "Log level: #{level}"

  print "Enable logging? (y/n) [#{enabled ? 'y' : 'n'}]: "
  response = STDIN.gets&.strip&.downcase
  Config.set("logging.enabled", response == 'y') unless response.empty?

  print "Log level (error/warn/info) [#{level}]: "
  new_level = STDIN.gets&.strip
  Config.set("logging.level", new_level) unless new_level.empty?
end

def show_configuration
  config = Config.load

  puts c("Current Configuration:", :cyan)
  puts JSON.pretty_generate(config)
end

# -----------------------
# Main Program
# -----------------------
def main
  log_message("Enhanced YouTube Downloader started", level: "info")

  # Check dependencies on first run
  check_dependencies

  loop do
    show_main_menu
    choice = get_menu_choice

    case choice
    when 0
      puts c("Goodbye! 👋", :green)
      break

    when 1 # Manual URL input
      urls = input_urls_manually
      if urls.empty?
        puts c("No URLs entered", :yellow)
        next
      end

      dirs = get_directories
      output_dir = dirs["default_music_dir"]

      print c("Output directory [#{output_dir}]: ", :yellow)
      custom_dir = STDIN.gets&.strip
      output_dir = custom_dir unless custom_dir.empty?

      download_batch(urls, output_dir, progress: true)

    when 2 # From .txt file
      print c("Enter .txt file path: ", :yellow)
      file_path = STDIN.gets&.strip

      unless file_path && File.exist?(file_path)
        puts c("File not found", :red)
        next
      end

      urls = load_urls_from_txt(file_path)
      if urls.empty?
        puts c("No valid URLs found in file", :yellow)
        next
      end

      puts c("Found #{urls.size} URLs", :green)

      dirs = get_directories
      output_dir = dirs["default_music_dir"]

      download_batch(urls, output_dir, progress: true)

    when 3 # From .csv file
      print c("Enter .csv file path: ", :yellow)
      file_path = STDIN.gets&.strip

      unless file_path && File.exist?(file_path)
        puts c("File not found", :red)
        next
      end

      urls = load_urls_from_csv(file_path)
      if urls.empty?
        puts c("No valid URLs found in file", :yellow)
        next
      end

      puts c("Found #{urls.size} URLs", :green)

      dirs = get_directories
      output_dir = dirs["default_music_dir"]

      download_batch(urls, output_dir, progress: true)

    when 4 # Select from brave directory
      dirs = get_directories
      brave_dir = dirs["brave_export_dir"]

      file_path = select_file_from_directory(brave_dir)
      unless file_path
        puts c("No file selected", :yellow)
        next
      end

      urls = load_urls_from_file(file_path)
      if urls.empty?
        puts c("No valid URLs found in file", :yellow)
        next
      end

      puts c("Found #{urls.size} URLs in #{File.basename(file_path)}", :green)

      output_dir = dirs["default_music_dir"]
      download_batch(urls, output_dir, progress: true)

    when 5 # Batch process brave directory
      dirs = get_directories
      brave_dir = dirs["brave_export_dir"]

      files = Dir.children(brave_dir).select { |f|
        f.end_with?('.txt') || f.end_with?('.csv')
      }.sort

      if files.empty?
        puts c("No .txt or .csv files found in brave directory", :yellow)
        next
      end

      puts c("Found #{files.size} files to process", :green)

      files.each do |file|
        file_path = File.join(brave_dir, file)
        urls = load_urls_from_file(file_path)

        next if urls.empty?

        puts c("Processing #{file} (#{urls.size} URLs)", :blue)

        output_dir = dirs["default_music_dir"]
        download_batch(urls, output_dir, progress: false)

        # Move processed file to archive
        archive_dir = File.join(brave_dir, "processed")
        FileUtils.mkdir_p(archive_dir)
        FileUtils.mv(file_path, File.join(archive_dir, file))
        puts c("Moved #{file} to processed/", :green)
      end

    when 6 # Configure settings
      configure_settings

    when 7 # Show configuration
      show_configuration

    when 8 # Check dependencies
      check_dependencies
      puts c("All dependencies OK!", :green)

    else
      puts c("Invalid option", :red)
    end

    puts ""
  end

rescue => e
  log_message("Fatal error: #{e.message}", level: "error")
  log_message(e.backtrace.join("\n"), level: "error")
  puts c("Fatal error: #{e.message}", :red)
  exit 1
end

# Run the program
main
