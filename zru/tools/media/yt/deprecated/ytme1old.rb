#!/usr/bin/env ruby

require 'fileutils'
require 'thread'
require 'etc'

INPUT_FILE  = ARGV[0] || '/mnt/c/scr/keys/tabs/new/exported-tabs.txt'
OUTPUT_DIR  = ARGV[1] || '/c/Users/tyler/Music/y-hold'
ARCHIVE     = File.join(OUTPUT_DIR, 'archive.txt')

FFMPEG_PATH = 'C:\msys64\mingw64\bin'

puts "\n🎬 ytme2 starting...\n"

unless File.exist?(INPUT_FILE)
puts "❌ Missing input file: #{INPUT_FILE}"
exit 1
end

urls = File.readlines(INPUT_FILE, chomp: true).reject(&:empty?)

if urls.empty?
puts "⚠️ No URLs found."
exit
end

FileUtils.mkdir_p(OUTPUT_DIR)

puts "📌 URLs: #{urls.size}"
puts "📁 Output: #{OUTPUT_DIR}"

max_threads = [Etc.nprocessors, 8].min
puts "⚙️ Threads: #{max_threads}"

queue = Queue.new
urls.each { |u| queue << u }

threads = Array.new(max_threads) do
Thread.new do
loop do
begin
url = queue.pop(true)
rescue ThreadError
break
end

  cmd = [
    "yt-dlp",
    "--ffmpeg-location", "\"#{FFMPEG_PATH}\"",
    "-S", "'res,ext:mp4:m4a'",
    "--recode", "mp4",
    "--download-archive", "\"#{ARCHIVE}\"",
    "-o", "'#{OUTPUT_DIR}/%(title).240s.%(ext)s'",
    "'#{url}'"
  ].join(" ")

  puts "🎯 #{url}"

  success = system(cmd)
  unless success
    puts "⚠️ Retry: #{url}"
    system(cmd)
  end
end

end
end

threads.each(&:join)

puts "\n✅ Done!\n"
