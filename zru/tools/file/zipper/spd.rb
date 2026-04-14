#!/usr/bin/env ruby
# zscr11.rb

require 'csv'
require 'fileutils'
require 'optparse'
require 'time'
require 'tty-prompt'
require 'tmpdir'
require 'io/console'
require 'open3'
require 'zlib'

trap("INT") do
  puts "\n⛔ Cancelled (Ctrl+C). Exiting cleanly."
  exit(130)
end

# =======================
# ENV DETECTION
# =======================
def detect_env
  if RUBY_PLATFORM =~ /mswin|mingw/
    :windows
  elsif File.exist?("/proc/version") && File.read("/proc/version").downcase.include?("microsoft")
    :wsl
  else
    :linux
  end
end

ENV_TYPE = detect_env

# =======================
# PATHS
# =======================
SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
LOG_DIR = File.join(SCRIPT_DIR, "logs")
CSV_PATH = File.join(LOG_DIR, "dirs.csv")
EXCLUDE_CSV = File.join(LOG_DIR, "excludes.csv")

# =======================
# MODELS
# =======================
DirEntry = Struct.new(:kind, :name, :path, :is_default, :enabled)
ExcludeEntry = Struct.new(:pattern, :enabled, :notes)

# =======================
# HELPERS
# =======================
def vprint(msg, silent)
  puts msg unless silent
end

def safe_mkdir(path)
  FileUtils.mkdir_p(path)
end

def is_dir?(p)
  File.exist?(p) && File.directory?(p)
end

def bool_to_str(b)
  b ? "1" : "0"
end

def str_to_bool(s)
  %w[1 true yes y on].include?(s.to_s.downcase)
end

# =======================
# HELP MENU
# =======================
def show_help
  puts <<~HELP

  SCR Archive & Distribution Tool (zscr11.rb)

  DESCRIPTION:
    Archive and distribute /scr backups across multiple drives.
    Uses configurable directory sources and CSV-driven exclude rules.

  USAGE:
    ruby zscr11.rb [options]

  CORE OPTIONS:
    -l                  List configured paths
    -e                  Edit directory config (dirs.csv)
    --edit-excludes     Edit exclude rules (excludes.csv)
    -n                  Dry run (no changes made)

  ARCHIVE CONTROL:
    --zip-only          Only create archive (no distribution)
    --spread-only       Only distribute (skip archive step)

  EXCLUDE CONTROL:
    --exclude           Enable excludes (default)
    --no-exclude        Disable excludes (include everything)

  OUTPUT CONTROL:
    --silent            Quiet mode (minimal output)

  GENERAL:
    -h, --help          Show this help menu

  EXAMPLES:
    ruby zscr11.rb
    ruby zscr11.rb -n
    ruby zscr11.rb -e
    ruby zscr11.rb --edit-excludes
    ruby zscr11.rb --zip-only
    ruby zscr11.rb --no-exclude

  NOTES:
    - Archives are created as: scr-YYYY-MM-DD_HH-MM-SS.tar.gz
    - Uses tar (and pv if available for progress)
    - Works on Linux, WSL, and Windows (with tar in PATH)
    - Excludes are managed via logs/excludes.csv
    - Ctrl+C exits safely

  FILES:
    logs/dirs.csv        Directory source/destination config
    logs/excludes.csv    Exclude pattern rules

  HELP
end

# =======================
# EXCLUDES CONFIG
# =======================
def ensure_exclude_config
  safe_mkdir(LOG_DIR)
  return if File.exist?(EXCLUDE_CSV)

  CSV.open(EXCLUDE_CSV, "w") do |csv|
    csv << %w[pattern enabled notes]
    csv << ["keys", "1", "sensitive"]
    csv << [".venv", "1", "python venv"]
    csv << ["*.tar.gz", "1", "archives"]
  end

  puts "✔ Created exclude config: #{EXCLUDE_CSV}"
end

def read_excludes
  ensure_exclude_config
  entries = []

  CSV.foreach(EXCLUDE_CSV, headers: true) do |r|
    entries << ExcludeEntry.new(
      r["pattern"],
      str_to_bool(r["enabled"]),
      r["notes"]
    )
  end

  entries
end

def write_excludes(entries)
  CSV.open(EXCLUDE_CSV, "w") do |csv|
    csv << %w[pattern enabled notes]
    entries.each do |e|
      csv << [e.pattern, bool_to_str(e.enabled), e.notes]
    end
  end
end

def build_excludes_from_csv(entries)
  entries
    .select { |e| e.enabled }
    .map { |e| "--exclude=#{e.pattern}" }
end

# =======================
# PROGRESS
# =======================
def fake_progress(stop_flag, seconds = 5)
  steps = 50
  steps.times do |i|
    break if stop_flag[:done]

    percent = ((i + 1).to_f / steps * 100).to_i
    bar = "#" * (i + 1) + "-" * (steps - i - 1)

    print "\rProgress: [#{bar}] #{percent}%"
    sleep(seconds.to_f / steps)
  end
