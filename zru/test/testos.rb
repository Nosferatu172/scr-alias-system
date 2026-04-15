#!/usr/bin/env ruby
# Script Name: testos.rb
# ID: SCR-ID-20260329033028-1TQWKK995Z
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: testos

def detect_environment
  is_windows = !!(RUBY_PLATFORM =~ /mingw|mswin/)
  # WSL detection by environment variables regardless of OS platform
  is_scr = ENV.key?('WSL_DISTRO_NAME') || ENV.key?('WSL_INTEROP') || ENV.key?('WSLENV')

  # Optional: double check scr via reading /proc/version if env vars missing
  if !is_scr && File.exist?('/proc/version')
    content = File.read('/proc/version').downcase
    is_scr = content.include?('microsoft')
  end

  { is_windows: is_windows, is_scr: is_scr }
end

env = detect_environment

puts "Running environment detection:"
puts "  Windows: #{env[:is_windows]}"
puts "  WSL: #{env[:is_scr]}"

