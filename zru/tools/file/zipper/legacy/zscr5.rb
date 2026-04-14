#!/usr/bin/env ruby
# Script Name: zipandspreadscr.rb
# Description: Archive a source /scr folder, rotate old archives, and spread to enabled destinations.

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
# Paths
# =======================
SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
LOG_DIR = File.join(SCRIPT_DIR, "logs")
CSV_PATH = File.join(LOG_DIR, "dirs.csv")

# =======================
# Model
# =======================
DirEntry = Struct.new(:kind, :name, :path, :is_default, :enabled)

# =======================
# Helpers
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

def suffix_from_index(n)
  letters = []
  loop do
    n, r = n.divmod(26)
    letters << ("a".ord + r).chr
    break if n == 0
    n -= 1
  end
  letters.reverse.join
end

def next_available_name(dest_dir, base)
  return base unless File.exist?(File.join(dest_dir, base))
  stem = base.sub(/\.tar\.gz$/, "")
  i = 0
  loop do
    name = "#{stem}#{suffix_from_index(i)}.tar.gz"
    return name unless File.exist?(File.join(dest_dir, name))
    i += 1
  end
end

# =======================
# CSV
# =======================
def ensure_default_config
  safe_mkdir(LOG_DIR)
  return if File.exist?(CSV_PATH)

  rows = []
  rows << ["source","main","C:/scr","1","1"]

  %w[d e f g h i].each do |d|
    rows << ["dest", d, "#{d.upcase}:/scr","0","1"]
  end

  CSV.open(CSV_PATH, "w") do |csv|
    csv << %w[kind name path is_default enabled]
    rows.each { |r| csv << r }
  end

  puts "✔ Created default config: #{CSV_PATH}"
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
# Archive
# =======================
def build_archive_name
  "scr-#{Time.now.strftime("%m-%d-%Y")}.tar.gz"
end

def check_tar!
  unless system("where tar >nul 2>&1")
    puts "❌ 'tar' not found in PATH."
    puts "➡ Install bsdtar or use Git Bash / WSL."
    exit(1)
  end
end

def create_archive(source, archive, dry, silent)
  source = File.expand_path(source)
  archive = File.expand_path(archive)

  vprint("📦 Archiving: #{source}", silent)
  return archive if dry

  unless Dir.exist?(source)
    puts "❌ Source does not exist: #{source}"
    exit(1)
  end

  check_tar!

  cmd = [
    "tar",
    "-czf", archive,
    "-C", source,
    "."
  ]

  success = system(*cmd)

  unless success && File.exist?(archive)
    puts "❌ Failed to create archive"
    exit(1)
  end

  vprint("✔ Created: #{archive}", silent)
  archive
end

def rotate_swap(swap, new_archives, dry, label, silent)
  Dir.glob(File.join(swap, "*.tar.gz")).each do |file|
    name = File.basename(file)
    dest = next_available_name(new_archives, name)
    dest_path = File.join(new_archives, dest)

    if dry
      vprint("DRY: move #{file} -> #{dest_path}", silent)
    else
      safe_mkdir(new_archives)
      FileUtils.mv(file, dest_path)
      vprint("📦 #{label}: rotated #{dest}", silent)
    end
  end
end

def spread_archive(archive, dests, dry, silent)
  dests.each do |d|
    base = d.path
    next unless is_dir?(base)

    swap = File.join(base, "swap")
    new_archives = File.join(base, "new-archives")

    safe_mkdir(swap) unless dry
    safe_mkdir(new_archives) unless dry

    rotate_swap(swap, new_archives, dry, d.name, silent)

    target = File.join(swap, File.basename(archive))

    if dry
      vprint("DRY: copy #{archive} -> #{target}", silent)
    else
      FileUtils.cp(archive, target, preserve: true)
      vprint("✅ #{d.name}: copied -> #{target}", silent)
    end
  end
end

# =======================
# Interactive edit
# =======================
def edit_entries(entries)
  prompt = TTY::Prompt.new

  loop do
    choices = entries.map.with_index do |e,i|
      "#{i}: #{e.kind} | #{e.name} -> #{e.path} | #{e.enabled ? 'enabled' : 'disabled'}#{e.is_default ? ' | default' : ''}"
    end

    choices << "Done"

    selection = prompt.select("Select entry to edit:", choices, per_page: 15)
    break if selection == "Done"

    index = selection.split(":").first.to_i
    entry = entries[index]

    new_path = prompt.ask("Path for #{entry.kind}: #{entry.name}?", default: entry.path)
    entry.path = File.expand_path(new_path) unless new_path.to_s.strip.empty?

    entry.enabled = prompt.yes?("Enable #{entry.name}?")

    if entry.kind == "source"
      entry.is_default = prompt.yes?("Mark as default?")
      if entry.is_default
        entries.each { |e| e.is_default = false if e.kind == "source" && e != entry }
      end
    end
  end

  write_entries(entries)
  puts "✔ Entries updated."
end

# =======================
# Run backup
# =======================
def run(entries, opts)
  src = entries.find { |e| e.kind == "source" && e.is_default && e.enabled }
  dests = entries.select { |e| e.kind == "dest" && e.enabled }

  unless src
    puts "❌ No default source set."
    return
  end

  archive_name = build_archive_name
  archive_path = File.join(Dir.tmpdir, archive_name)

  create_archive(src.path, archive_path, opts[:dry], opts[:silent]) unless opts[:spread_only]
  spread_archive(archive_path, dests, opts[:dry], opts[:silent]) unless opts[:zip_only]

  vprint("✔ Done.", opts[:silent])
end

# =======================
# Help
# =======================
def show_help
  puts <<~HELP

    zipandspreadscr.rb - Archive and spread /scr folders

    Usage:
      ruby zscr.rb [options]

    Options:
      -l                List config
      -e                Edit config
      -n                Dry run
      --silent          Quiet mode
      --zip-only        Only archive
      --spread-only     Only spread
      -h, --help        Show help

  HELP
end

# =======================
# CLI
# =======================
options = {
  list: false,
  edit: false,
  dry: false,
  silent: false,
  zip_only: false,
  spread_only: false,
  help: false
}

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
  entries.each_with_index do |e,i|
    puts "[#{i}] #{e.kind}: #{e.name} -> #{e.path} #{e.enabled ? '' : '(disabled)'}"
  end
elsif options[:edit]
  edit_entries(entries)
else
  run(entries, options)
end
