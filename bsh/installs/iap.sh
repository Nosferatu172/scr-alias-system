#!/usr/bin/env bash

# ============================================
# Script Name: iap.sh
# Purpose: APT Package Orchestrator
# ============================================

set -uo pipefail

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
# FLAGS
# ==================================================

VERBOSE=0
DEBUG=0
QUIET=0

DO_INSTALL=0
DO_VERIFY=0
DO_CLEAN=0
DO_LIST=0
DO_DRYRUN=0

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF

iap - APT Package Orchestrator

Usage:
  iap [options]

Actions:
  --install        Install packages
  --verify         Check package availability
  --clean          Normalize + dedupe packages
  --list           Show package list
  --dry-run        Simulate install (no changes)

Flags:
  -v, --verbose    Verbose output
  --debug          Debug mode
  -q, --quiet      Minimal output
  -h, --help       Show help

Examples:
  iap --install
  iap --clean --verify --install
  iap --list
  iap --dry-run

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
# ARG PARSE
# ==================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose) VERBOSE=1 ;;
            --debug) DEBUG=1 ;;
            -q|--quiet) QUIET=1 ;;

            --install) DO_INSTALL=1 ;;
            --verify) DO_VERIFY=1 ;;
            --clean) DO_CLEAN=1 ;;
            --list) DO_LIST=1 ;;
            --dry-run) DO_DRYRUN=1 ;;
        esac
        shift
    done
}

# ==================================================
# PACKAGE SET
# ==================================================

load_packages() {

CORE_PKGS=(git curl wget file rsync tar xz-utils zip unzip gzip rzip p7zip build-essential ca-certificates aptitude pkg-config patch lftp)

DEV_PKGS=(autoconf bison libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgdbm-dev libgdbm-compat-dev libdb-dev uuid-dev libncurses5-dev libncursesw5-dev libsqlite3-dev libxml2-dev libxslt1-dev libpq-dev python3-dev python3-pip python3-venv)

MEDIA_PKGS=(ffmpeg imagemagick libavformat-dev libavcodec-dev libswresample-dev libflac-dev libvorbis-dev libwavpack-dev libmad0-dev libmpcdec-dev libmodplug-dev libopusfile-dev libsamplerate0-dev libasound2-dev libpulse-dev libjack-dev libsndio-dev libao-dev libfaad-dev)

IMAGE_PDF_PKGS=(libjpeg-turbo-progs libheif1 libheif-examples poppler-utils qpdf pdftk img2pdf libimage-exiftool-perl)

APPS_PKGS=(vlc mpv audacious libreoffice mystiq caffeine)

SEC_PKGS=(john hashcat)

MISC_PKGS=(sqlite3)

ALL_PKGS=(
    "${CORE_PKGS[@]}"
    "${DEV_PKGS[@]}"
    "${MEDIA_PKGS[@]}"
    "${IMAGE_PDF_PKGS[@]}"
    "${APPS_PKGS[@]}"
    "${SEC_PKGS[@]}"
    "${MISC_PKGS[@]}"
)

}

# ==================================================
# CLEAN
# ==================================================

clean_packages() {
    info "Cleaning package list..."

    declare -A map=(
        [p7zip]=7zip
        [pdftk]=pdftk-java
        [libncurses5-dev]=libncurses-dev
        [libncursesw5-dev]=libncurses-dev
    )

    local cleaned=()
    declare -A seen=()

    for pkg in "${ALL_PKGS[@]}"; do
        [[ -n "${map[$pkg]:-}" ]] && pkg="${map[$pkg]}"
        [[ -z "${seen[$pkg]:-}" ]] && cleaned+=("$pkg") && seen[$pkg]=1
    done

    ALL_PKGS=("${cleaned[@]}")
}

# ==================================================
# VERIFY
# ==================================================

verify_packages() {
    info "Verifying packages..."

    local valid=()
    for pkg in "${ALL_PKGS[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            valid+=("$pkg")
        else
            warn "Missing: $pkg"
        fi
    done

    ALL_PKGS=("${valid[@]}")
}

# ==================================================
# LIST
# ==================================================

list_packages() {
    info "Package list:"
    for pkg in "${ALL_PKGS[@]}"; do
        echo " - $pkg"
    done
}

# ==================================================
# INSTALL
# ==================================================

install_packages() {

    APT_FLAGS="-y"
    [[ "$QUIET" -eq 1 ]] && APT_FLAGS="-y -qq"
    [[ "$DEBUG" -eq 1 ]] && set -x

    info "Updating..."
    sudo apt update $APT_FLAGS

    if [[ "$DO_DRYRUN" -eq 1 ]]; then
        info "Dry run enabled (no changes)"
        sudo apt install --dry-run "${ALL_PKGS[@]}"
    else
        info "Installing packages..."
        sudo apt install $APT_FLAGS "${ALL_PKGS[@]}"
    fi

    success "Install complete"
}

# ==================================================
# MAIN
# ==================================================

run() {

    load_packages

    [[ "$DO_CLEAN" -eq 1 ]] && clean_packages
    [[ "$DO_VERIFY" -eq 1 ]] && verify_packages
    [[ "$DO_LIST" -eq 1 ]] && list_packages
    [[ "$DO_INSTALL" -eq 1 ]] && install_packages

    if [[ "$DO_INSTALL" -eq 0 && "$DO_VERIFY" -eq 0 && "$DO_CLEAN" -eq 0 && "$DO_LIST" -eq 0 ]]; then
        warn "No action specified → defaulting to --install"
        install_packages
    fi

    success "Finished"
}

# ==================================================
# ENTRY
# ==================================================

main() {
    handle_help_flags "$@"
    parse_args "$@"
    run
}

main "$@"
