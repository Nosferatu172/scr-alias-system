# banshee.rb
# Unified Ruby toolbox for file management, text utilities, media ops, archive tools, and more.
# Combines the functionalities from the ZRU collection into one command-line tool.
# Created by: Tyler Jensen

require 'fileutils'
require 'pathname'
require 'optparse'
require 'yaml'
require 'digest'
require 'time'
require 'json'
require 'csv'
require 'shellwords'

begin
  require 'tty-prompt'
  require 'pastel'
  require 'colorize'
  require 'prawn'
rescue LoadError
  # Gems are optional; the script will continue with reduced features.
end

module Platform
  def self.windows?
    (/mingw|mswin|cygwin/ =~ RUBY_PLATFORM) != nil
  end

  def self.linux?
    RUBY_PLATFORM.include?('linux')
  end

  def self.macos?
    RUBY_PLATFORM.include?('darwin')
  end

  def self.wsl?
    return false unless linux?
    return true if ENV['WSL_DISTRO_NAME'] || ENV['WSLENV']
    version_file = '/proc/version'
    return false unless File.exist?(version_file)
    File.read(version_file).downcase.include?('microsoft')
  rescue
    false
  end

  def self.name
    return "WSL (#{ENV['WSL_DISTRO_NAME'] || 'Unknown'})" if wsl?
    return 'Windows' if windows?
    return 'macOS' if macos?
    return 'Linux' if linux?
    'Unknown'
  end

  def self.clear_command
    windows? ? 'cls' : 'clear'
  end
end

module Helpers
  def self.color(text, color = nil)
    return text unless text.respond_to?(:colorize) && color
    text.colorize(color)
  end

  def self.format_size(bytes)
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    return "#{bytes} B" if bytes < 1024
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    "%.1f %s" % [bytes.to_f / (1024 ** exp), units[exp]]
  end

  def self.format_time(time)
    time.strftime('%Y-%m-%d %H:%M:%S')
  end

  def self.confirm(message)
    if defined?(TTY::Prompt)
      TTY::Prompt.new.yes?(message)
    else
      print "#{message} (y/N): "
      gets.to_s.strip.downcase == 'y'
    end
  rescue Interrupt
    false
  end
end

class Config
  CONFIG_FILE = File.expand_path(File.join(File.dirname(__FILE__), 'banshee_config.yml'))
  OVERRIDES_FILE = File.expand_path(File.join(File.dirname(__FILE__), 'fileops.local.json'))

  DEFAULTS = {
    'ui' => {
      'show_hidden' => false,
      'page_size' => 20
    },
    'archive' => {
      'days_old' => 30,
      'format' => 'zip'
    },
    'media' => {
      'ffmpeg' => 'ffmpeg',
      'default_audio' => 'mp3',
      'default_video' => 'mp4'
    },
    'directories' => {
      'cookies_dir' => '/mnt/c/scr/keys/cookies/',
      'passwords_file' => '/mnt/c/scr/keys/passwords.txt'
    }
  }

  def self.load
    return DEFAULTS unless File.exist?(CONFIG_FILE)
    data = YAML.load_file(CONFIG_FILE)
    DEFAULTS.merge(data) do |key, old_val, new_val|
      old_val.is_a?(Hash) && new_val.is_a?(Hash) ? old_val.merge(new_val) : new_val
    end
  rescue
    DEFAULTS
  end

  def self.save(config)
    File.write(CONFIG_FILE, config.to_yaml)
  end

  def self.get(path)
    keys = path.split('.')
    cfg = load
    keys.each { |key| cfg = cfg[key] if cfg.is_a?(Hash) }
    cfg
  rescue
    nil
  end

  def self.set(path, value)
    keys = path.split('.')
    cfg = load
    target = cfg
    keys[0..-2].each { |key| target[key] ||= {} ; target = target[key] }
    target[keys.last] = value
    save(cfg)
  end

  def self.load_overrides
    return {} unless File.exist?(OVERRIDES_FILE)
    JSON.parse(File.read(OVERRIDES_FILE)).transform_keys(&:to_sym)
  rescue
    {}
  end

  def self.save_overrides(overrides)
    File.write(OVERRIDES_FILE, JSON.pretty_generate(overrides))
    true
  rescue
    false
  end

  def self.get_dir(key)
    overrides = load_overrides
    dirs = load['directories'] || {}
    (overrides[key.to_sym] || dirs[key]).to_s.strip
  end
end

