#!/usr/bin/env ruby
# Script Name: frag_script_gen-main.rb
# ID: SCR-ID-20260329032519-00S02FR4ZY
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: frag_script_gen-main

require 'securerandom'
require 'time'

def generate_unique_filename(base, length = 6)
  suffix = SecureRandom.hex(length / 2)
  "#{base}-#{suffix}.rb"
end

print "What base file name (e.g. file_ops)? "
base_name = gets.strip
base_name = "script" if base_name.empty?

filename = generate_unique_filename(base_name)
timestamp = Time.now.strftime("%Y-%m-%d")

header = <<~RUBY
  # #{filename}
  # Created on #{timestamp}
  # Description: 

RUBY

# Write header to new file
File.write(filename, header)

puts "Created new file: #{filename}"

# Open in nano
exec("nano #{filename}")
