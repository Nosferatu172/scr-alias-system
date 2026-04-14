#!/usr/bin/env ruby

# ============================================
# Script Name: __SCRIPT_NAME__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
# ============================================

require 'optparse'


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