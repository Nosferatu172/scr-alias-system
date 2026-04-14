#!/usr/bin/env bash

# ============================================
# Script Name: cmus.sh
# ID: SCR-ID-20260414115939-7TJW4SV6NO
# Purpose: Installing Cmus (apt / source / auto)
# Created: 2026-04-14 11:59:39
# Path: /mnt/c/scr/bsh/installs/cmus.sh
# Assigned with: mktool
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cmus
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

info()    { printf "%b[+] %s%b\n" "$CYAN" "$1" "$RESET"; }
success() { printf "%b[✔] %s%b\n" "$GREEN" "$1" "$RESET"; }
warn()    { printf "%b[!] %s%b\n" "$YELLOW" "$1" "$RESET"; }
error()   { printf "%b[✖] %s%b\n" "$RED" "$1" "$RESET"; }

# ==================================================
# ENV DETECTION
# ==================================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        . /etc/os-release 2>/dev/null && echo "$ID" || echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF

$SCRIPT_NAME

Usage:
  bash $SCRIPT_NAME [options]

Modes:
  --auto        Decide best install method (default)
  --apt         Install via apt only
  --source      Build from GitHub source

Options:
  --clean       Remove build directory after install
  -v, --verbose Verbose output
  --debug       Debug mode
  -q, --quiet   Minimal output

Help:
  -h, --help    Show help

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
# ENV HOOKS
# ==================================================

pre_run_env() {
    command -v vpy >/dev/null 2>&1 && vpy on || true
}

post_run_env() {
    command -v vpy >/dev/null 2>&1 && vpy off || true
}

# ==================================================
# ARGS
# ==================================================

VERBOSE=0
DEBUG=0
QUIET=0

MODE="auto"
CLEAN=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto) MODE="auto" ;;
            --apt) MODE="apt" ;;
            --source) MODE="source" ;;
            --clean) CLEAN=1 ;;
            -v|--verbose) VERBOSE=1 ;;
            --debug) DEBUG=1 ;;
            -q|--quiet) QUIET=1 ;;
        esac
        shift
    done
}

# ==================================================
# INSTALL FUNCTIONS
# ==================================================

install_deps() {
    info "Installing dependencies"
    sudo apt update -y

    sudo apt install -y \
        pkg-config \
        libncursesw5-dev \
        libfaad-dev \
        libao-dev \
        libasound2-dev \
        libcddb2-dev \
        libcdio-cdda-dev \
        libdiscid-dev \
        libavformat-dev \
        libavcodec-dev \
        libswresample-dev \
        libflac-dev \
        libjack-dev \
        libmad0-dev \
        libmodplug-dev \
        libmpcdec-dev \
        libsystemd-dev \
        libopusfile-dev \
        libpulse-dev \
        libsamplerate0-dev \
        libsndio-dev \
        libvorbis-dev \
        libwavpack-dev \
        man
}

install_apt() {
    info "Installing cmus via apt"
    sudo apt update -y
    sudo apt install -y cmus
}

install_source() {

    WORKDIR="$HOME/cmus-build"

    install_deps

    if [[ -d "$WORKDIR" ]]; then
        warn "Existing repo found, updating"
        cd "$WORKDIR"
        git pull
    else
        info "Cloning cmus"
        git clone https://github.com/cmus/cmus.git "$WORKDIR"
        cd "$WORKDIR"
    fi

    info "Building cmus"
    make

    if [[ "$CLEAN" -eq 1 ]]; then
        info "Cleaning build directory"
        rm -rf "$WORKDIR"
    fi
}

auto_install() {
    info "Auto mode selected"

    if command -v apt >/dev/null 2>&1; then
        info "Using apt (preferred)"
        install_apt
    else
        warn "apt not found, falling back to source"
        install_source
    fi
}

# ==================================================
# MAIN
# ==================================================

run() {

    [[ "$VERBOSE" -eq 1 ]] && info "Running $SCRIPT_NAME"

    case "$MODE" in
        apt)
            install_apt
            ;;
        source)
            install_source
            ;;
        auto)
            auto_install
            ;;
        *)
            error "Unknown mode: $MODE"
            exit 1
            ;;
    esac

    success "cmus setup complete"
    info "Run: cmus -h"
}

# ==================================================
# ENTRY
# ==================================================

main() {

    handle_help_flags "$@"
    parse_args "$@"

    pre_run_env
    trap 'post_run_env' EXIT

    run
}

main "$@"
