#!/usr/bin/env ruby
# zscr9.rb

require 'csv'
require 'fileutils'
require 'optparse'
require 'time'
require 'tty-prompt'
require 'tmpdir'

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

# =======================
# MODEL
# =======================
DirEntry = Struct.new(:kind, :name, :path, :is_default, :enabled)

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
# PROGRESS BAR (fallback)
# =======================
def fake_progress(seconds = 3)
  steps = 30
  steps.times do |i|
    percent = ((i+1).to_f / steps * 100).to_i
    bar = "#" * (i+1) + "-" * (steps - i - 1)
    print "\rProgress: [#{bar}] #{percent}%"
    sleep(seconds.to_f / steps)
  end
  puts
end

# =======================
# TAR CHECK
# =======================
def check_tar!
  ok = if ENV_TYPE == :windows
         system("where tar >nul 2>&1")
       else
         system("which tar > /dev/null 2>&1")
       end

  unless ok
    puts "❌ 'tar' not found in PATH."
    exit(1)
  end
end

def has_pv?
  system("which pv > /dev/null 2>&1")
end

# =======================
# CSV DEFAULTS
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
  safe_mkdir(LOG_DIR)
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
  "scr-#{Time.now.strftime("%m-%d-%Y_%H-%M-%S")}.tar.gz"
end

def create_archive(source, archive, dry, silent)
  vprint("📦 Archiving: #{source}", silent)
  return archive if dry

  check_tar!

  if has_pv? && ENV_TYPE != :windows
    size = `du -sb "#{source}"`.split.first.to_i rescue 0

    cmd = "tar -cf - -C \"#{source}\" . | pv -s #{size} | gzip > \"#{archive}\""
    system(cmd)
  else
    # fallback
    Thread.new { fake_progress(5) }
    system("tar", "-czf", archive, "-C", source, ".")
  end

  unless File.exist?(archive)
    puts "❌ Archive failed"
    exit(1)
  end

  vprint("✔ Created: #{archive}", silent)
  archive
end

def rotate_swap(swap, new_archives, dry, label, silent)
  Dir.glob(File.join(swap, "*.tar.gz")).each do |file|
    dest = File.join(new_archives, File.basename(file))

    if dry
      vprint("DRY: move #{file} -> #{dest}", silent)
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
      vprint("DRY: copy #{archive} -> #{target}", silent)
    else
      FileUtils.cp(archive, target, preserve: true)
      vprint("✅ #{d.name}: copied", silent)
    end
  end
end

# =======================
# EDIT
# =======================
def edit_entries(entries)
  prompt = TTY::Prompt.new

  loop do
    choices = entries.map.with_index do |e,i|
      "#{i}: #{e.kind} | #{e.name} -> #{e.path} | #{e.enabled ? 'enabled' : 'disabled'}#{e.is_default ? ' | default' : ''}"
    end

    choices << "Done"

    selection = prompt.select("Select entry:", choices)
    break if selection == "Done"

    index = selection.split(":").first.to_i
    entry = entries[index]

    new_path = prompt.ask("Path?", default: entry.path)
    entry.path = File.expand_path(new_path) unless new_path.to_s.strip.empty?

    entry.enabled = prompt.yes?("Enable?")

    if entry.kind == "source"
      entry.is_default = prompt.yes?("Set as default?")
      if entry.is_default
        entries.each { |e| e.is_default = false if e.kind == "source" && e != entry }
      end
    end
  end

  write_entries(entries)
  puts "✔ Updated."
end

# =======================
# HELP
# =======================
def show_help
  puts <<~HELP

  zipandspreadscr_xplat.rb

  🔹 DESCRIPTION
    Archives a source /scr folder and distributes it to multiple destinations.
    Automatically rotates old backups.

  🔹 USAGE
    ruby zipandspreadscr_xplat.rb [options]

  🔹 OPTIONS
    -l                List config
    -e                Edit config interactively
    -n                Dry run (no changes)
    --zip-only        Only create archive
    --spread-only     Only distribute existing archive
    --silent          Minimal output
    -h, --help        Show this help

  🔹 EXAMPLES

    Run full backup:
      ruby zipandspreadscr_xplat.rb

    Dry run:
      ruby zipandspreadscr_xplat.rb -n

    Edit paths:
      ruby zipandspreadscr_xplat.rb -e

    Only create archive:
      ruby zipandspreadscr_xplat.rb --zip-only

    Only distribute:
      ruby zipandspreadscr_xplat.rb --spread-only

  🔹 STRUCTURE

    destination/
      ├── swap/
      │     latest archive goes here
      └── new-archives/
            older archives rotated here

  🔹 NOTES
    - Uses 'tar' for compression
    - Uses 'pv' (if installed) for real progress bar
    - Works on WSL, Linux, Windows

  HELP
end

# =======================
# RUN
# =======================
def run(entries, opts)
  src = entries.find { |e| e.kind == "source" && e.is_default && e.enabled }
  dests = entries.select { |e| e.kind == "dest" && e.enabled }

  archive = File.join(Dir.tmpdir, build_archive_name)

  create_archive(src.path, archive, opts[:dry], opts[:silent]) unless opts[:spread_only]
  spread_archive(archive, dests, opts[:dry], opts[:silent]) unless opts[:zip_only]

  puts "✔ Done."
end

# =======================
# CLI
# =======================
options = { list:false, edit:false, dry:false, silent:false, zip_only:false, spread_only:false, help:false }

OptionParser.new do |opts|
  opts.on("-l") { options[:list] = true }
  opts.on("-e") { options[:edit] = true }
  opts.on("-n") { options[:dry] = true }
  opts.on("--silent") { options[:silent] = true }
  opts.on("--zip-only") { options[:zip_only] = true }
  opts.on("--spread-only") { options[:spread_only] = true }
  opts.on("-h","--help") { options[:help] = true }
end.parse!

entries = read_entries

if options[:help]
  show_help
elsif options[:list]
  entries.each_with_index { |e,i| puts "[#{i}] #{e.kind}: #{e.name} -> #{e.path}" }
elsif options[:edit]
  edit_entries(entries)
else
  run(entries, options)
end
