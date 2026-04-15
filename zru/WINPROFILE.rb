#!/usr/bin/env ruby
# Script Name: WINPROFILE.rb
# ID: SCR-ID-20260329032925-0FMA4TMHB1
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: WINPROFILE

# =========================
# WINPROFILE BOOTSTRAP
# =========================

def valid_win_user_dir?(name)
  return false if name.nil? || name.strip.empty?

  bad = ["public", "default", "default user", "all users", "desktop.ini"]
  !bad.include?(name.strip.downcase)
end

def scan_winprofile
  root = "/mnt/c/Users"
  return nil unless Dir.exist?(root)

  candidates = Dir.children(root)
                  .select { |u| valid_win_user_dir?(u) }
                  .select { |u| File.directory?(File.join(root, u)) }

  # Prefer a user with Documents
  preferred = candidates.find do |u|
    File.directory?(File.join(root, u, "Documents"))
  end

  return File.join(root, preferred) if preferred

  # fallback: first valid user
  return File.join(root, candidates.first) if candidates.any?

  nil
end

def load_winprofile_from_main
  main_sh = ""   # <-- change if you use one

  return nil unless File.exist?(main_sh)

  result = `bash -c 'source "#{main_sh}" >/dev/null 2>&1 && echo $WINPROFILE'`.strip
  return result unless result.empty?

  nil
end

# -------------------------
# Resolve WINPROFILE
# -------------------------

WINPROFILE =
  ENV["WINPROFILE"] ||
  load_winprofile_from_main ||
  scan_winprofile

# -------------------------
# Hard fallback (optional safety)
# -------------------------
if WINPROFILE.nil? || WINPROFILE.empty?
  puts "❌ Could not auto-detect WINPROFILE."
  print "Enter Windows username folder manually: "
  input = STDIN.gets&.strip

  if input.nil? || input.empty?
    puts "❌ No input provided. Exiting."
    exit 1
  end

  WINPROFILE = "/mnt/c/Users/#{input}"
end

# -------------------------
# Final sanity check
# -------------------------
unless File.directory?(WINPROFILE)
  puts "❌ WINPROFILE path invalid: #{WINPROFILE}"
  exit 1
end

# =========================
# READY
# =========================

puts "✔ WINPROFILE resolved: #{WINPROFILE}"
puts "sample.rb for resolving the snippet needed for each script"
puts "this helps resolve the need for the sh file in the aliases"