end

def has_pv?
  system("which pv > /dev/null 2>&1")
end

# =======================
# TAR CHECK
# =======================
def check_tar!
  ok = ENV_TYPE == :windows ? system("where tar >nul 2>&1") : system("which tar > /dev/null 2>&1")
  unless ok
    puts "❌ 'tar' not found in PATH."
    exit(1)
  end
end

# =======================
# DIR CONFIG
# =======================
def ensure_default_config
  safe_mkdir(LOG_DIR)
  return if File.exist?(CSV_PATH)

  rows = []

  if ENV_TYPE == :windows
    rows << ["source","main","C:/scr","1","1"]
    %w[d e f g h i].each { |d| rows << ["dest", d, "#{d.upcase}:/scr","0","1"] }
  else
    rows << ["source","main","/mnt/c/scr","1","1"]
    %w[d e f g h i].each { |d| rows << ["dest", d, "/mnt/#{d}/scr","0","1"] }
  end

  CSV.open(CSV_PATH, "w") do |csv|
    csv << %w[kind name path is_default enabled]
    rows.each { |r| csv << r }
  end

  puts "✔ Created config: #{CSV_PATH}"
end

def read_entries
  ensure_default_config
  entries = []

  CSV.foreach(CSV_PATH, headers: true) do |r|
    entries << DirEntry.new(
      r["kind"],
      r["name"],
      File.expand_path(r["path"]),
      str_to_bool(r["is_default"]),
      str_to_bool(r["enabled"])
    )
  end

  entries
end

def write_entries(entries)
  CSV.open(CSV_PATH, "w") do |csv|
    csv << %w[kind name path is_default enabled]
    entries.each do |e|
      csv << [e.kind, e.name, e.path, bool_to_str(e.is_default), bool_to_str(e.enabled)]
    end
  end
end

# =======================
# ARCHIVE
# =======================
def build_archive_name
  "scr-#{Time.now.strftime("%Y-%m-%d_%H-%M-%S")}.tar.gz"
end

def create_archive(source, archive, dry, silent, use_excludes, exclude_entries)
  vprint("📦 Archiving (filtered): #{source}", silent)
  return archive if dry

  check_tar!

  excludes = use_excludes ? build_excludes_from_csv(exclude_entries) : []
  include_dirs = %w[core aliases zru zpy bsh]

  if has_pv? && ENV_TYPE != :windows
    size = include_dirs.sum do |d|
      `du -sb "#{File.join(source, d)}" 2>/dev/null`.split.first.to_i
    end

    cmd = "tar #{excludes.join(' ')} -cf - #{include_dirs.map { |d| "-C \"#{source}\" #{d}" }.join(' ')} | pv -s #{size} | gzip > \"#{archive}\""
    system(cmd)

  else
    size = include_dirs.sum do |d|
      `du -sb "#{File.join(source, d)}" 2>/dev/null`.split.first.to_i
    end

    cmd = ["tar", *excludes, "-cf", "-", *include_dirs.map { |d| ["-C", source, d] }.flatten]

    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      File.open(archive, "wb") do |file|
        gz = Zlib::GzipWriter.new(file)

        read_bytes = 0
        last_percent = -1
        bar_len = 40

        while (chunk = stdout.read(1024 * 64))
          gz.write(chunk)
          read_bytes += chunk.bytesize

          if size > 0
            percent = [(read_bytes.to_f / size * 100).to_i, 100].min

            if percent != last_percent
              filled = (percent * bar_len / 100.0).to_i
              bar = "#" * filled + "-" * (bar_len - filled)

              print "\rProgress: [#{bar}] #{percent}%"
              last_percent = percent
            end
          end
        end

        gz.close
      end

      unless wait_thr.value.success?
        puts "\n❌ tar failed"
        exit(1)
      end
    end

    puts "\rProgress: [########################################] 100%"
  end

  unless File.exist?(archive)
    puts "❌ Archive failed"
    exit(1)
  end

  vprint("✔ Created (filtered): #{archive}", silent)
  archive
end

# =======================
# SPREAD
# =======================
def rotate_swap(swap, new_archives, dry, label, silent)
  Dir.glob(File.join(swap, "*.tar.gz")).each do |file|
    dest = File.join(new_archives, File.basename(file))

    if dry
      vprint("DRY: move #{file}", silent)
    else
      safe_mkdir(new_archives)
      FileUtils.mv(file, dest)
      vprint("📦 #{label}: rotated", silent)
    end
  end
end

