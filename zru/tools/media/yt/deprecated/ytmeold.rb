#!/usr/bin/env ruby
# ytbulk.rb — yt-dlp downloader that accepts URLs from:
#  - Manual input
#  - .txt files (one URL per line)
#  - .csv files (first column OR url/link/href column)
#
# Includes:
#  - Option 4: Choose .txt/.csv from brave dir
#  - Option 6: Batch process brave dir one file at a time, with multi-select,
#              then move processed input files to ../completed/
#
# Notes:
#  - NO GUI folder popups (open_folder is disabled)

require "fileutils"
require "json"
require "etc"
require "time"
require "csv"
require "benchmark"
require "thread"
require "open3"
require "shellwords"

begin
  require "colorize"
rescue LoadError
  # ok, no colors
end

# -----------------------
# Helper: Color wrapper
# -----------------------
def c(text, color)
  return text unless text.respond_to?(:colorize)
  text.colorize(color)
end

# -----------------------
# Locate script dir + fileops.rb next to it
# -----------------------
SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
begin
  require_relative File.join(SCRIPT_DIR, "fileops")
rescue LoadError => e
  abort "❌ Missing fileops.rb next to this script.\n   #{e.message}"
end

# -----------------------
# Paths (logs next to script)
# -----------------------
LOG_DIR       = File.join(SCRIPT_DIR, "logs")
INFO_JSON_DIR = File.join(LOG_DIR, "info_json")
CSV_DIR       = File.join(LOG_DIR, "downloads_csv")
[LOG_DIR, INFO_JSON_DIR, CSV_DIR].each { |d| FileUtils.mkdir_p(d) }

def log_message(msg, file: "script.log", log_dir: LOG_DIR)
  timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  File.open(File.join(log_dir, file), "a") { |f| f.puts("[#{timestamp}] #{msg}") }
end

# ======================================================================
# WINUSER (soft set) — single source of truth for Windows username in WSL
# ======================================================================
def resolve_winuser
  winuser = ENV["WINUSER"].to_s.strip
  return winuser unless winuser.empty?

  # 1) Try your shared env file (~/.config/wsl-env.sh)
  env_file = File.expand_path("~/.config/wsl-env.sh")
  if File.exist?(env_file)
    cmd = "source #{Shellwords.escape(env_file)} >/dev/null 2>&1; echo -n \"$WINUSER\""
    out, _ = Open3.capture2("bash", "-lc", cmd)
    winuser = out.to_s.strip
    unless winuser.empty?
      ENV["WINUSER"] = winuser
      return winuser
    end
  end

  # 2) Last resort: ask Windows directly
  cmd_exe = "/mnt/c/Windows/System32/cmd.exe"
  if File.exist?(cmd_exe)
    out, _ = Open3.capture2(cmd_exe, "/c", "echo %USERNAME%")
    winuser = out.to_s.strip
    unless winuser.empty?
      ENV["WINUSER"] = winuser
      return winuser
    end
  end

  ""
end

WINUSER = resolve_winuser
if WINUSER.to_s.strip.empty?
  abort "❌ WINUSER not set.\n   Tip: ensure ~/.config/wsl-env.sh exists OR Windows interop is enabled."
end

# -----------------------
# Ctrl+C (no prompt)
# -----------------------
$CANCELLED = false
$ACTIVE_PGIDS = []

trap("INT") do
  $CANCELLED = true
  begin
    msg = "\n🛑 Ctrl+C caught — cancelling…"
    puts(msg.respond_to?(:colorize) ? msg.colorize(:yellow) : msg)
  rescue
  end

  $ACTIVE_PGIDS.uniq.each do |pgid|
    begin
      Process.kill("TERM", -pgid)
    rescue
    end
  end
end

