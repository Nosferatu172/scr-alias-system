#!/usr/bin/env bash

# ============================================
# Script Name: __SCRIPT_NAME__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
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
# HELP SYSTEM (MULTI ENTRY SUPPORT)
# ==================================================

show_help() {
cat <<EOF

$SCRIPT_NAME

Usage:
  bash $SCRIPT_NAME [options]

Help:
  -h, --h, --help, help     Show this help

Options:
  -v, --verbose             Verbose output
  --debug                  Debug mode
  -q, --quiet              Minimal output

EOF
exit 0
}


handle_help_flags() {
    for arg in "$@"; do
        case "$arg" in
            -h|--h|--help|help)
                show_help
                ;;
        esac
    done
}


# ==================================================
# ENV HOOK SYSTEM (VPY INTEGRATION)
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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                ;;
            --debug)
                DEBUG=1
                ;;
            -q|--quiet)
                QUIET=1
                ;;
            *)
                ;;
        esac
        shift
    done
}


# ==================================================
# MAIN LOGIC
# ==================================================

run() {

    [[ "$VERBOSE" -eq 1 ]] && info "Running $SCRIPT_NAME"
    [[ "$VERBOSE" -eq 1 ]] && info "Directory: $SCRIPT_DIR"

    [[ "$DEBUG" -eq 1 ]] && warn "Debug mode enabled"

    # -----------------------------
    # YOUR LOGIC HERE
    # -----------------------------

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

    exit 0
}


main "$@"