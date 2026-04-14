#!/usr/bin/env ruby
# Script Name: filename_generator.rb
# ID: SCR-ID-20260329032452-N8OS3QV8VS
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: filename_generator

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

# Write the header to the new file
File.write(filename, header)

puts "Created new file: #{filename}"
