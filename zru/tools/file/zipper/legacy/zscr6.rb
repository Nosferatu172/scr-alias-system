#!/usr/bin/env ruby
# zipandspreadscr_xplat.rb

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
# TAR CHECK
# =======================
def check_tar!
  case ENV_TYPE
  when :windows
    ok = system("where tar >nul 2>&1")
  else
    ok = system("which tar > /dev/null 2>&1")
  end

  unless ok
    puts "❌ 'tar' not found in PATH."
    puts "➡ Install tar (Linux: apt install tar)"
    exit(1)
  end
end

# =======================
# CSV DEFAULTS
# =======================
def ensure_default_config
  safe_mkdir(LOG_DIR)
  return if File.exist?(CSV_PATH)

  rows = []

  case ENV_TYPE
  when :windows
    rows << ["source","main","C:/scr","1","1"]
    %w[d e f g h i].each do |d|
      rows << ["dest", d, "#{d.upcase}:/scr","0","1"]
    end

  when :wsl
    rows << ["source","main","/mnt/c/scr","1","1"]
    %w[d e f g h i].each do |d|
      rows << ["dest", d, "/mnt/#{d}/scr","0","1"]
    end

  else # linux
    rows << ["source","main","/scr","1","1"]
    %w[d e f g h i].each do |d|
      rows << ["dest", d, "/mnt/#{d}/scr","0","1"]
    end
  end

  CSV.open(CSV_PATH, "w") do |csv|
    csv << %w[kind name path is_default enabled]
    rows.each { |r| csv << r }
  end

  puts "✔ Created config for #{ENV_TYPE}: #{CSV_PATH}"
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
  "scr-#{Time.now.strftime("%m-%d-%Y")}.tar.gz"
end

def create_archive(source, archive, dry, silent)
  source = File.expand_path(source)
  archive = File.expand_path(archive)

  vprint("📦 Archiving: #{source}", silent)
  return archive if dry

  unless Dir.exist?(source)
    puts "❌ Source missing: #{source}"
    exit(1)
  end

  check_tar!

  cmd = ["tar", "-czf", archive, "-C", source, "."]

  success = system(*cmd)

  unless success && File.exist?(archive)
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
# RUN
# =======================
def run(entries, opts)
  src = entries.find { |e| e.kind == "source" && e.is_default && e.enabled }
  dests = entries.select { |e| e.kind == "dest" && e.enabled }

  unless src
    puts "❌ No source set"
    return
  end

  archive = File.join(Dir.tmpdir, build_archive_name)

  create_archive(src.path, archive, opts[:dry], opts[:silent]) unless opts[:spread_only]
  spread_archive(archive, dests, opts[:dry], opts[:silent]) unless opts[:zip_only]

  vprint("✔ Done.", opts[:silent])
end

# =======================
# CLI
# =======================
options = { list: false, edit: false, dry: false, silent: false, zip_only: false, spread_only: false }

OptionParser.new do |opts|
  opts.on("-l") { options[:list] = true }
  opts.on("-e") { options[:edit] = true }
  opts.on("-n") { options[:dry] = true }
  opts.on("--silent") { options[:silent] = true }
  opts.on("--zip-only") { options[:zip_only] = true }
  opts.on("--spread-only") { options[:spread_only] = true }
end.parse!

entries = read_entries

if options[:list]
  entries.each_with_index { |e,i| puts "[#{i}] #{e.kind}: #{e.name} -> #{e.path}" }
elsif options[:edit]
  require 'tty-prompt'
  prompt = TTY::Prompt.new
  edit_entries(entries)
else
  run(entries, options)
end
