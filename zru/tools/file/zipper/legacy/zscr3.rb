#!/usr/bin/env ruby
# zipandspreadscr.rb - Archive and spread /scr folders on Windows natively

require 'csv'
require 'fileutils'
require 'optparse'
require 'time'

# =======================
# Ctrl+C handler
# =======================
trap("INT") do
  puts "\n⛔ Cancelled (Ctrl+C). Exiting cleanly."
  exit(130)
end

# =======================
# Paths / Config
# =======================
SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
LOG_DIR = File.join(SCRIPT_DIR, "logs")
CSV_PATH = File.join(LOG_DIR, "dirs.csv")

DirEntry = Struct.new(:kind, :name, :path, :is_default, :enabled)

# =======================
# Helpers
# =======================
def vprint(msg, silent=false)
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

def print_progress(current, total, width=40)
  total = 1 if total <= 0
  ratio = current.to_f / total
  filled = (width * ratio).to_i
  bar = "#" * filled + "-" * (width - filled)
  percent = (ratio * 100).round(1)
  print "\rProgress: [#{bar}] #{current}/#{total} (#{percent}%)"
  puts if current >= total
end

# =======================
# CSV Handling
# =======================
def ensure_default_config
  safe_mkdir(LOG_DIR)
  return if File.exist?(CSV_PATH)

  rows = []
  rows << ["source","main","C:/scr","1","1"]
  %w[d e f g h i].each { |d| rows << ["dest", d, "#{d}/scr","0","1"] }

  CSV.open(CSV_PATH, "w") do |csv|
    csv << %w[kind name path is_default enabled]
    rows.each { |r| csv << r }
  end

  puts "? Created default config: #{CSV_PATH}"
end

def read_entries
  ensure_default_config
  entries = []
  CSV.foreach(CSV_PATH, headers: true) do |r|
    entries << DirEntry.new(
      r["kind"], r["name"], r["path"],
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
    entries.each { |e| csv << [e.kind, e.name, e.path, bool_to_str(e.is_default), bool_to_str(e.enabled)] }
  end
end

# =======================
# Archive Helpers
# =======================
def build_archive_name
  "scr-#{Time.now.strftime("%m-%d-%Y")}.tar.gz"
end

def create_archive(source, archive, dry=false, silent=false)
  vprint("Archiving: #{source}", silent)
  return archive if dry

  swap_dir = File.join(source, "swap")
  safe_mkdir(swap_dir)
  archive_path = File.join(swap_dir, next_available_name(swap_dir, File.basename(archive)))

  items = Dir.entries(source).reject { |e| e == "." || e == ".." || e == File.basename(archive_path) }
  total = items.size
  system("tar -czf #{archive_path} -C #{source} .")
  items.each_with_index { |_, i| print_progress(i+1, total) }
  vprint("? Created: #{archive_path}", silent)
  archive_path
end

def rotate_swap(swap, new_archives, dry=false, label="", silent=false)
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

def spread_archive(archive, dests, dry=false, silent=false)
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
      FileUtils.cp(archive, target)
      vprint("➡️  #{d.name}: copied -> #{target}", silent)
    end
  end
end

# =======================
# Main Logic
# =======================
def run(entries, opts)
  src = entries.find { |e| e.kind == "source" && e.is_default && e.enabled }
  dests = entries.select { |e| e.kind == "dest" && e.enabled }
  unless src
    puts "? No default source"
    return
  end
  source_dir = src.path
  archive = File.join(source_dir, build_archive_name)
  unless opts[:spread_only]
    archive = create_archive(source_dir, archive, opts[:dry], opts[:silent])
  end
  unless opts[:zip_only]
    spread_archive(archive, dests, opts[:dry], opts[:silent])
  end
  vprint("? Done.", opts[:silent])
end

# =======================
# Help
# =======================
def print_help
  puts <<~HELP
    zipandspreadscr.rb - Archive and spread /scr folders

    Usage:
      ruby zscr.rb [options]

    Options:
      -l                List all configured sources and destinations.
      -e                Edit configuration interactively.
      -n                Dry run: show what would happen without writing files.
      --silent          Suppress normal output; only show errors.
      -h, --help        Show this help message and exit.

    Behavior:
      Archives default source into timestamped .tar.gz inside 'swap/'
      Rotates old archives in 'swap/' into 'new-archives/' with suffixes (a, b, ...)
      Spreads archive to all enabled destinations
      Supports multiple runs per day with automatic suffixes
      Ctrl+C exits cleanly

    Examples:
      ruby zscr.rb
      ruby zscr.rb -l
      ruby zscr.rb -e
      ruby zscr.rb -n
      ruby zscr.rb --silent
  HELP
end

# =======================
# CLI
# =======================
options = { dry: false, silent: false, zip_only: false, spread_only: false }

if ARGV.include?("-h") || ARGV.include?("--help")
  print_help
  exit
elsif ARGV.include?("-l")
  read_entries.each { |e| puts "[#{e.kind}] #{e.name} -> #{e.path}" }
  exit
elsif ARGV.include?("-e")
  # simple placeholder edit menu
  puts "Interactive edit menu not implemented in this snippet."
  exit
end

ARGV.each do |arg|
  options[:dry] = true if arg == "-n"
  options[:silent] = true if arg == "--silent"
end

run(read_entries, options)
