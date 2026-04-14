#!/usr/bin/env ruby
# Script Name: filename_generator_with_logging.rb
# ID: SCR-ID-20260329032501-GVJAORQ7J5
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: filename_generator_with_logging

require 'optparse'
require 'fileutils'
require 'time'

LOG_DIR = '/mnt/c/zru/filename-generators/logs/'
LOG_FILE = File.join(LOG_DIR, 'script.log')

def generate_unique_tag(length)
  charset = ('a'..'z').to_a +
            ('A'..'Z').to_a +
            ('0'..'9').to_a +
            %w[! @ # $ % ^ & * _ + - =]

  if length > charset.size
    puts "Max unique characters exceeded (#{charset.size})."
    return
  end

  charset.shuffle.take(length).join
end

def create_file_with_template(filename, note)
  content = <<~RUBY
    #!/usr/bin/env ruby
    # #{filename}
    # Generated on #{Time.now.utc.iso8601}
    # Notes: #{note.nil? || note.empty? ? "None" : note}

    def main
      puts "Script #{File.basename(__FILE__)} ran successfully."
    end

    main if __FILE__ == $PROGRAM_NAME
  RUBY

  File.write(filename, content)
  File.chmod(0755, filename)
  puts "Created #{filename}"
end

def log_creation(filename, note)
  FileUtils.mkdir_p(LOG_DIR)
  File.open(LOG_FILE, 'a') do |log|
    log.puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] Created: #{filename} #{note.nil? ? '' : "- Note: #{note}"}"
  end
end

# --- Command-line argument handling ---

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{$0} [options]"

  opts.on("-d", "--directory DIR", "Output directory") { |d| options[:dir] = d }
  opts.on("-l", "--length N", Integer, "Length of unique tag (default: 8)") { |l| options[:length] = l }
  opts.on("-n", "--note NOTE", "Optional note to log with the script") { |n| options[:note] = n }
end.parse!

dir = options[:dir] || "."
length = options[:length] || 8
note = options[:note]

unique = generate_unique_tag(length)
exit unless unique

FileUtils.mkdir_p(dir)
filename = File.join(dir, "file_ops-#{unique}.rb")

create_file_with_template(filename, note)
log_creation(filename, note)
