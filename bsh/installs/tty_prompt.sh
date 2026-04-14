#!/usr/bin/env bash

# ============================================
# Script Name: tty_prompt.sh
# Purpose: Install + Validate + Test Ruby TTY
# ============================================

set -euo pipefail

# ==================================================
# PATHS
# ==================================================

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

# ==================================================
# COLORS
# ==================================================

CYAN="\e[36m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

info()    { [[ "$QUIET" -eq 0 ]] && printf "%b[+] %s%b\n" "$CYAN" "$1" "$RESET"; }
success() { printf "%b[✔] %s%b\n" "$GREEN" "$1" "$RESET"; }
warn()    { printf "%b[!] %s%b\n" "$YELLOW" "$1" "$RESET"; }
error()   { printf "%b[✖] %s%b\n" "$RED" "$1" "$RESET"; }

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF

$SCRIPT_NAME

Usage:
  bash $SCRIPT_NAME [options]

Options:
  --install        Install TTY gems
  --check          Check TTY environment
  --fix            Apply WSL fixes
  --test           Run interactive Ruby test

Flags:
  -v, --verbose    Verbose output
  --debug          Debug mode
  -q, --quiet      Minimal output
  -h, --help       Show help

Examples:
  $SCRIPT_NAME --install --check --test
  $SCRIPT_NAME --fix

EOF
exit 0
}

handle_help_flags() {
    for arg in "$@"; do
        case "$arg" in
            -h|--h|--help|help) show_help ;;
        esac
    done
}

# ==================================================
# ENV HOOK
# ==================================================

pre_run_env() {
    command -v vpy >/dev/null 2>&1 && vpy on || true
}

post_run_env() {
    command -v vpy >/dev/null 2>&1 && vpy off || true
}

# ==================================================
# ARG PARSING
# ==================================================

VERBOSE=0
DEBUG=0
QUIET=0

DO_INSTALL=0
DO_CHECK=0
DO_FIX=0
DO_TEST=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose) VERBOSE=1 ;;
            --debug) DEBUG=1 ;;
            -q|--quiet) QUIET=1 ;;

            --install) DO_INSTALL=1 ;;
            --check) DO_CHECK=1 ;;
            --fix) DO_FIX=1 ;;
            --test) DO_TEST=1 ;;
        esac
        shift
    done
}

# ==================================================
# CORE FUNCTIONS
# ==================================================

install_tty() {
    info "Installing Ruby TTY gems..."
    gem install tty-prompt tty-color tty-cursor tty-screen tty-progress --no-document
    success "TTY gems installed"
}

check_tty() {
    info "Checking TTY environment..."

    echo "Ruby: $(ruby -v || echo 'missing')"
    echo "Gem:  $(gem -v || echo 'missing')"

    echo "TERM: ${TERM:-undefined}"
    echo "TTY:  $(ruby -e 'puts STDIN.tty?')"

    if [[ "$(ruby -e 'puts STDIN.tty?')" != "true" ]]; then
        warn "STDIN is not a TTY → interactive prompts WILL break"
    else
        success "TTY is valid"
    fi
}

fix_tty() {
    info "Applying WSL TTY fixes..."

    if ! grep -q "TERM=xterm-256color" ~/.bashrc; then
        echo 'export TERM=xterm-256color' >> ~/.bashrc
        success "Added TERM fix to ~/.bashrc"
    else
        info "TERM already configured"
    fi

    export TERM=xterm-256color
    success "TERM set for current session"
}

run_test() {
    info "Running interactive Ruby TTY test..."

    cat <<'RUBY' > /tmp/tty_test.rb
require 'tty-prompt'

prompt = TTY::Prompt.new

name = prompt.ask("What is your name?")
color = prompt.select("Pick a color:", %w(red green blue))

puts "Hello #{name}, you picked #{color}!"
RUBY

    ruby /tmp/tty_test.rb
}

# ==================================================
# MAIN LOGIC
# ==================================================

run() {

    [[ "$VERBOSE" -eq 1 ]] && info "Running $SCRIPT_NAME"
    [[ "$DEBUG" -eq 1 ]] && warn "Debug mode enabled"

    [[ "$DO_INSTALL" -eq 1 ]] && install_tty
    [[ "$DO_CHECK" -eq 1 ]] && check_tty
    [[ "$DO_FIX" -eq 1 ]] && fix_tty
    [[ "$DO_TEST" -eq 1 ]] && run_test

    if [[ "$DO_INSTALL" -eq 0 && "$DO_CHECK" -eq 0 && "$DO_FIX" -eq 0 && "$DO_TEST" -eq 0 ]]; then
        warn "No action specified → defaulting to --check"
        check_tty
    fi

    success "Finished successfully"
}

# ==================================================
# ENTRYPOINT
# ==================================================

main() {
    handle_help_flags "$@"
    parse_args "$@"

    pre_run_env
    trap 'post_run_env' EXIT

    run
}

main "$@"