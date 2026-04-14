require 'fileutils'
require 'thread'
require 'etc'

# === yt-downloader-Hardcore.rb ===
# 🚀 Autodetects formats, skips prompts, and runs full speed.

puts "\n🎬 yt-downloader Hardcore Mode: Full Throttle! ⚡\n"

DEFAULT_INPUT = '/mnt/c/scr/keys/tabs/brave/exported-tabs.txt'
DEFAULT_VIDEO = '/mnt/d/Wyvern/Music/clm/y-hold/'

media = 'video'
urls = File.readlines(DEFAULT_INPUT).map(&:strip)
puts "\n📌 Total URLs: #{urls.size}" # No prompts
exit if urls.empty?

out = DEFAULT_VIDEO # Default output
FileUtils.mkdir_p(out) unless Dir.exist?(out)

max_threads = [Etc.nprocessors / 2, 5, 10, 15, 20, 25].min

queue = Queue.new
urls.each { |url| queue << url }

threads = Array.new(max_threads) do
  Thread.new do
    until queue.empty?
      url = queue.pop(true) rescue nil
      next unless url

      cmd = "yt-dlp --ffmpeg-location "D:\scr\core\win\ffmpeg\bin\ffmpeg.exe" -S 'res,ext:mp4:m4a' --recode mp4 -o '#{out}/%(title)s.%(ext)s' #{url}"
      puts "🎯 #{url}"
      system(cmd)
    end
  end
end

threads.each(&:join)
