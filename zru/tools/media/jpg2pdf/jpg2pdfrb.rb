#!/usr/bin/env ruby
# Script Name: jpg2pdf.rb
# ID: SCR-ID-20260329012742-7D3U05CW7J
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scr jpg2pdf

require 'fileutils'
require 'prawn'
require 'optparse'
require 'csv'

# =========================================================
# SCRIPT-LOCAL CONFIG (portable, no root usage)
# =========================================================

SCRIPT_DIR = File.dirname(File.realpath(__FILE__))
CONFIG_FILE = File.join(SCRIPT_DIR, "jpeg2pdf_config.csv")

def load_config
  return {} unless File.exist?(CONFIG_FILE)

  config = {}
  CSV.foreach(CONFIG_FILE) do |row|
    key, value = row
    config[key] = value
  end
  config
end

def save_config(config)
  CSV.open(CONFIG_FILE, "w") do |csv|
    config.each do |k, v|
      csv << [k, v]
    end
  end
end

config = load_config

# =========================================================
# WINPROFILE fallback
# =========================================================

def scan_winprofile
  root = "/mnt/c/Users"
  return nil unless Dir.exist?(root)

  candidates = Dir.children(root)
                  .reject { |u| ["public", "default", "all users", "default user"].include?(u.downcase) }

  preferred = candidates.find do |u|
    File.directory?(File.join(root, u, "Documents"))
  end

  return File.join(root, preferred) if preferred
  return File.join(root, candidates.first) if candidates.any?

  nil
end

WINPROFILE = ENV["WINPROFILE"] || scan_winprofile

# =========================================================
# DEFAULTS (config overrides WINPROFILE)
# =========================================================

DEFAULT_INPUT =
  config["default_input"] ||
  (WINPROFILE ? "#{WINPROFILE}/Documents/czur/scans" : Dir.pwd)

DEFAULT_OUTPUT =
  WINPROFILE ? "#{WINPROFILE}/Documents/czur/pdfs/output.pdf" : "#{Dir.pwd}/output.pdf"

# =========================================================
# CLI OPTIONS
# =========================================================

options = {
  input: DEFAULT_INPUT,
  output: DEFAULT_OUTPUT,
  show: false,
  active: false,
  set_default: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: jpeg2pdf [options]"

  opts.on("-eDIR", "Set input directory AND save as default") do |dir|
    options[:input] = dir
    options[:set_default] = true
  end

  opts.on("-oFILE", "Output PDF file") do |file|
    options[:output] = file
  end

  opts.on("-a", "Use active directory") do
    options[:active] = true
  end

  opts.on("-l", "Show resolved paths") do
    options[:show] = true
  end

  opts.on("-h", "Help") do
    puts opts
    exit
  end
end.parse!

# =========================================================
# ACTIVE DIRECTORY OVERRIDE
# =========================================================

options[:input] = Dir.pwd if options[:active]

input_dir = File.expand_path(options[:input])
output_pdf = File.expand_path(options[:output])

# =========================================================
# SAVE DEFAULT IF -e USED
# =========================================================

if options[:set_default]
  config["default_input"] = input_dir
  save_config(config)
  puts "💾 Saved default input directory → #{input_dir}"
end

# =========================================================
# DEBUG MODE
# =========================================================

if options[:show]
  puts "Input:   #{input_dir}"
  puts "Output:  #{output_pdf}"
  puts "Config:  #{CONFIG_FILE}"
  puts "WINPROFILE: #{WINPROFILE || 'nil'}"
  exit
end

# =========================================================
# IMAGE COLLECTION
# =========================================================

def collect_images(dir)
  Dir.glob(File.join(dir, "*.{jpg,jpeg,JPG,JPEG}")).sort
end

# =========================================================
# PDF BUILD
# =========================================================

def build_pdf(images, output)
  if images.empty?
    puts "❌ No images found"
    exit 1
  end

  FileUtils.mkdir_p(File.dirname(output))

  Prawn::Document.generate(output, page_size: 'LETTER', margin: 18) do |pdf|
    images.each_with_index do |img, i|
      pdf.start_new_page unless i.zero?

      begin
        pdf.text File.basename(img), size: 10, style: :bold
        pdf.move_down 8

        pdf.image img,
          fit: [pdf.bounds.width, pdf.bounds.height - 20],
          position: :center,
          vposition: :center

      rescue => e
        pdf.text "Failed: #{img}", color: "FF0000"
        pdf.text e.message, size: 8
      end
    end
  end

  puts "✔ PDF saved: #{output}"
end

# =========================================================
# RUN
# =========================================================

images = collect_images(input_dir)

puts "Input:  #{input_dir}"
puts "Output: #{output_pdf}"
puts "Images: #{images.size}"
puts

build_pdf(images, output_pdf)
