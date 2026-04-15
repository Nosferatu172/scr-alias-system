#!/usr/bin/env ruby

# ============================================
# Script Name: __SCRIPT_NAME__
# ID: __SCR_ID__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
# Assigned with: mktool
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: __ALIAS_CALL__
# ============================================

require 'optparse'
require 'rbconfig'


# ==================================================
# PATHS
# ==================================================

SCRIPT_PATH = File.expand_path(__FILE__)
SCRIPT_DIR  = File.dirname(SCRIPT_PATH)
SCRIPT_NAME = File.basename(SCRIPT_PATH)


# ==================================================
# COLORS
# ==================================================

CYAN  = "\e[36m"
GREEN = "\e[32m"
RED   = "\e[31m"
YELLOW = "\e[33m"
RESET = "\e[0m"


def info(msg)   = puts("#{CYAN}[+] #{msg}#{RESET}")
def success(msg)= puts("#{GREEN}[✔] #{msg}#{RESET}")
def warn(msg)   = puts("#{YELLOW}[!] #{msg}#{RESET}")
def error(msg)  = puts("#{RED}[✖] #{msg}#{RESET}")


# ==================================================
# ENVIRONMENT DETECTION
# ==================================================

def detect_os
  case RbConfig::CONFIG['host_os']
  when /linux/
    if File.exist?('/etc/os-release')
      File.readlines('/etc/os-release').each do |line|
        return $1.strip.gsub('"', '') if line =~ /^ID=(.+)$/
      end
    end
    'linux'
  when /darwin/
    'macos'
  when /mingw|mswin/
    'windows'
  else
    'unknown'
  end
end

def detect_arch
  RbConfig::CONFIG['host_cpu']
end

def detect_env
  if ENV['WSL_DISTRO_NAME']
    'wsl'
  elsif ENV['TERMUX_VERSION']
    'termux'
  elsif Dir.exist?('/mnt/c')
    'wsl'
  else
    'native'
  end
end

def detect_wsl
  # Check for WSL environment variables
  if ENV['WSL_DISTRO_NAME']
    # WSL_DISTRO_NAME exists in both WSL1 and WSL2
    'wsl'
  elsif ENV['WSLENV'] || ENV['WSL_INTEROP']
    # WSLENV/WSL_INTEROP indicate WSL2 interop
    'wsl2'
  elsif Dir.exist?('/mnt/c') && File.exist?('/proc/version')
    begin
      content = File.read('/proc/version').downcase
      (content.include?('microsoft') || content.include?('wsl')) ? 'wsl' : 'false'
    rescue
      'false'
    end
  else
    'false'
  end
end

def detect_wsl_distro
  if ENV['WSL_DISTRO_NAME']
    ENV['WSL_DISTRO_NAME']
  elsif File.exist?('/etc/os-release')
    begin
      File.readlines('/etc/os-release').each do |line|
        return $1.strip.gsub('"', '') if line =~ /^PRETTY_NAME=(.+)$/
      end
    rescue
    end
  end
  'unknown'
end


# ==================================================
# SCR ENVIRONMENT CORE (UNIFIED VIEW)
# ==================================================

def scr_env
  @scr_env ||= begin
    os_raw = RbConfig::CONFIG['host_os']

    env = {
      os: :unknown,
      arch: RbConfig::CONFIG['host_cpu'],
      distro: nil,
      wsl: false,
      mode: :native
    }

    # OS
    case os_raw
    when /linux/
      env[:os] = :linux

      if File.exist?('/etc/os-release')
        File.readlines('/etc/os-release').each do |line|
          env[:distro] = $1.strip.gsub('"','') if line =~ /^ID=(.+)$/
        end
      end

    when /darwin/
      env[:os] = :mac

    when /mingw|mswin/
      env[:os] = :windows
    end

    # WSL
    env[:wsl] =
      ENV['WSL_DISTRO_NAME'] ||
      ENV['WSLENV'] ||
      (File.exist?('/mnt/c') && File.read('/proc/version') =~ /microsoft/i)

    env[:wsl] = !!env[:wsl]

    # mode
    env[:mode] =
      if env[:wsl]
        :wsl
      else
        env[:os]
      end

    env
  end
end


# ==================================================
# HELP SYSTEM (MULTI ENTRY SUPPORT)
# ==================================================

def show_help
  puts <<~HELP

  #{SCRIPT_NAME}

  Usage:
    ruby #{SCRIPT_NAME} [options]

  Help:
    -h, --h, --help, help     Show this help

  Options:
    -v, --verbose             Verbose output
        --debug              Debug mode
    -q, --quiet              Minimal output

  HELP

  exit 0
end


def handle_help_flags(args)
  return if args.empty?

  if args.any? { |a| ["-h", "--h", "--help", "help"].include?(a) }
    show_help
  end
end


# ==================================================
# ENV HOOK SYSTEM (VPY INTEGRATION)
# ==================================================

def pre_run_env
  # optional external hook
  system("vpy on")
rescue
  # ignore environment failures silently
end


def post_run_env
  system("vpy off")
rescue
end


# ==================================================
# ARG PARSER
# ==================================================

def parse_args(raw_args)
  options = {
    verbose: false,
    debug: false,
    quiet: false
  }

  OptionParser.new do |opts|
    opts.on("-v", "--verbose") { options[:verbose] = true }
    opts.on("--debug") { options[:debug] = true }
    opts.on("-q", "--quiet") { options[:quiet] = true }

    # intentionally NOT used for auto-help (we handle manually)
  end.parse!(raw_args)

  options
end


# ==================================================
# MAIN LOGIC
# ==================================================

def run(options)
  info("Running #{SCRIPT_NAME}") if options[:verbose]
  info("Directory: #{SCRIPT_DIR}") if options[:verbose]

  warn("Debug mode enabled") if options[:debug]

  # -----------------------------
  # YOUR LOGIC HERE
  # -----------------------------

  success("Finished successfully")
end


# ==================================================
# ENTRYPOINT
# ==================================================

def main
  raw_args = ARGV.dup

  handle_help_flags(raw_args)

  options = parse_args(raw_args)

  pre_run_env

  begin
    run(options)
    return 0
  rescue => e
    error(e.message)
    return 1
  ensure
    post_run_env
  end
end


exit(main)