# -----------------------
# Dependencies
# -----------------------
def ensure_dependencies
  deps = { "yt-dlp" => "sudo apt install -y yt-dlp" }
  missing = deps.keys.reject { |cmd| system("which #{cmd} > /dev/null 2>&1") }
  unless missing.empty?
    puts c("🚧 Missing dependencies: #{missing.join(', ')}", :red)
    missing.each { |dep| system(deps[dep]) }
    exec("ruby #{$0}")
  end
end

# Prompt printed ABOVE user input
def prompt_choice(title, prompt: "> ", allow_back: true, allow_exit: true)
  puts title
  print prompt
  ans = STDIN.gets
  return :exit if ans.nil?
  ans = ans.strip
  return :back if allow_back && ans.downcase == "b"
  return :exit if allow_exit && ans.downcase == "e"
  ans
end

# -----------------------
# NO-GUI folder open (disabled)
# -----------------------
def open_folder(_path)
  # Disabled to prevent Kali/GTK file manager from popping up.
end

def move_json_files(base_dir)
  Dir.glob(File.join(base_dir, "*.info.json")).each do |json_file|
    FileUtils.mv(json_file, INFO_JSON_DIR)
  end
end

def organize_by_artist_folder(base_dir)
  info_files = Dir.glob(File.join(INFO_JSON_DIR, "*.info.json"))
  if info_files.empty?
    puts c("❌ No info.json files found.", :red)
    return
  end

  info_files.each do |info_path|
    break if $CANCELLED
    begin
      info = JSON.parse(File.read(info_path))
      artist = info["artist"] || info["uploader"] || "Unknown"
      artist_folder = File.join(base_dir, artist)
      FileUtils.mkdir_p(artist_folder)

      base_name = File.basename(info_path, ".info.json")
      %w[mp3 mp4 m4a webm flac wav].each do |ext|
        media_file = File.join(base_dir, "#{base_name}.#{ext}")
        FileUtils.mv(media_file, artist_folder) if File.exist?(media_file)
      end

      log_message("Moved #{base_name} to #{artist_folder}")
    rescue => e
      puts c("❌ Failed #{info_path}: #{e.message}", :red)
      log_message("Error processing #{info_path}: #{e.message}")
    end
  end
end

def run_cmd_capture_pgid(cmd)
  pid = Process.spawn(cmd, pgroup: true)
  pgid = Process.getpgid(pid)
  $ACTIVE_PGIDS << pgid
  Process.wait(pid)
rescue => e
  log_message("Command failed: #{cmd} | #{e.class}: #{e.message}")
ensure
  begin
    $ACTIVE_PGIDS.delete(pgid) if defined?(pgid) && pgid
  rescue
  end
end

def build_download_cmd(url, output_dir, media_type, cookies_file = nil)
  cookies_arg = ""
  if cookies_file && !cookies_file.to_s.strip.empty?
    cookies_arg = "--cookies '#{cookies_file}'"
  end

  if media_type == "audio"
    "yt-dlp #{cookies_arg} -x --audio-format mp3 --write-info-json -o '#{output_dir}/%(title).240s.%(ext)s' '#{url}'"
  else
    "yt-dlp #{cookies_arg} -S 'res,ext:mp4:m4a' --recode mp4 --write-info-json -o '#{output_dir}/%(title).240s.%(ext)s' '#{url}'"
  end
end

def worker(queue, output_dir, media_type, cookies_file)
  until queue.empty? || $CANCELLED
    url = nil
    begin
      url = queue.pop(true)
    rescue ThreadError
      url = nil
    end
    next unless url
    break if $CANCELLED

    puts c("🔗 Downloading: #{url}", :light_green)
    log_message("Downloading: #{url}")
    run_cmd_capture_pgid(build_download_cmd(url, output_dir, media_type, cookies_file))
  end
end

def download_media(urls, output_dir, media_type, threads_count, cookies_file)
  duration = Benchmark.measure do
    queue = Queue.new
    urls.each { |url| queue << url }
    threads = threads_count.times.map { Thread.new { worker(queue, output_dir, media_type, cookies_file) } }
    threads.each(&:join)
  end

  move_json_files(output_dir) unless $CANCELLED
  puts c("⏱️ Finished in #{duration.real.round(2)}s", :green) unless $CANCELLED
  open_folder(output_dir) unless $CANCELLED # no-op now