def spread_archive(archive, dests, dry, silent)
  dests.each do |d|
    next unless is_dir?(d.path)

    swap = File.join(d.path, "swap")
    new_archives = File.join(d.path, "new-archives")

    safe_mkdir(swap) unless dry
    safe_mkdir(new_archives) unless dry

    rotate_swap(swap, new_archives, dry, d.name, silent)

    target = File.join(swap, File.basename(archive))

    if dry
      vprint("DRY: copy #{archive}", silent)
    else
      FileUtils.cp(archive, target, preserve: true)
      vprint("✅ #{d.name}: copied", silent)
    end
  end
end

# =======================
# EDITORS
# =======================
def term_height
  IO.console.winsize[0] rescue 40
end

def edit_entries(entries)
  prompt = TTY::Prompt.new

  loop do
    choices = entries.map.with_index do |e, i|
      {
        name: "#{i}: #{e.kind} | #{e.name} -> #{e.path} [#{e.enabled ? 'on' : 'off'}]",
        value: i
      }
    end

    choices << { name: "➕ Add new entry", value: :add }
    choices << { name: "❌ Delete entry", value: :delete }
    choices << { name: "✔ Done", value: :done }

    selection = prompt.select(
      "Select entry:",
      choices,
      per_page: term_height - 5
    )

    case selection
    when :done
      break

    when :add
      kind = prompt.select("Kind?", %w[source dest])
      name = prompt.ask("Name?")
      path = prompt.ask("Path?")
      enabled = prompt.yes?("Enabled?")

      entries << DirEntry.new(kind, name, path, false, enabled)

    when :delete
      idx = prompt.select(
        "Delete which?",
        entries.map.with_index { |e, i| { name: "#{i}: #{e.name}", value: i } },
        per_page: term_height - 5
      )
      entries.delete_at(idx)

    else
      entry = entries[selection]

      action = prompt.select("Action?", %w[Edit Toggle Back])

      case action
      when "Toggle"
        entry.enabled = !entry.enabled
      when "Edit"
        entry.path = prompt.ask("Path?", default: entry.path)
        entry.enabled = prompt.yes?("Enable?", default: entry.enabled)
      when "Back"
        next
      end
    end
  end

  write_entries(entries)
  puts "✔ Updated."
end

def edit_excludes(entries)
  prompt = TTY::Prompt.new

  loop do
    choices = entries.map.with_index do |e,i|
      "#{i}: #{e.pattern} | #{e.enabled ? 'on' : 'off'} | #{e.notes}"
    end
    choices << "Add new"
    choices << "Done"

    selection = prompt.select("Edit excludes:", choices, per_page: choices.size)
    break if selection == "Done"

    if selection == "Add new"
      entries << ExcludeEntry.new(
        prompt.ask("Pattern?"),
        true,
        prompt.ask("Notes?")
      )
      next
    end

    index = selection.split(":").first.to_i
    e = entries[index]

    e.pattern = prompt.ask("Pattern?", default: e.pattern)
    e.notes = prompt.ask("Notes?", default: e.notes)
    e.enabled = prompt.yes?("Enabled?")
  end

  write_excludes(entries)
  puts "✔ Excludes updated."
end

# =======================
# RUN
# =======================
def run(entries, opts)
  src = entries.find { |e| e.kind == "source" && e.is_default && e.enabled }
  dests = entries.select { |e| e.kind == "dest" && e.enabled }

  archive = File.join(Dir.tmpdir, build_archive_name)
  excludes = read_excludes

  create_archive(src.path, archive, opts[:dry], opts[:silent], opts[:exclude], excludes) unless opts[:spread_only]
  spread_archive(archive, dests, opts[:dry], opts[:silent]) unless opts[:zip_only]

  puts "✔ Done."
end

# =======================
# CLI
# =======================
options = {
  list:false,
  edit:false,
  edit_excludes:false,
  dry:false,
  silent:false,
  zip_only:false,
  spread_only:false,
  help:false,
  exclude:true
}

OptionParser.new do |opts|
  opts.on("-l") { options[:list] = true }
  opts.on("-e") { options[:edit] = true }
  opts.on("--edit-excludes") { options[:edit_excludes] = true }
  opts.on("-n") { options[:dry] = true }
  opts.on("--silent") { options[:silent] = true }
  opts.on("--zip-only") { options[:zip_only] = true }
  opts.on("--spread-only") { options[:spread_only] = true }
  opts.on("--exclude") { options[:exclude] = true }
  opts.on("--no-exclude") { options[:exclude] = false }
  opts.on("-h","--help") { options[:help] = true }
end.parse!

entries = read_entries

if options[:help]
  show_help
elsif options[:list]
  entries.each_with_index { |e,i| puts "[#{i}] #{e.kind}: #{e.name} -> #{e.path}" }
elsif options[:edit]
  edit_entries(entries)
elsif options[:edit_excludes]
  edit_excludes(read_excludes)
else
  run(entries, options)
end
