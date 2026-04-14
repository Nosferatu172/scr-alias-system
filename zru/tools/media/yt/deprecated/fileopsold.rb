#!/usr/bin/env ruby
# fileops.rb
# Centralized directory configuration (edit defaults here)
# Supports safe per-run overrides via ./fileops.local.json next to the scripts

require 'etc'
require 'open3'
require 'json'

module FileOps
  DEFAULT_DIRS = {
    brave_export_dir:   "/mnt/c/Users/{WIN_USER}/Documents/mine/brave/",
    default_music_dir:  "/mnt/f/Music/clm/y-hold/",
    default_videos_dir: "/mnt/f/Music/clm/Videos/y-hold/",
    music_artist_dir:   "/mnt/f/Music/clm/Active-org/",
    video_artist_dir:   "/mnt/f/Music/clm/Videos/Active-org/",
    cookies_dir:        "/mnt/c/scr/key/cookies/"
  }.freeze

  # -----------------------
  # Detect Windows username (WSL)
  # Priority:
  # 1) ENV["WINUSER"] (new standard)
  # 2) ENV["WIN_USER"] (legacy compatibility)
  # 3) /mnt/c/Windows/System32/cmd.exe (full path; avoids PATH issues)
  # 4) powershell.exe (if available)
  # 5) /mnt/c/Users directory heuristic
  # 6) Linux fallback
  # -----------------------
  def self.detect_win_user
    env_user = ENV["WINUSER"].to_s.strip
    return env_user unless env_user.empty?

    legacy = ENV["WIN_USER"].to_s.strip
    return legacy unless legacy.empty?

    # Try cmd.exe by full path (Kali WSL often doesn't have it in PATH)
    begin
      cmd_exe = "/mnt/c/Windows/System32/cmd.exe"
      if File.exist?(cmd_exe)
        out, _err, st = Open3.capture3(cmd_exe, "/c", "echo %USERNAME%")
        if st.success?
          u = out.to_s.strip
          return u unless u.empty? || u =~ /%USERNAME%/i
        end
      end
    rescue
    end

    # Try cmd.exe if it happens to be on PATH
    begin
      out, _err, st = Open3.capture3("cmd.exe", "/c", "echo %USERNAME%")
      if st.success?
        u = out.to_s.strip
        return u unless u.empty? || u =~ /%USERNAME%/i
      end
    rescue
    end

    # PowerShell fallback
    begin
      out, _err, st = Open3.capture3("powershell.exe", "-NoProfile", "-Command", "$env:UserName")
      if st.success?
        u = out.to_s.strip
        return u unless u.empty?
      end
    rescue
    end

    # Heuristic: pick a likely user dir under /mnt/c/Users
    begin
      if Dir.exist?("/mnt/c/Users")
        candidates = Dir.entries("/mnt/c/Users").reject { |n|
          n.start_with?(".") || ["All Users", "Default", "Default User", "Public"].include?(n)
        }

        preferred = candidates.find { |n| Dir.exist?("/mnt/c/Users/#{n}/Documents") }
        return preferred if preferred && !preferred.strip.empty?
        return candidates.first if candidates.any?
      end
    rescue
    end

    Etc.getlogin || ENV["USER"] || "tyler"
  end

  def self.with_win_user(template_path, win_user)
    template_path.to_s.gsub("{WIN_USER}", win_user.to_s)
  end

  def self.local_overrides_path(script_dir)
    File.join(script_dir.to_s, "fileops.local.json")
  end

  def self.load_local_overrides(script_dir)
    path = local_overrides_path(script_dir)
    return {} unless File.exist?(path)

    begin
      raw = JSON.parse(File.read(path))
      return {} unless raw.is_a?(Hash)
      raw.transform_keys { |k| k.to_s.strip.to_sym }
    rescue
      {}
    end
  end

  def self.save_local_overrides(script_dir, overrides_hash)
    path = local_overrides_path(script_dir)
    data = overrides_hash.transform_keys(&:to_s)
    tmp = path + ".tmp"

    File.open(tmp, "w") { |f| f.write(JSON.pretty_generate(data)) }
    File.rename(tmp, path)
    true
  rescue
    begin
      File.delete(tmp) if tmp && File.exist?(tmp)
    rescue
    end
    false
  end

  def self.build_dirs(win_user = nil, script_dir = nil)
    win_user ||= detect_win_user
    script_dir ||= Dir.pwd

    # Export for the rest of the process (so other code can just read ENV["WINUSER"])
    ENV["WINUSER"] ||= win_user
    ENV["WIN_USER"] ||= win_user # keep legacy too, harmless

    defaults  = DEFAULT_DIRS.transform_values { |v| with_win_user(v, win_user) }
    overrides = load_local_overrides(script_dir).transform_values { |v| with_win_user(v, win_user) }

    defaults.merge(overrides)
  end

  def self.valid_keys
    DEFAULT_DIRS.keys
  end
end
