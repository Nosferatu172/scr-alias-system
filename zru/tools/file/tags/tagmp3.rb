#!/usr/bin/env ruby
# Script Name: tagmp3.rb
# ID: SCR-ID-20260329033010-RQCDJ1L6M8
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: tagmp3

require 'taglib'
require 'httparty'
require 'json'
require 'open-uri'

def get_directory
  print "Enter directory with MP3 files (or type 'exit'): "
  input = gets.chomp.strip
  exit if input.downcase == 'exit'
  return input if Dir.exist?(input)

  puts "Directory does not exist."
  get_directory
end

def prompt(field)
  print "#{field}: "
  gets.chomp.strip
end

def fetch_cover_art(artist, album)
  api_key = 'YOUR_LASTFM_API_KEY'
  url = "https://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=#{api_key}&artist=#{artist}&album=#{album}&format=json"

  response = HTTParty.get(url)
  data = JSON.parse(response.body)

  if data["album"] && data["album"]["image"]
    # Get the large cover art image URL
    image_url = data["album"]["image"].find { |img| img["size"] == "large" }["#text"]
    return image_url if image_url && !image_url.empty?
  end

  nil # Return nil if no image is found
end

def download_cover_image(url, cover_path)
  File.open(cover_path, 'wb') do |f|
    f.write URI.open(url).read
  end
end

def embed_cover(tag, cover_path)
  return unless File.exist?(cover_path)

  picture = TagLib::ID3v2::AttachedPictureFrame.new
  picture.mime_type = "image/jpeg"
  picture.description = "Cover"
  picture.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover
  picture.picture = File.open(cover_path, "rb") { |f| f.read }
  tag.add_frame(picture)
end

def tag_file(file_path, artist, title = nil, album = nil, cover_path = nil)
  TagLib::MPEG::File.open(file_path) do |file|
    tag = file.id3v2_tag

    tag.artist = artist
    tag.title  = title if title && !title.empty?
    tag.album  = album if album && !album.empty?
    embed_cover(tag, cover_path) if cover_path

    file.save
    puts "Tagged: #{File.basename(file_path)}"
  end
rescue => e
  puts "Failed to tag #{file_path}: #{e.message}"
end

def process_directory(dir)
  mp3_files = Dir.glob(File.join(dir, "*.mp3"))
  cover_path = File.join(dir, "cover.jpg")

  if mp3_files.empty?
    puts "No MP3 files found."
    return
  end

  puts "\nMP3 files detected:"
  mp3_files.each_with_index { |f, i| puts "#{i+1}. #{File.basename(f)}" }

  puts "\nWhat do you want to apply to these files?"
  artist = prompt("Artist")
  album  = prompt("Album (optional)")
  title_choice = prompt("Set title from filename? (yes/no)").downcase == "yes"

  # If no cover.jpg in directory, attempt to fetch cover art from Last.fm
  if !File.exist?(cover_path)
    puts "No cover.jpg found, attempting to fetch cover art..."
    cover_url = fetch_cover_art(artist, album)
    if cover_url
      download_cover_image(cover_url, cover_path)
      puts "Cover art downloaded from Last.fm."
    else
      puts "No cover art found on Last.fm."
    end
  end

  mp3_files.each do |file|
    title = title_choice ? File.basename(file, ".mp3").split(" - ").last : prompt("Title for #{File.basename(file)}")
    tag_file(file, artist, title, album, cover_path)
  end
end

def main
  puts "--- MP3 Metadata Tagger + Cover Art Fetching ---"
  dir = get_directory
  process_directory(dir)
  puts "\nDone tagging and embedding cover art."
end

main