end

def save_urls_to_csv(urls)
  csv_file = File.join(CSV_DIR, "urls_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv")
  CSV.open(csv_file, "w") { |csv| urls.each { |u| csv << [u] } }
  csv_file
end

# -----------------------
# URL parsing / normalization
# -----------------------
def normalize_url(line)
  return nil if line.nil?
  s = line.to_s.strip
  return nil if s.empty?
  return nil if s.start_with?("#")
  s = s.gsub(/\A["']|["']\z/, "")
  s = s.split(/\s+/).first.to_s.strip
  return nil unless s =~ /\Ahttps?:\/\/\S+/i
  s
end

def load_urls_from_txt(path)
  File.readlines(path).map { |ln| normalize_url(ln) }.compact
end

def load_urls_from_csv(path)
  urls = []

  # Try with headers first
  CSV.foreach(path, headers: true) do |row|
    next unless row
    candidate =
      row["url"] || row["URL"] ||
      row["link"] || row["Link"] ||
      row["href"] || row["HREF"] ||
      row&.fields&.first
    u = normalize_url(candidate)
    urls << u if u
  end

  # Fallback: no headers / unknown layout
  if urls.empty?
    CSV.foreach(path, headers: false) do |row|
      next unless row && row[0]
      u = normalize_url(row[0])
      urls << u if u
    end
  end

  urls
end

def load_urls_from_file(path)
  ext = File.extname(path).downcase
  case ext
  when ".csv"
    load_urls_from_csv(path)
  else
    load_urls_from_txt(path)
  end
end

def input_urls_manually
  urls = []
  puts "🎯 Enter URLs one per line (blank line to finish):"
  loop do
    line = STDIN.gets
    return urls if line.nil?
    line = line.strip
    break if line.empty?
    u = normalize_url(line)
    urls << u if u
  end
  urls
end

def list_cookie_files(cookies_dir)
  return [] unless cookies_dir && Dir.exist?(cookies_dir)
  Dir.entries(cookies_dir)
     .reject { |f| f.start_with?(".") }
     .map { |f| File.join(cookies_dir, f) }
     .select { |p| File.file?(p) }
     .sort
end

def select_cookie_file(cookies_dir)
  files = list_cookie_files(cookies_dir)
  if files.empty?
    puts c("⚠️ No cookie files found in: #{cookies_dir}", :yellow)
    return nil
  end

  puts "\n🍪 Select a cookies file from:"
  puts "   #{cookies_dir}"
  files.each_with_index { |p, i| puts "  #{i + 1}: #{File.basename(p)}" }

  ans = prompt_choice("Select number (b=back, e=exit):", prompt: "> ")
  return :exit if ans == :exit
  return :back if ans == :back
  choice = ans.to_i
  return nil if choice < 1 || choice > files.size
  files[choice - 1]
end

def select_file_from_directory(dir, exts: [".txt", ".csv"])
  unless Dir.exist?(dir)
    puts c("❌ Directory not found: #{dir}", :red)
    return nil
  end

  files = Dir.entries(dir).select { |f| exts.include?(File.extname(f).downcase) }
  if files.empty?
    puts c("⚠️ No #{exts.join(', ')} files found in: #{dir}", :yellow)
    return nil
  end

  puts "\n📂 Select a file from:"
  puts "   #{dir}"
  files.each_with_index do |f, i|
    tag = File.extname(f).downcase == ".csv" ? "[CSV]" : "[TXT]"
    puts "  #{i + 1}: #{tag} #{f}"
  end

  ans = prompt_choice("Select number (b=back, e=exit):", prompt: "> ")
  return :exit if ans == :exit
  return :back if ans == :back
  choice = ans.to_i
  return nil if choice < 1 || choice > files.size
  File.join(dir, files[choice - 1])
end

# -----------------------
# completed/ folder next to brave_dir
# -----------------------
def completed_dir_for(brave_dir)
  File.expand_path(File.join(brave_dir, "..", "completed"))
end

def move_to_completed(input_file, brave_dir)
  return if input_file.nil? || input_file.to_s.strip.empty?
  return unless File.exist?(input_file)

  dest_dir = completed_dir_for(brave_dir)
  FileUtils.mkdir_p(dest_dir)

  base = File.basename(input_file)
  dest = File.join(dest_dir, base)

  if File.exist?(dest)
    stamp = Time.now.strftime("%Y%m%d%H%M%S")
    dest = File.join(dest_dir, "#{File.basename(base, ".*")}_#{stamp}#{File.extname(base)}")
  end

  FileUtils.mv(input_file, dest)
  dest
end

def batch_files_in_dir(dir, exts: [".txt", ".csv"])
  return [] unless Dir.exist?(dir)
  Dir.entries(dir)
     .reject { |f| f.start_with?(".") }
     .select { |f| exts.include?(File.extname(f).downcase) }
     .map { |f| File.join(dir, f) }
     .select { |p| File.file?(p) }
     .sort
end

# -----------------------
# NEW: Multi-select parser for Option 6
# -----------------------
def parse_selection_input(input, max)
  s = input.to_s.strip.downcase
  return :all if s == "a" || s == "all"
  return :back if s == "b"
  return :exit if s == "e"
  return [] if s.empty?

  picks = []

  s.split(",").each do |tok|
    tok = tok.strip
    next if tok.empty?

    if tok.include?("-")
      a, b = tok.split("-", 2).map { |x| x.to_i }
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
  ans = prompt_choice("Selection (a/all, b=back, e=exit):", prompt: "> ")

  return :exit if ans == :exit
  return :back if ans == :back

  parsed = parse_selection_input(ans, files.size)
  return :exit if parsed == :exit
  return :back if parsed == :back
  return files if parsed == :all

  if parsed.empty?
    puts c("⚠️ Nothing selected.", :yellow)
    return []
  end

  parsed.map { |n| files[n - 1] }
end

def edit_directory_overrides(script_dir, current_dirs)
  overrides = FileOps.load_local_overrides(script_dir)

  loop do
    puts "\n🛠️ Directory overrides (one-at-a-time) — (b=back, e=exit)"
    keys = FileOps.valid_keys

    keys.each_with_index do |k, i|
      cur = current_dirs[k]
      mark = overrides.key?(k) ? "*" : " "
      puts "  #{i + 1}:#{mark} #{k} => #{cur}"
    end
    puts "\n  s: save overrides to fileops.local.json"
    puts "  r: remove an override (revert one key to default)"

    ans = prompt_choice("Pick a number to edit, or s/r, (b=back, e=exit):", prompt: "> ")
    return :exit if ans == :exit
    return :back if ans == :back

    if ans.downcase == "s"
      ok = FileOps.save_local_overrides(script_dir, overrides)
      puts(ok ? c("✅ Saved overrides.", :green) : c("❌ Failed to save overrides.", :red))
      next
    end

    if ans.downcase == "r"
      rm = prompt_choice("Enter key number to remove override (b=back, e=exit):", prompt: "> ")
      next if rm == :back
      return :exit if rm == :exit
      idx = rm.to_i - 1
      if idx >= 0 && idx < keys.size
        overrides.delete(keys[idx])
        ok = FileOps.save_local_overrides(script_dir, overrides)
        puts(ok ? c("✅ Removed override for #{keys[idx]}", :green) : c("❌ Failed to save.", :red))
      else
        puts c("❌ Invalid selection.", :red)
      end
      next
    end

    idx = ans.to_i - 1
    if idx < 0 || idx >= keys.size
      puts c("❌ Invalid selection.", :red)
      next
    end

    key = keys[idx]
    input = prompt_choice("New value for #{key} (blank = keep current) (b=back, e=exit):", prompt: "> ")
    next if input == :back
    return :exit if input == :exit

    if input.strip.empty?
      puts c("↩️ Kept: #{key}", :yellow)
      next
    end

    overrides[key] = input.strip
    ok = FileOps.save_local_overrides(script_dir, overrides)
    puts(ok ? c("✅ Updated #{key}", :green) : c("❌ Failed to save override.", :red))
  end
end

def choose_output_dir(dirs, prompt_choice_fn)
  default_music  = dirs[:default_music_dir]
  default_videos = dirs[:default_videos_dir]
  music_artist_root = dirs[:music_artist_dir]
  video_artist_root = dirs[:video_artist_dir]

  puts "\n📂 Choose output directory:  (b=back, e=exit)"
  puts "1: Default Music: #{default_music}"
  puts "2: Default Videos: #{default_videos}"
  puts "3: Enter custom path"
  puts "4: #{music_artist_root} + organize by artist"
  puts "5: #{video_artist_root} + organize by artist"
  ans = prompt_choice_fn.call("Select option:", prompt: "> ")
  return :exit if ans == :exit
  return :back if ans == :back

  output_choice = ans
  output_dir = case output_choice
               when "1" then default_music
               when "2" then default_videos
               when "3"
                 custom = prompt_choice_fn.call("Enter custom output directory (b=back, e=exit):", prompt: "> ")
                 return :back if custom == :back
                 return :exit if custom == :exit
                 custom
               when "4"
                 artist = prompt_choice_fn.call("Enter artist name (blank = auto-detect later) (b=back, e=exit):", prompt: "> ")
                 return :back if artist == :back
                 return :exit if artist == :exit
                 artist = artist.strip
                 dir = artist.empty? ? music_artist_root : File.join(music_artist_root, artist)
                 FileUtils.mkdir_p(dir)
                 puts c("✅ Saving to: #{dir}", :green)
                 dir
               when "5"
                 artist = prompt_choice_fn.call("Enter artist name (blank = auto-detect later) (b=back, e=exit):", prompt: "> ")
                 return :back if artist == :back
                 return :exit if artist == :exit
                 artist = artist.strip
                 dir = artist.empty? ? video_artist_root : File.join(video_artist_root, artist)
                 FileUtils.mkdir_p(dir)
                 puts c("✅ Saving to: #{dir}", :green)
                 dir
               else
                 default_music
               end

  FileUtils.mkdir_p(output_dir)
  { output_choice: output_choice, output_dir: output_dir }
end

def main
  ensure_dependencies
  dirs = FileOps.build_dirs(nil, SCRIPT_DIR)

  state_stack = []
  data = {
    media_type: nil,
    urls: [],
    output_choice: nil,
    output_dir: nil,
    threads_count: Etc.nprocessors,
    cookies_enabled: false,
    cookies_file: nil,
    input_file_used: nil
  }

  state = :media_type

  loop do
    break if $CANCELLED

    case state
    when :media_type
      ans = prompt_choice("🎵 Download type? (1: Video, 2: Audio)  [b=back, e=exit]:", prompt: "> ")
      break if ans == :exit
      if ans == :back
        state = state_stack.pop || :media_type
        next
      end
      data[:media_type] = (ans.strip == "2" ? "audio" : "video")
      state_stack << :media_type
      state = :cookies

    when :cookies
      cookies_dir = dirs[:cookies_dir]
      puts "\n🍪 Cookies:"
      puts "   cookies_dir => #{cookies_dir}"
      ans = prompt_choice("Use cookies for yt-dlp? (1: No, 2: Yes)  [b=back, e=exit]:", prompt: "> ")
      break if ans == :exit
      if ans == :back
        state = state_stack.pop || :media_type
        next
      end

      if ans.strip == "2"
        selected = select_cookie_file(cookies_dir)
        break if selected == :exit
        next if selected == :back

        if selected && File.exist?(selected)
          data[:cookies_enabled] = true
          data[:cookies_file] = selected
          puts c("✅ Using cookies file: #{selected}", :green)
        else
          puts c("⚠️ No cookies selected. Continuing without cookies.", :yellow)
          data[:cookies_enabled] = false
          data[:cookies_file] = nil
        end
      else
        data[:cookies_enabled] = false
        data[:cookies_file] = nil
      end

      state_stack << :cookies
      state = :url_input_mode

    when :url_input_mode
      brave_dir = dirs[:brave_export_dir]
      puts "\n📥 How would you like to input URLs?  (b=back, e=exit)"
      puts "1: Manually input URLs"
      puts "2: Load from a file (path)  [supports .txt and .csv]"
      puts "3: Use default exported-tabs.txt"
      puts "4: Choose from directory: #{brave_dir}  [shows .txt and .csv]"
      puts "5: Edit directory overrides (save to fileops.local.json)"
      puts "6: Batch process directory (select files) + move to ../completed/"
      ans = prompt_choice("Select option:", prompt: "> ")
      break if ans == :exit
      if ans == :back
        state = state_stack.pop || :cookies
        next
      end

      if ans == "6"
        out = choose_output_dir(dirs, ->(t, **kw) { prompt_choice(t, **kw) })
        next if out == :back
        break if out == :exit
        data[:output_choice] = out[:output_choice]
        data[:output_dir]    = out[:output_dir]

        puts "\n🧠 Select download mode for batch:  (b=back, e=exit)"
        puts "1: Multithreaded (#{Etc.nprocessors} threads)"
        puts "2: Single-threaded (1 thread)"
        dm = prompt_choice("Select option:", prompt: "> ")
        break if dm == :exit
        next if dm == :back
        data[:threads_count] = (dm == "2" ? 1 : Etc.nprocessors)

        cookies_file = data[:cookies_enabled] ? data[:cookies_file] : nil

        all_files = batch_files_in_dir(brave_dir, exts: [".txt", ".csv"])
        if all_files.empty?
          puts c("⚠️ No .txt/.csv files found in: #{brave_dir}", :yellow)
          next
        end

        selected = select_files_from_list(all_files)
        break if selected == :exit
        next if selected == :back

        files = selected
        if files.empty?
          puts c("⚠️ No files selected. Returning to menu.", :yellow)
          next
        end

        completed_dir = completed_dir_for(brave_dir)
        FileUtils.mkdir_p(completed_dir)
        puts c("\n📦 Batch mode:", :cyan)
        puts "   Input dir:      #{brave_dir}"
        puts "   Completed dir:  #{completed_dir}"
        puts "   Files selected: #{files.size}"

        files.each_with_index do |file_path, idx|
          break if $CANCELLED
          puts c("\n▶️  (#{idx + 1}/#{files.size}) Processing: #{File.basename(file_path)}", :light_blue)

          urls = load_urls_from_file(file_path).compact.map(&:strip).reject(&:empty?).uniq
          urls = urls.select { |u| u =~ /\Ahttps?:\/\//i }.uniq

          if urls.empty?
            puts c("⚠️ No URLs in file, moving anyway: #{file_path}", :yellow)
            moved = move_to_completed(file_path, brave_dir)
            puts c("📁 Moved to: #{moved}", :cyan) if moved
            next
          end

          csv_out = save_urls_to_csv(urls)
          puts c("🧾 Saved URL list to: #{csv_out}", :cyan)

          banner = "\n🚀 Starting downloads for file #{idx + 1}/#{files.size}… (Ctrl+C to cancel)"
          puts(c(banner, :cyan)) rescue puts(banner)

          download_media(urls, data[:output_dir], data[:media_type], data[:threads_count], cookies_file)

          if !$CANCELLED && ["4", "5"].include?(data[:output_choice])
            puts "\n🎨 Organizing by creator/uploader..."
            organize_by_artist_folder(data[:output_dir])
          end

          break if $CANCELLED

          moved = move_to_completed(file_path, brave_dir)
          if moved
            puts c("✅ Completed + moved input file to: #{moved}", :green)
            log_message("Completed input file moved: #{file_path} -> #{moved}")
          end
        end

        puts c("\n✅ Batch run finished.", :green) unless $CANCELLED
        break
      end

      urls = []
      input_file_used = nil

      case ans
      when "1"
        urls = input_urls_manually

      when "2"
        pth = prompt_choice("Enter full file path (b=back, e=exit):", prompt: "> ")
        next if pth == :back
        break if pth == :exit
        if File.exist?(pth)
          input_file_used = pth
          urls = load_urls_from_file(pth)
        else
          urls = []
        end

      when "3"
        default_file = File.join(brave_dir, "exported-tabs.txt")
        if File.exist?(default_file)
          input_file_used = default_file
          urls = load_urls_from_txt(default_file)
        else
          urls = []
        end

      when "4"
        selected = select_file_from_directory(brave_dir, exts: [".txt", ".csv"])
        break if selected == :exit
        next if selected == :back
        if selected && File.exist?(selected)
          input_file_used = selected
          urls = load_urls_from_file(selected)
        else
          urls = []
        end

      when "5"
        ret = edit_directory_overrides(SCRIPT_DIR, dirs)
        break if ret == :exit
        next if ret == :back
        dirs = FileOps.build_dirs(nil, SCRIPT_DIR)
        next

      else
        puts c("❌ Invalid choice.", :red)
        next
      end

      urls = urls.compact.map(&:strip).reject(&:empty?).uniq
      urls = urls.select { |u| u =~ /\Ahttps?:\/\//i }.uniq

      if urls.empty?
        puts c("⚠️ No URLs found.", :yellow)
        next
      end

      data[:urls] = urls
      data[:input_file_used] = input_file_used

      csv_out = save_urls_to_csv(urls)
      puts c("🧾 Saved URL list to: #{csv_out}", :cyan)

      state_stack << :url_input_mode
      state = :output_dir

    when :output_dir
      out = choose_output_dir(dirs, ->(t, **kw) { prompt_choice(t, **kw) })
      break if out == :exit
      if out == :back
        state = state_stack.pop || :url_input_mode
        next
      end

      data[:output_choice] = out[:output_choice]
      data[:output_dir]    = out[:output_dir]

      state_stack << :output_dir
      state = :download_mode

    when :download_mode
      puts "\n🧠 Select download mode:  (b=back, e=exit)"
      puts "1: Multithreaded (#{Etc.nprocessors} threads)"
      puts "2: Single-threaded (1 thread)"
      ans = prompt_choice("Select option:", prompt: "> ")
      break if ans == :exit
      if ans == :back
        state = state_stack.pop || :output_dir
        next
      end

      data[:threads_count] = (ans == "2" ? 1 : Etc.nprocessors)
      state_stack << :download_mode
      state = :run

    when :run
      banner = "\n🚀 Starting downloads… (Ctrl+C to cancel)"
      puts(c(banner, :cyan)) rescue puts(banner)

      cookies_file = data[:cookies_enabled] ? data[:cookies_file] : nil
      download_media(data[:urls], data[:output_dir], data[:media_type], data[:threads_count], cookies_file)

      if !$CANCELLED && ["4", "5"].include?(data[:output_choice])
        puts "\n🎨 Organizing by creator/uploader..."
        organize_by_artist_folder(data[:output_dir])
      end

      brave_dir = dirs[:brave_export_dir]
      input_file = data[:input_file_used]

      if !$CANCELLED && input_file && File.exist?(input_file)
        begin
          in_brave = File.expand_path(input_file).start_with?(File.expand_path(brave_dir) + File::SEPARATOR)
          if in_brave
            moved = move_to_completed(input_file, brave_dir)
            puts c("✅ Moved input file to: #{moved}", :green) if moved
          end
        rescue
        end
      end

      break
    end
  end

  puts c("\n👋 Exiting.", :yellow) if !$CANCELLED
end

main
 