module FileOps
  def self.list_entries(dir, show_hidden = false)
    return [] unless Dir.exist?(dir)
    begin
      entries = Dir.entries(dir) - ['.']
      entries.reject! { |e| !show_hidden && e.start_with?('.') }
      dirs = entries.select { |e| File.directory?(File.join(dir, e)) rescue false }.compact.sort
      files = entries.select { |e| File.file?(File.join(dir, e)) rescue false }.compact.sort
      ['..'] + dirs.map { |d| "#{d}/" } + files
    rescue => e
      puts Helpers.color("Error listing #{dir}: #{e.message}", :red)
      ['..']  
    end
  end

  def self.file_info(path)
    return nil unless File.exist?(path)
    stat = File.stat(path)
    {
      path: File.expand_path(path),
      size: stat.size,
      size_human: Helpers.format_size(stat.size),
      mtime: Helpers.format_time(stat.mtime),
      permissions: sprintf('%o', stat.mode)[-3,3],
      type: File.directory?(path) ? 'directory' : 'file',
      executable: File.executable?(path)
    }
  end

  def self.copy_files(sources, destination, options = {})
    results = { copied: 0, skipped: 0, errors: 0 }
    FileUtils.mkdir_p(destination)

    sources.each do |src|
      next unless File.exist?(src)
      dest = File.join(destination, File.basename(src))
      if File.exist?(dest) && !options[:overwrite]
        if options[:rename_on_conflict]
          base = File.basename(src, '.*')
          ext = File.extname(src)
          counter = 1
          dest = File.join(destination, "#{base}_#{counter}#{ext}")
          counter += 1 while File.exist?(dest)
        else
          results[:skipped] += 1
          next
        end
      end
      begin
        FileUtils.cp_r(src, dest)
        results[:copied] += 1
      rescue => e
        puts Helpers.color("Error copying #{src}: #{e.message}", :red)
        results[:errors] += 1
      end
    end

    results
  end

  def self.move_files(sources, destination, options = {})
    results = { moved: 0, skipped: 0, errors: 0 }
    FileUtils.mkdir_p(destination)

    sources.each do |src|
      next unless File.exist?(src)
      dest = File.join(destination, File.basename(src))
      if File.exist?(dest) && !options[:overwrite]
        if options[:rename_on_conflict]
          base = File.basename(src, '.*')
          ext = File.extname(src)
          counter = 1
          dest = File.join(destination, "#{base}_#{counter}#{ext}")
          counter += 1 while File.exist?(dest)
        else
          results[:skipped] += 1
          next
        end
      end
      begin
        FileUtils.mv(src, dest)
        results[:moved] += 1
      rescue => e
        puts Helpers.color("Error moving #{src}: #{e.message}", :red)
        results[:errors] += 1
      end
    end

    results
  end

  def self.delete(paths, options = {})
    results = { deleted: 0, skipped: 0, errors: 0 }
    paths.each do |path|
      next unless File.exist?(path)
      if options[:confirm] && !Helpers.confirm("Delete #{path}?")
        results[:skipped] += 1
        next
      end
      begin
        FileUtils.rm_rf(path)
        results[:deleted] += 1
      rescue => e
        puts Helpers.color("Error deleting #{path}: #{e.message}", :red)
        results[:errors] += 1
      end
    end
    results
  end

  def self.find_duplicates(directory, recursive: false, extensions: nil)
    return {} unless Dir.exist?(directory)
    pattern = recursive ? '**/*' : '*'
    seen = {}
    duplicates = {}
    Dir.glob(File.join(directory, pattern)).each do |path|
      next if File.directory?(path)
      next if extensions && !extensions.include?(File.extname(path).downcase)
      hash = Digest::SHA256.file(path).hexdigest rescue next
      if seen[hash]
        duplicates[hash] ||= [seen[hash]]
        duplicates[hash] << path
      else
        seen[hash] = path
      end
    end
    duplicates
  end

  def self.clean_filename(filename, patterns)
    cleaned = filename.dup
    patterns.each { |pattern| cleaned.gsub!(pattern, '') }
    cleaned.gsub!(/\s+/, ' ')
    cleaned.strip
  end

  def self.lowercase_extensions(directory, recursive: false)
    return { changed: 0, skipped: 0 } unless Dir.exist?(directory)
    pattern = recursive ? '**/*' : '*'
    results = { changed: 0, skipped: 0 }
    Dir.glob(File.join(directory, pattern)).each do |path|
      next if File.directory?(path)
      ext = File.extname(path)
      next if ext.empty? || ext == ext.downcase
      new_path = File.join(File.dirname(path), File.basename(path, '.*') + ext.downcase)
      begin
        FileUtils.mv(path, new_path)
        results[:changed] += 1
      rescue
        results[:skipped] += 1
      end
    end
    results
  end

  def self.capitalize_filenames(directory)
    return 0 unless Dir.exist?(directory)
    changed = 0
    Dir.foreach(directory) do |entry|
      next if ['.', '..'].include?(entry)
      src = File.join(directory, entry)
      next unless File.file?(src)
      new_name = entry.downcase.split.map(&:capitalize).join(' ')
      next if new_name == entry
      dest = File.join(directory, new_name)
      FileUtils.mv(src, dest)
      changed += 1
    rescue
      next
    end
    changed
  end

  def self.remove_timestamps(directory)
    return 0 unless Dir.exist?(directory)
    changed = 0
    Dir.foreach(directory) do |entry|
      next if ['.', '..'].include?(entry)
      src = File.join(directory, entry)
      next unless File.file?(src)
      new_name = entry.gsub(/\b\d{4}[-_]?\d{2}[-_]?\d{2}[_-]?/, '')
                      .gsub(/\b\d{6,8}[_-]?/, '')
                      .gsub(/[_-]{2,}/, '_')
                      .gsub(/^[_-]+|[_-]+$/, '')
                      .strip
      next if new_name.empty? || new_name == entry
      dest = File.join(directory, new_name)
      FileUtils.mv(src, dest)
      changed += 1
    rescue
      next
    end
    changed
  end

  def self.merge_directories(source_a, source_b, destination, options = {})
    return { copied: 0, errors: 0 } unless Dir.exist?(source_a) && Dir.exist?(source_b)
    FileUtils.mkdir_p(destination)
    paths = Dir.glob(File.join(source_a, '**', '*')) + Dir.glob(File.join(source_b, '**', '*'))
    copied = 0
    errors = 0
    paths.each do |path|
      next if File.directory?(path)
      rel = path.sub(/^#{Regexp.escape(File.dirname(path))}/, '')
      rel = path.sub(/^#{Regexp.escape(source_a)}\/?/, '') if path.start_with?(source_a)
      rel = path.sub(/^#{Regexp.escape(source_b)}\/?/, '') if path.start_with?(source_b)
      dest = File.join(destination, rel)
      begin
        FileUtils.mkdir_p(File.dirname(dest))
        if File.exist?(dest)
          if options[:conflict_mode] == 'overwrite'
            FileUtils.cp(path, dest)
          elsif options[:conflict_mode] == 'rename'
            base = File.basename(dest, '.*')
            ext = File.extname(dest)
            count = 1
            new_dest = File.join(File.dirname(dest), "#{base}_#{count}#{ext}")
            count += 1 while File.exist?(new_dest)
            FileUtils.cp(path, new_dest)
          else
            # skip
          end
        else
          FileUtils.cp(path, dest)
        end
        copied += 1
      rescue => e
        puts Helpers.color("Merge error: #{e.message}", :red)
        errors += 1
      end
    end
    { copied: copied, errors: errors }
  end
end

module ArchiveOps
  def self.archive_old_files(directory, days_old, options = {})
    return { archived: 0, errors: 0 } unless Dir.exist?(directory)
    cutoff = Time.now - (days_old * 24 * 60 * 60)
    archive_dir = options[:archive_dir] || File.join(directory, 'archive')
    FileUtils.mkdir_p(archive_dir)
    files = Dir.glob(File.join(directory, '*')).select { |f| File.file?(f) && File.mtime(f) < cutoff }
    return { archived: 0, errors: 0 } if files.empty?
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    archive_name = "archived_#{timestamp}.#{options[:format] || 'zip'}"
    archive_path = File.join(archive_dir, archive_name)
    if options[:format] == 'tar'
      system('tar', '-czf', archive_path, *files.map { |f| File.basename(f) })
    else
      begin
        require 'zip'
        Zip::File.open(archive_path, Zip::File::CREATE) do |zipfile|
          files.each { |file| zipfile.add(File.basename(file), file) }
        end
      rescue LoadError
        puts Helpers.color('rubyzip not installed: install gem zip to create archives', :yellow)
        return { archived: 0, errors: files.size }
      end
    end
    files.each { |file| File.delete(file) rescue nil }
    { archived: files.size, errors: 0 }
  end
end

module MediaOps
  def self.convert_audio(input, output, format = 'mp3', options = {})
    ffmpeg = options[:ffmpeg] || Config.get('media.ffmpeg') || 'ffmpeg'
    cmd = [ffmpeg, '-i', input, '-vn', '-acodec', 'libmp3lame', '-ab', options[:bitrate] || '192k', '-ar', '44100', '-y', output]
    system(*cmd)
  end

  def self.convert_video(input, output, format = 'mp4', options = {})
    ffmpeg = options[:ffmpeg] || Config.get('media.ffmpeg') || 'ffmpeg'
    cmd = [ffmpeg, '-i', input, '-c:v', 'libx264', '-c:a', 'aac', '-strict', 'experimental', '-y', output]
    system(*cmd)
  end

  def self.remove_metadata(input, output, options = {})
    ffmpeg = options[:ffmpeg] || Config.get('media.ffmpeg') || 'ffmpeg'
    ext = File.extname(input).downcase
    cmd = case ext
          when '.mp3'
            [ffmpeg, '-i', input, '-map_metadata', '-1', '-c:a', 'copy', '-y', output]
          when '.mp4'
            [ffmpeg, '-i', input, '-map_metadata', '-1', '-c', 'copy', '-y', output]
          else
            return false
          end
    system(*cmd)
  end

  def self.youtube_download(url, output_dir = '.', options = {})
    unless system('which yt-dlp > /dev/null 2>&1') || Platform.windows?
      puts Helpers.color('yt-dlp is not installed or not found in PATH', :yellow)
      return false
    end
    FileUtils.mkdir_p(output_dir)
    output_mask = File.join(output_dir, '%(title)s.%(ext)s')
    cmd = ['yt-dlp', '-o', output_mask, url]
    cmd << '-f' << options[:format] if options[:format]
    cmd << '--cookies' << options[:cookies_file] if options[:cookies_file]
    system(*cmd)
  end
end

module TextOps
  def self.remove_duplicate_lines(file)
    return 0 unless File.exist?(file)
    lines = File.readlines(file).uniq
    File.write(file, lines.join)
    lines.size
  end

  def self.extract_parentheses(file, output = nil)
    return nil unless File.exist?(file)
    output ||= file.sub(/\.[^.]+$/, '_extracted.txt')
    extracted = []
    File.foreach(file) do |line|
      extracted << $1 while line.scan(/\(([^)]+)\)/) { |match| extracted << match.first }
    end
    File.write(output, extracted.join("\n") + "\n")
    output
  end

  def self.add_prefix(file, prefix, output = nil)
    return nil unless File.exist?(file)
    output ||= file.sub(/\.[^.]+$/, '_prefixed.txt')
    File.open(output, 'w') do |out|
      File.foreach(file) do |line|
        clean = line.strip
        out.puts("#{prefix} #{clean}") unless clean.empty?
      end
    end
    output
  end

  def self.clean_urls(file, output = nil)
    return 0 unless File.exist?(file)
    output ||= file.sub(/\.[^.]+$/, '_cleaned.txt')
    urls = Set.new
    yt_watch = /https?:\/\/www\.youtube\.com\/watch\?v=[^&\s]+/
    yt_list = /[?&]list=([a-zA-Z0-9_-]+)/
    File.foreach(file) do |line|
      line.strip!
      next if line.empty?
      urls << line if line =~ yt_watch
      if line =~ yt_list
        list_id = $1
        urls << "https://www.youtube.com/playlist?list=#{list_id}" unless list_id.start_with?('RD')
      end
    end
    File.write(output, urls.to_a.join("\n") + "\n")
    urls.size
  end
end

module PdfOps
  def self.jpg_to_pdf(input_dir, output_file)
    unless defined?(Prawn)
      puts Helpers.color('Prawn gem is required for JPG -> PDF conversion', :yellow)
      return false
    end
    return false unless Dir.exist?(input_dir)
    images = Dir.glob(File.join(input_dir, '*.{jpg,jpeg,JPG,JPEG}')).sort
    return false if images.empty?
    FileUtils.mkdir_p(File.dirname(output_file))
    Prawn::Document.generate(output_file, page_size: 'LETTER', margin: 18) do |pdf|
      images.each_with_index do |img, idx|
        pdf.start_new_page unless idx.zero?
        pdf.text File.basename(img), size: 10, style: :bold
        pdf.move_down 8
        pdf.image img, fit: [pdf.bounds.width, pdf.bounds.height - 20], position: :center, vposition: :center
      rescue StandardError => e
        pdf.text "Failed: #{img}", color: 'FF0000'
        pdf.text e.message, size: 8
      end
    end
    true
  end
end

module PasswordOps
  DEMONS = %w[Beelzebul Lucifer Asmodeus Belial Leviathan Azazel Samael Shax Baalzebub Iblis Marid Ifrit Qareeb Andhaka Hiranyaksha Typhon Geryon Cerberus Cacus Oni Tengu Kappa Huangdi XiWangmu Fenrir Loki Hel Nidhöggr Walker Wyvern Demon Hell Excercist Raptor Reaper Raymond Arbatroft HellWalker Harbinger GrimReaper]
  MILITARY = %w[Alpha Bravo Charlie Delta Echo Fox Golf Hex Indiana Jeff Kilo Lima Max Nixon Oscar Papa Quebec Romeo Sierra Talon Uuvea Vextar Whiskey Xray Yahtzee Zulu]

  def self.generate(count = 10)
    count.times.map do
      demon = DEMONS.sample
      a = rand(100).to_s.rjust(2, '0')
      b = rand(100).to_s.rjust(2, '0')
      alpha = MILITARY.sample
      "#{demon}!!#{a}#{alpha}!!#{b}"
    end
  end

  def self.write(passwords, targets)
    targets.each do |target|
      dir = File.dirname(target)
      FileUtils.mkdir_p(dir)
      existing = File.exist?(target) ? File.read(target).split("\n") : []
      File.open(target, 'a') do |file|
        passwords.each { |pw| file.puts(pw) unless existing.include?(pw) }
      end
    end
  end
end

class FileBrowser
  def initialize(start_dir = Dir.pwd)
    @current_dir = File.expand_path(start_dir)
    @show_hidden = Config.get('ui.show_hidden')
    @page_size = Config.get('ui.page_size')
  end

  def browse
    loop do
      system(Platform.clear_command)
      puts Helpers.color("📂 Banshee Browser - #{Platform.name}", :cyan)
      puts "Current directory: #{@current_dir}"
      entries = FileOps.list_entries(@current_dir, @show_hidden)
      
      # Display entries with numbers
      entries.each_with_index do |entry, idx|
        mark = entry == '..' ? '📁' : (entry.end_with?('/') ? '📂' : '📄')
        puts "  #{idx + 1}: #{mark} #{entry}"
      end
      
      puts ""
      puts "Commands:"
      puts "  t: Toggle hidden files"
      puts "  x: Exit"
      puts ""
      print "Select (1-#{entries.size}, t=toggle, x=exit): "
      choice = STDIN.gets.to_s.strip.downcase
      
      if choice == 'x' || choice == 'exit'
        break
      elsif choice == 't' || choice == 'toggle'
        @show_hidden = !@show_hidden
        Config.set('ui.show_hidden', @show_hidden)
      else
        num = choice.to_i
        next if num < 1 || num > entries.size
        selected = entries[num - 1]
        
        if selected == '..'
          @current_dir = File.dirname(@current_dir) unless @current_dir == '/'
        elsif selected.end_with?('/')
          @current_dir = File.join(@current_dir, selected.chomp('/')) if Dir.exist?(File.join(@current_dir, selected.chomp('/')))
        else
          open_entry(File.join(@current_dir, selected))
        end
      end
    end
  rescue Interrupt
    puts '\nGoodbye.'
  end

  def open_entry(path)
    info = FileOps.file_info(path)
    puts "\n#{info[:path]}"
    puts "Type: #{info[:type]}"
    puts "Size: #{info[:size_human]}"
    puts "Modified: #{info[:mtime]}"
    puts "Permissions: #{info[:permissions]}"
    puts
    print "Press Enter to continue: "
    STDIN.gets
  end
end

class Banshee
  def initialize
    @options = {}
  end

  def show_command_help(cmd)
    case cmd
    when '--youtube'
      puts Helpers.color('🎬 YouTube Downloader', :cyan)
      puts "\nUsage:"
      puts "  banshee --youtube              # Interactive flow (recommended)"
      puts "  banshee --youtube \"URL\"        # Start with a single URL"
      puts "\nFeatures:"
      puts "  ✓ Audio (MP3) and Video (MP4) downloads"
      puts "  ✓ Cookie support for protected content"
      puts "  ✓ Multiple URL input methods (manual, files, tabs)"
      puts "  ✓ Batch processing from directory"
      puts "  ✓ Multi-threaded downloads (1-6 threads)"
      puts "  ✓ Auto-organize by artist"
      puts "  ✓ Smart directory configuration"
      puts "\nInteractive Flow:"
      puts "  1. Choose Audio/Video"
      puts "  2. Configure cookies (optional)"
      puts "  3. Input URLs (manual/file/default tabs/directory/batch)"
      puts "  4. Select output directory"
      puts "  5. Choose threading mode"
      puts "  6. Download with progress"
      puts "\nExample:"
      puts "  scr banshee --youtube                    # Full interactive"
      puts "  scr banshee --youtube 'https://...'      # Start with URL"
      puts "\nConfiguration:"
      puts "  Edit fileops.local.json to set default directories"
    when '--password', '--passwords'
      puts Helpers.color('🔐 Password Generator', :cyan)
      puts "\nUsage:"
      puts "  banshee --password COUNT [FILE]"
      puts "\nExamples:"
      puts "  scr banshee --password 10                # Generate 10 passwords"
      puts "  scr banshee --password 5 /path/to/pw.txt # Save to specific file"
      puts "  scr banshee --passwords 5 /path/to/pw.txt # Alias"
      puts "\nDefault save location: /mnt/c/scr/keys/passwords.txt (from config)"
    when '--browse'
      puts Helpers.color('📂 Interactive File Browser', :cyan)
      puts "\nUsage:"
      puts "  banshee --browse [DIR]"
      puts "  banshee --browse /path/to/folder"
      puts "\nFeatures:"
      puts "  ✓ Navigate directories interactively"
      puts "  ✓ View file properties"
      puts "  ✓ Toggle hidden files display"
    else
      puts Helpers.color("Help for #{cmd}:", :cyan)
      puts "Use 'banshee --help' to see all commands"
    end
    puts
  end

  def run(argv)
    # Check for command-specific help BEFORE parsing
    if argv.include?('--help') && argv.any? { |arg| arg.start_with?('--') && arg != '--help' }
      cmd = argv.find { |arg| arg.start_with?('--') && arg != '--help' }
      show_command_help(cmd)
      return
    end
    
    # Check if we should browse BEFORE parsing (parse! modifies argv)
    should_browse = argv.empty? || argv.include?('-b') || argv.include?('--browse')
    
    parse(argv)
    if should_browse
      FileBrowser.new(@options[:directory] || Dir.pwd).browse
    elsif @options[:command]
      execute
    else
      puts Helpers.color('No command specified. Use --help for options.', :yellow)
    end
  end

  def parse(argv)
    parser = OptionParser.new do |opts|
      opts.banner = "Banshee - Unified Ruby toolbox for file and media work"
      opts.on('-b', '--browse [DIR]', 'Interactive browser') { |dir| @options[:browse] = true; @options[:directory] = dir || Dir.pwd }
      opts.on('--copy SRC DEST', Array, 'Copy files or directories') { |args| @options[:command] = :copy; @options[:sources] = args[0..-2]; @options[:destination] = args.last }
      opts.on('--move SRC DEST', Array, 'Move files or directories') { |args| @options[:command] = :move; @options[:sources] = args[0..-2]; @options[:destination] = args.last }
      opts.on('--delete FILES', Array, 'Delete paths') { |args| @options[:command] = :delete; @options[:paths] = args }
      opts.on('--duplicates DIR', 'Find duplicate files') { |dir| @options[:command] = :duplicates; @options[:directory] = dir }
      opts.on('--clean-filenames DIR PATTERN1,PATTERN2', Array, 'Clean filenames in directory') { |args| @options[:command] = :clean_filenames; @options[:directory] = args.shift; @options[:patterns] = args }
      opts.on('--lowercase-ext DIR', 'Lowercase file extensions') { |dir| @options[:command] = :lowercase_ext; @options[:directory] = dir }
      opts.on('--capitalize DIR', 'Capitalize filenames in directory') { |dir| @options[:command] = :capitalize; @options[:directory] = dir }
      opts.on('--remove-timestamps DIR', 'Remove timestamp fragments from filenames') { |dir| @options[:command] = :remove_timestamps; @options[:directory] = dir }
      opts.on('--merge DIR1 DIR2 DEST', Array, 'Merge two directories into one') { |args| @options[:command] = :merge; @options[:source_a] = args[0]; @options[:source_b] = args[1]; @options[:destination] = args[2] }
      opts.on('--archive-old DIR DAYS', Array, 'Archive files older than DAYS') { |args| @options[:command] = :archive_old; @options[:directory] = args[0]; @options[:days] = args[1].to_i }
      opts.on('--jpg2pdf DIR OUTPUT', Array, 'Convert JPG files in DIR to PDF OUTPUT') { |args| @options[:command] = :jpg2pdf; @options[:directory] = args[0]; @options[:output] = args[1] }
      opts.on('--password COUNT OUTFILE', '--passwords COUNT OUTFILE', Array, 'Generate COUNT passwords and append to OUTFILE') { |args| @options[:command] = :password; @options[:count] = args[0].to_i; @options[:outfile] = args[1] }
      opts.on('--convert INPUT OUTPUT [FORMAT]', Array, 'Convert media file to mp3/mp4') { |args| @options[:command] = :convert; @options[:input] = args[0]; @options[:output] = args[1]; @options[:format] = args[2] || nil }
      opts.on('--meta-clean DIR', 'Remove metadata from MP3/MP4 files in directory') { |dir| @options[:command] = :meta_clean; @options[:directory] = dir }
      opts.on('--youtube [URL]', 'Download YouTube content (interactive or with URL)') { |url| @options[:command] = :youtube; @options[:url] = url }
      opts.on('--duplicate-lines FILE', 'Remove duplicate lines from text file') { |file| @options[:command] = :duplicate_lines; @options[:file] = file }
      opts.on('--extract-parens FILE', 'Extract parentheses content from text file') { |file| @options[:command] = :extract_parens; @options[:file] = file }
      opts.on('--add-prefix FILE PREFIX', Array, 'Add PREFIX to each line in FILE') { |args| @options[:command] = :add_prefix; @options[:file] = args[0]; @options[:prefix] = args[1] }
      opts.on('--clean-urls FILE', 'Clean YouTube URLs from text file') { |file| @options[:command] = :clean_urls; @options[:file] = file }
      opts.on('--config KEY VALUE', Array, 'Set configuration value') { |args| @options[:command] = :config; @options[:key] = args[0]; @options[:value] = args[1] }
      opts.on('--show-config', 'Show current configuration') { @options[:command] = :show_config }
      opts.on('--dry-run', 'Preview operations without side effects') { @options[:dry_run] = true }
      opts.on('--recursive', 'Include subdirectories when applicable') { @options[:recursive] = true }
      opts.on('-v', '--version', 'Show version') { puts "banshee.rb v1.0.0"; exit }
      opts.on('-h', '--help', 'Show help') { puts opts; exit }
    end
    parser.parse!(argv)
  rescue OptionParser::InvalidOption => e
    puts Helpers.color(e.message, :red)
    puts parser
    exit 1
  end

  def execute
    case @options[:command]
    when :copy then run_copy
    when :move then run_move
    when :delete then run_delete
    when :duplicates then run_duplicates
    when :clean_filenames then run_clean_filenames
    when :lowercase_ext then run_lowercase_ext
    when :capitalize then run_capitalize
    when :remove_timestamps then run_remove_timestamps
    when :merge then run_merge
    when :archive_old then run_archive_old
    when :jpg2pdf then run_jpg2pdf
    when :password then run_password
    when :convert then run_convert
    when :meta_clean then run_meta_clean
    when :youtube then run_youtube
    when :duplicate_lines then run_duplicate_lines
    when :extract_parens then run_extract_parens
    when :add_prefix then run_add_prefix
    when :clean_urls then run_clean_urls
    when :config then run_config
    when :show_config then puts Config.load.to_yaml
    else
      puts Helpers.color('Unknown command. Use --help to list supported commands.', :yellow)
    end
  end

  def run_copy
    dest = @options[:destination]
    return error('Destination directory is required') unless dest
    sources = @options[:sources] || []
    return error('At least one source path is required') if sources.empty?
    puts FileOps.copy_files(sources, dest, overwrite: @options[:dry_run], rename_on_conflict: !@options[:dry_run]).inspect
  end

  def run_move
    dest = @options[:destination]
    return error('Destination directory is required') unless dest
    sources = @options[:sources] || []
    return error('At least one source path is required') if sources.empty?
    puts FileOps.move_files(sources, dest, overwrite: @options[:dry_run], rename_on_conflict: !@options[:dry_run]).inspect
  end

  def run_delete
    paths = @options[:paths] || []
    return error('At least one file or directory is required') if paths.empty?
    result = FileOps.delete(paths, confirm: !@options[:dry_run])
    puts result.inspect
  end

  def run_duplicates
    dir = @options[:directory] || Dir.pwd
    duplicates = FileOps.find_duplicates(dir, recursive: @options[:recursive])
    if duplicates.empty?
      puts 'No duplicates found.'
      return
    end
    duplicates.each do |hash, paths|
      next if paths.size < 2
      puts 'Duplicate set:'
      paths.each { |p| puts "  #{p}" }
    end
  end

  def run_clean_filenames
    dir = @options[:directory]
    patterns = @options[:patterns] || []
    return error('Directory and pattern list are required') unless dir && patterns.any?
    Dir.glob(File.join(dir, '*')).each do |path|
      next if File.directory?(path)
      new_name = FileOps.clean_filename(File.basename(path), patterns)
      next if new_name == File.basename(path)
      dest = File.join(dir, new_name)
      FileUtils.mv(path, dest) unless @options[:dry_run]
      puts "Renamed: #{File.basename(path)} -> #{new_name}"
    end
  end

  def run_lowercase_ext
    dir = @options[:directory] || Dir.pwd
    result = FileOps.lowercase_extensions(dir, recursive: @options[:recursive])
    puts result.inspect
  end

  def run_capitalize
    dir = @options[:directory]
    return error('Directory is required') unless dir
    changed = FileOps.capitalize_filenames(dir)
    puts "Capitalized #{changed} filenames."
  end

  def run_remove_timestamps
    dir = @options[:directory]
    return error('Directory is required') unless dir
    changed = FileOps.remove_timestamps(dir)
    puts "Updated #{changed} filenames."
  end

  def run_merge
    a = @options[:source_a]
    b = @options[:source_b]
    dest = @options[:destination]
    return error('Source A, Source B, and Destination are required') unless a && b && dest
    result = FileOps.merge_directories(a, b, dest, conflict_mode: 'rename')
    puts result.inspect
  end

  def run_archive_old
    dir = @options[:directory] || Dir.pwd
    days = @options[:days] || Config.get('archive.days_old')
    result = ArchiveOps.archive_old_files(dir, days, format: Config.get('archive.format'))
    puts result.inspect
  end

  def run_jpg2pdf
    dir = @options[:directory]
    output = @options[:output]
    return error('Input directory and output file are required') unless dir && output
    if PdfOps.jpg_to_pdf(dir, output)
      puts "Saved PDF: #{output}"
    else
      error('JPG to PDF conversion failed')
    end
  end

  def run_password
    count = @options[:count] && @options[:count] > 0 ? @options[:count] : 10
    out = @options[:outfile] || Config.get_dir('passwords_file')
    # Expand path to handle /mnt/c and similar paths
    out = File.expand_path(out)
    passwords = PasswordOps.generate(count)
    PasswordOps.write(passwords, [out])
    puts Helpers.color("✅ Generated #{passwords.size} passwords.", :green)
    puts Helpers.color("💾 Saved to #{out}", :green)
  end

  def run_convert
    input = @options[:input]
    output = @options[:output]
    format = @options[:format] || File.extname(output).delete('.')
    return error('Input and output are required') unless input && output
    success = format == 'mp3' ? MediaOps.convert_audio(input, output, format) : MediaOps.convert_video(input, output, format)
    puts success ? "Converted #{input} to #{output}" : error('Conversion failed')
  end

  def run_meta_clean
    dir = @options[:directory] || Dir.pwd
    unless Dir.exist?(dir)
      return error('Directory not found')
    end
    files = Dir.glob(File.join(dir, @options[:recursive] ? '**/*.{mp3,mp4,MP3,MP4}' : '*.{mp3,mp4,MP3,MP4}'))
    files.each do |file|
      output = file.sub(/\.(mp3|MP3|mp4|MP4)$/, '_clean\0')
      if MediaOps.remove_metadata(file, output)
        puts "Cleaned metadata: #{file} -> #{output}"
      else
        puts Helpers.color("Failed: #{file}", :red)
      end
    end
  end

  def run_youtube
    # Full interactive state machine like banshee26
    youtube_interactive_flow
  end

  def youtube_interactive_flow
    puts Helpers.color("\n🎬 YouTube Downloader - banshee26 Mode", :cyan)
    
    # Get directory configuration
    dirs = {
      cookies_dir: Config.get_dir('cookies_dir'),
      default_music_dir: Config.get_dir('default_music_dir'),
      default_videos_dir: Config.get_dir('default_videos_dir'),
      music_artist_dir: Config.get_dir('music_artist_dir'),
      video_artist_dir: Config.get_dir('video_artist_dir'),
      brave_export_dir: Config.get_dir('brave_export_dir')
    }
    
    data = {
      media_type: nil,
      urls: @options[:url] ? [@options[:url]] : [],
      output_choice: nil,
      output_dir: nil,
      threads_count: 6,
      cookies_enabled: false,
      cookies_file: nil,
      input_file_used: nil,
      ask_organize: false
    }
    
    state = :media_type
    state_stack = []
    
    loop do
      case state
      # ============================================================
      when :media_type
        puts "\n🎵 Download type? (1: Video, 2: Audio)  [b=back, e=exit]:"
        print "> "
        ans = STDIN.gets.to_s.strip.downcase
        
        if ans == 'e' || ans == 'exit'
          puts Helpers.color("🛑 Exiting...", :yellow)
          break
        end
        
        if ans == 'b' || ans == 'back'
          state = state_stack.pop || :media_type
          next
        end
        
        if ans == '1'
          data[:media_type] = 'video'
        elsif ans == '2'
          data[:media_type] = 'audio'
        else
          puts Helpers.color("❌ Invalid choice. Use 1 for Video, 2 for Audio.", :red)
          next
        end
        
        state_stack << :media_type
        state = :cookies
      
      # ============================================================
      when :cookies
        cookies_dir = dirs[:cookies_dir]
        
        puts "\n🍪 Cookies:"
        puts "   cookies_dir => #{cookies_dir}"
        
        print "Use cookies for yt-dlp? (1: No, 2: Yes)  [b=back, e=exit]: > "
        ans = STDIN.gets.to_s.strip.downcase
        
        if ans == 'e' || ans == 'exit'
          puts Helpers.color("🛑 Exiting...", :yellow)
          break
        end
        
        if ans == 'b' || ans == 'back'
          state = state_stack.pop || :media_type
          next
        end
        
        if ans == '2'
          selected = select_cookie_file(cookies_dir)
          if selected == :exit
            puts Helpers.color("🛑 Exiting...", :yellow)
            break
          end
          if selected == :back
            state = state_stack.pop || :cookies
            next
          end
          
          if selected && File.exist?(selected)
            data[:cookies_enabled] = true
            data[:cookies_file] = selected
            puts Helpers.color("✅ Using cookies file: #{selected}", :green)
          else
            puts Helpers.color("⚠️ No cookies selected. Continuing without cookies.", :yellow)
          end
        else
          data[:cookies_enabled] = false
          data[:cookies_file] = nil
        end
        
        state_stack << :cookies
        state = :url_input_mode
      
      # ============================================================
      when :url_input_mode
        brave_dir = dirs[:brave_export_dir]
        
        puts "\n📥 How would you like to input URLs?  (b=back, e=exit)"
        puts "1: Manually input URLs"
        puts "2: Load from a file"
        puts "3: Use default exported-tabs.txt"
        puts "4: Choose from directory: #{brave_dir}"
        puts "5: Edit directory overrides"
        puts "6: Batch process directory"
        
        print "Select option: > "
        ans = STDIN.gets.to_s.strip.downcase
        
        if ans == 'e' || ans == 'exit'
          puts Helpers.color("🛑 Exiting...", :yellow)
          break
        end
        
        if ans == 'b' || ans == 'back'
          state = state_stack.pop || :cookies
          next
        end
        
        # ================= BATCH MODE =================
        if ans == '6'
          out = choose_output_dir(dirs)
          if out == :exit
            puts Helpers.color("🛑 Exiting...", :yellow)
            break
          end
          if out == :back
            next
          end
          
          data[:output_choice] = out[:output_choice]
          data[:output_dir] = out[:output_dir]
          data[:ask_organize] = out[:ask_organize] || false
          
          puts "\n🧠 Select download mode:"
          puts "1: Multithreaded (6 threads)"
          puts "2: Single-threaded"
          
          print "Select option: > "
          dm = STDIN.gets.to_s.strip.downcase
          
          if dm == 'e' || dm == 'exit'
            puts Helpers.color("🛑 Exiting...", :yellow)
            break
          end
          if dm == 'b' || dm == 'back'
            next
          end
          
          data[:threads_count] = (dm == '2' ? 1 : 6)
          
          files = batch_files_in_dir(brave_dir)
          selected = select_files_from_list(files)
          
          if selected == :exit
            puts Helpers.color("🛑 Exiting...", :yellow)
            break
          end
          if selected == :back
            next
          end
          
          selected.each_with_index do |file_path, idx|
            puts Helpers.color("\n▶️  (#{idx + 1}/#{selected.size}) #{File.basename(file_path)}", :light_blue)
            
            urls = load_urls_from_file(file_path)
            next if urls.empty?
            
            download_media(urls, data[:output_dir], data[:media_type], data[:threads_count], data[:cookies_file])
            
            if data[:ask_organize]
              organize_by_artist_folder(data[:output_dir])
            end
            
            move_to_completed(file_path, brave_dir)
          end
          
          puts Helpers.color("\n✅ Batch run finished.", :green)
          break
        end
        
        # ================= SINGLE MODE =================
        urls = case ans
        when '1'
          input_urls_manually
        when '2'
          print "Enter full file path: > "
          pth = STDIN.gets.to_s.strip
          File.exist?(pth) ? load_urls_from_file(pth) : []
        when '3'
          path = File.join(brave_dir, "exported-tabs.txt")
          File.exist?(path) ? load_urls_from_txt(path) : []
        when '4'
          selected = select_file_from_directory(brave_dir)
          selected ? load_urls_from_file(selected) : []
        when '5'
          edit_directory_overrides
          next  # Stay in this state
        else
          puts Helpers.color("❌ Invalid option. Please choose 1-6.", :red)
          next
        end
        
        if urls.empty?
          puts Helpers.color("❌ No URLs loaded. Please try again.", :red)
          next
        end
        
        data[:urls] = urls
        state_stack << :url_input_mode
        state = :output_dir
      
      # ============================================================
      when :output_dir
        out = choose_output_dir(dirs)
        
        if out == :exit
          puts Helpers.color("🛑 Exiting...", :yellow)
          break
        end
        if out == :back
          state = state_stack.pop || :url_input_mode
          next
        end
        
        data[:output_choice] = out[:output_choice]
        data[:output_dir] = out[:output_dir]
        data[:ask_organize] = out[:ask_organize] || false
        
        state_stack << :output_dir
        state = :download_mode
      
      # ============================================================
      when :download_mode
        puts "\n🧠 Select download mode:"
        puts "1: Multithreaded (6 threads)"
        puts "2: Single-threaded"
        
        print "Select option: > "
        ans = STDIN.gets.to_s.strip.downcase
        
        if ans == 'e' || ans == 'exit'
          puts Helpers.color("🛑 Exiting...", :yellow)
          break
        end
        if ans == 'b' || ans == 'back'
          state = state_stack.pop || :output_dir
          next
        end
        
        data[:threads_count] = (ans == '2' ? 1 : 6)
        
        state_stack << :download_mode
        state = :run
      
      # ============================================================
      when :run
        puts Helpers.color("\n🚀 Starting downloads…", :cyan)
        
        download_media(data[:urls], data[:output_dir], data[:media_type], data[:threads_count], data[:cookies_file])
        
        if data[:ask_organize]
          puts Helpers.color("\n👤 Organizing by artist...", :cyan)
          organize_by_artist_folder(data[:output_dir])
        end
        
        puts Helpers.color("\n✅ All downloads complete!", :green)
        break
      end
    end
  end

  def input_urls_manually
    urls = []
    puts Helpers.color("\n📝 Enter URLs (one per line, blank to finish):", :cyan)
    loop do
      print "> "
      line = STDIN.gets
      break if line.nil? || line.strip.empty?
      urls << line.strip if line.strip.match?(%r{https?://})
    end
    puts Helpers.color("✓ Added #{urls.size} URLs", :green)
    urls
  end

  def select_url_file
    print "\nFile path (.txt or .csv): "
    file_path = STDIN.gets.to_s.strip
    return [] unless File.exist?(file_path)
    
    urls = if file_path.end_with?('.csv')
      load_urls_from_csv(file_path)
    else
      load_urls_from_txt(file_path)
    end
    puts Helpers.color("✓ Loaded #{urls.size} URLs from file", :green)
    urls
  end

  def load_urls_from_txt(path)
    File.readlines(path).map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
  end

  def load_urls_from_csv(path)
    urls = []
    CSV.foreach(path, headers: true) do |row|
      next unless row
      url = row['url'] || row['URL'] || row['link'] || row['Link'] || row[0]
      urls << url.to_s.strip if url && url.to_s.match?(%r{https?://})
    end
    urls
  end

  def load_urls_from_file(path)
    return [] unless File.exist?(path)
    
    if path.end_with?('.csv')
      load_urls_from_csv(path)
    else
      load_urls_from_txt(path)
    end
  end

  def download_media_threaded(urls, output_dir, media_type, thread_count, cookies_file = nil)
    queue = Queue.new
    urls.each { |url| queue << url }
    
    threads = thread_count.times.map do
      Thread.new do
        until queue.empty?
          url = queue.pop(true) rescue nil
          next unless url
          puts Helpers.color("⬇️  #{url}", :light_blue)
          cmd = build_yt_dlp_cmd(url, output_dir, media_type, cookies_file)
          system(cmd)
        end
      end
    end
    
    threads.each(&:join)
  end

  def build_yt_dlp_cmd(url, output_dir, media_type, cookies_file = nil)
    output_template = File.join(output_dir, '%(title).240s.%(ext)s')
    cmd = ['yt-dlp']
    cmd << '--cookies' << cookies_file if cookies_file
    
    if media_type == 'audio'
      # Extract best audio and convert to mp3
      cmd += ['-x', '--audio-format', 'mp3', '--audio-quality', '0', '--write-info-json']
    else
      # Get best video + best audio and merge to mp4
      cmd += ['-f', 'bestvideo+bestaudio/best', '--merge-output-format', 'mp4', '--write-info-json']
    end
    
    cmd += ['-o', output_template, url]
    cmd.shelljoin
  end

  def organize_by_artist_folder(base_dir)
    # Look for .info.json files in the base directory
    info_files = Dir.glob(File.join(base_dir, '*.info.json')).sort
    
    if info_files.empty?
      puts Helpers.color('ℹ️  No .info.json files found', :yellow)
      return
    end

    info_files.each do |info_path|
      begin
        info = JSON.parse(File.read(info_path))
        artist = info['artist'] || info['uploader'] || 'Unknown Artist'
        artist_folder = File.join(base_dir, artist)
        
        FileUtils.mkdir_p(artist_folder)

        base_name = File.basename(info_path, '.info.json')
        # Move associated media files
        %w[mp3 mp4 m4a webm flac wav].each do |ext|
          media_file = File.join(base_dir, "#{base_name}.#{ext}")
          if File.exist?(media_file)
            FileUtils.mv(media_file, File.join(artist_folder, File.basename(media_file)))
            puts Helpers.color("  ↪️  #{File.basename(media_file)} → #{artist}/", :green)
          end
        end

        # Move the info.json file itself
        FileUtils.mv(info_path, File.join(artist_folder, File.basename(info_path)))
      rescue => e
        puts Helpers.color("❌ Failed to process #{File.basename(info_path)}: #{e.message}", :red)
      end
    end
    puts Helpers.color('✅ Organization complete!', :green)
  end

  def select_cookie_file(cookies_dir)
    files = list_cookie_files(cookies_dir)
    if files.empty?
      puts Helpers.color("⚠️ No cookie files found in: #{cookies_dir}", :yellow)
      return nil
    end

    puts "\n🍪 Select a cookies file from:"
    puts "   #{cookies_dir}"
    files.each_with_index { |p, i| puts "  #{i + 1}: #{File.basename(p)}" }

    print "Select number (b=back, e=exit): > "
    ans = STDIN.gets.to_s.strip.downcase
    return :exit if ans == 'e' || ans == 'exit'
    return :back if ans == 'b' || ans == 'back'
    choice = ans.to_i
    return nil if choice < 1 || choice > files.size
    files[choice - 1]
  end

  def list_cookie_files(cookies_dir)
    return [] unless cookies_dir && Dir.exist?(cookies_dir)
    Dir.entries(cookies_dir)
       .reject { |f| f.start_with?('.') }
       .map { |f| File.join(cookies_dir, f) }
       .select { |p| File.file?(p) }
       .sort
  end

  def choose_output_dir(dirs)
    default_music = dirs[:default_music_dir]
    default_videos = dirs[:default_videos_dir]
    music_artist_root = dirs[:music_artist_dir]
    video_artist_root = dirs[:video_artist_dir]

    puts "\n📂 Choose output directory:  (b=back, e=exit)"
    puts "1: Default Music: #{default_music}"
    puts "2: Default Videos: #{default_videos}"
    puts "3: Enter custom path"
    puts "4: #{music_artist_root} + organize by artist"
    puts "5: #{video_artist_root} + organize by artist"

    print "Select option: > "
    ans = STDIN.gets.to_s.strip.downcase
    return :exit if ans == 'e' || ans == 'exit'
    return :back if ans == 'b' || ans == 'back'

    output_choice = ans
    output_dir = nil
    ask_organize = false

    case output_choice
    when '1'
      output_dir = default_music
    when '2'
      output_dir = default_videos
    when '3'
      print "Enter custom output directory (b=back, e=exit): > "
      custom = STDIN.gets.to_s.strip.downcase
      return :back if custom == 'b' || custom == 'back'
      return :exit if custom == 'e' || custom == 'exit'
      
      output_dir = custom.strip
      
      puts "\n🗂️ Organize output?"
      puts "1: No (flat)"
      puts "2: Yes (by artist/uploader)"
      
      print "Select option: > "
      org = STDIN.gets.to_s.strip.downcase
      return :back if org == 'b' || org == 'back'
      return :exit if org == 'e' || org == 'exit'
      
      ask_organize = (org == '2')
    when '4'
      print "Enter artist name (blank = auto-detect later) (b=back, e=exit): > "
      artist = STDIN.gets.to_s.strip.downcase
      return :back if artist == 'b' || artist == 'back'
      return :exit if artist == 'e' || artist == 'exit'
      
      artist = artist.strip
      output_dir = artist.empty? ? music_artist_root : File.join(music_artist_root, artist)
      ask_organize = true
    when '5'
      print "Enter artist name (blank = auto-detect later) (b=back, e=exit): > "
      artist = STDIN.gets.to_s.strip.downcase
      return :back if artist == 'b' || artist == 'back'
      return :exit if artist == 'e' || artist == 'exit'
      
      artist = artist.strip
      output_dir = artist.empty? ? video_artist_root : File.join(video_artist_root, artist)
      ask_organize = true
    else
      output_dir = default_music
    end

    # Ensure directory exists safely
    FileUtils.mkdir_p(output_dir) if output_dir.is_a?(String)

    puts Helpers.color("✅ Saving to: #{output_dir}", :green)

    {
      output_choice: output_choice,
      output_dir: output_dir,
      ask_organize: ask_organize
    }
  end

  def select_file_from_directory(dir, exts: ['.txt', '.csv'])
    unless Dir.exist?(dir)
      puts Helpers.color("❌ Directory not found: #{dir}", :red)
      return nil
    end

    files = Dir.entries(dir).select { |f| exts.include?(File.extname(f).downcase) }
    if files.empty?
      puts Helpers.color("⚠️ No #{exts.join(', ')} files found in: #{dir}", :yellow)
      return nil
    end

    puts "\n📂 Select a file from:"
    puts "   #{dir}"
    files.each_with_index do |f, i|
      tag = File.extname(f).downcase == '.csv' ? '[CSV]' : '[TXT]'
      puts "  #{i + 1}: #{tag} #{f}"
    end

    print "Select number (b=back, e=exit): > "
    ans = STDIN.gets.to_s.strip.downcase
    return :exit if ans == 'e' || ans == 'exit'
    return :back if ans == 'b' || ans == 'back'
    choice = ans.to_i
    return nil if choice < 1 || choice > files.size
    File.join(dir, files[choice - 1])
  end

  def batch_files_in_dir(dir, exts: ['.txt', '.csv'])
    return [] unless Dir.exist?(dir)
    Dir.entries(dir)
       .reject { |f| f.start_with?('.') }
       .select { |f| exts.include?(File.extname(f).downcase) }
       .map { |f| File.join(dir, f) }
       .select { |p| File.file?(p) }
       .sort
  end

  def select_files_from_list(files)
    return [] if files.nil? || files.empty?

    puts "\n📄 Files found:"
    files.each_with_index do |p, i|
      puts "  #{i + 1}: #{File.basename(p)}"
    end

    puts "\n✅ Choose files to run:"
    puts "   - a / all        = all files"
    puts "   - 1,5,19,175     = specific numbers"
    puts "   - 2-10           = range"
    puts "   - 1-3,8,12-15    = mix"
    print "Selection (a/all, b=back, e=exit): > "
    ans = STDIN.gets.to_s.strip.downcase

    return :exit if ans == 'e' || ans == 'exit'
    return :back if ans == 'b' || ans == 'back'

    parsed = parse_selection_input(ans, files.size)
    return :exit if parsed == :exit
    return :back if parsed == :back
    return files if parsed == :all

    if parsed.empty?
      puts Helpers.color("⚠️ Nothing selected.", :yellow)
      return []
    end

    parsed.map { |n| files[n - 1] }
  end

  def parse_selection_input(input, max)
    s = input.to_s.strip.downcase
    return :all if s == 'a' || s == 'all'
    return :back if s == 'b'
    return :exit if s == 'e'
    return [] if s.empty?

    picks = []
    s.split(',').each do |tok|
      tok = tok.strip
      next if tok.empty?

      if tok.include?('-')
        a, b = tok.split('-', 2).map { |x| x.to_i }
        next if a <= 0 || b <= 0
        lo, hi = [a, b].min, [a, b].max
        (lo..hi).each { |n| picks << n if n >= 1 && n <= max }
      else
        n = tok.to_i
        picks << n if n >= 1 && n <= max
      end
    end

    picks.uniq.sort
  end

  def edit_directory_overrides
    puts Helpers.color("🛠️ Directory overrides editor - not implemented yet", :yellow)
    puts "Use a text editor to modify fileops.local.json directly"
  end

  def download_media(urls, output_dir, media_type, threads_count, cookies_file)
    if threads_count > 1
      download_media_threaded(urls, output_dir, media_type, threads_count, cookies_file)
    else
      urls.each do |url|
        puts Helpers.color("⬇️  #{url}", :light_blue)
        cmd = build_yt_dlp_cmd(url, output_dir, media_type, cookies_file)
        system(cmd)
      end
    end
  end

  def move_to_completed(input_file, brave_dir)
    return if input_file.nil? || input_file.to_s.strip.empty?
    return unless File.exist?(input_file)

    dest_dir = File.expand_path(File.join(brave_dir, '..', 'completed'))
    FileUtils.mkdir_p(dest_dir)

    base = File.basename(input_file)
    dest = File.join(dest_dir, base)

    if File.exist?(dest)
      stamp = Time.now.strftime('%Y%m%d%H%M%S')
      dest = File.join(dest_dir, "#{File.basename(base, '.*')}_#{stamp}#{File.extname(base)}")
    end

    FileUtils.mv(input_file, dest)
    dest
  end

  def run_duplicate_lines
    file = @options[:file]
    return error('File is required') unless file
    count = TextOps.remove_duplicate_lines(file)
    puts "Processed #{count} unique lines."
  end

  def run_extract_parens
    file = @options[:file]
    return error('File is required') unless file
    output = TextOps.extract_parentheses(file)
    puts "Wrote extracted content to #{output}."
  end

  def run_add_prefix
    file = @options[:file]
    prefix = @options[:prefix]
    return error('File and prefix are required') unless file && prefix
    output = TextOps.add_prefix(file, prefix)
    puts "Wrote prefixed file to #{output}."
  end

  def run_clean_urls
    file = @options[:file]
    return error('File is required') unless file
    count = TextOps.clean_urls(file)
    puts "Wrote cleaned URLs, found #{count} entries."
  end

  def run_config
    key = @options[:key]
    value = @options[:value]
    return error('Key and value are required') unless key && value
    Config.set(key, value)
    puts "Config updated: #{key} = #{value}"
  end

  def error(message)
    puts Helpers.color(message, :red)
    false
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    Banshee.new.run(ARGV)
  rescue Interrupt
    puts '\nInterrupted. Goodbye.'
    exit 0
  rescue => e
    puts Helpers.color("Fatal error: #{e.message}", :red)
    puts e.backtrace.first(5)
    exit 1
  end
end
