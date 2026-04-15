#!/usr/bin/env bash

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
# ENVIRONMENT DETECTION
# ==================================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            echo "$ID"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

detect_arch() {
    uname -m
}

detect_env() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        echo "wsl"
    elif [[ -n "${TERMUX_VERSION:-}" ]]; then
        echo "termux"
    elif [[ -d /mnt/c ]]; then
        echo "wsl"
    else
        echo "native"
    fi
}

detect_wsl() {
    # Check for WSL environment variables
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        # WSL_DISTRO_NAME exists in both WSL1 and WSL2
        echo "wsl"
    elif [[ -n "${WSLENV:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]]; then
        # WSLENV/WSL_INTEROP indicate WSL2 interop
        echo "wsl2"
    elif [[ -d /mnt/c ]] && [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        echo "wsl"
    else
        echo "false"
    fi
}

detect_wsl_distro() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        echo "$WSL_DISTRO_NAME"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        echo "unknown"
    fi
}


# ==================================================
# SCR ENVIRONMENT CORE (UNIFIED VIEW)
# ==================================================

scr_env() {
    # Cache the result
    if [[ -z "${_SCR_ENV:-}" ]]; then
        declare -A env

        # OS detection
        case "$OSTYPE" in
            linux-gnu*)
                env[os]="linux"
                if [[ -f /etc/os-release ]]; then
                    . /etc/os-release
                    env[distro]="$ID"
                fi
                ;;
            darwin*)
                env[os]="macos"
                ;;
            msys|win32)
                env[os]="windows"
                ;;
            *)
                env[os]="unknown"
                ;;
        esac

        # Architecture
        env[arch]="$(uname -m)"

        # WSL detection
        env[wsl]="false"
        if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSLENV:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]]; then
            env[wsl]="true"
        elif [[ -d /mnt/c ]] && [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
            env[wsl]="true"
        fi

        # Mode
        if [[ "${env[wsl]}" == "true" ]]; then
            env[mode]="wsl"
        else
            env[mode]="${env[os]}"
        fi

        # Serialize for caching
        _SCR_ENV="${env[os]}|${env[arch]}|${env[distro]:-}|${env[wsl]}|${env[mode]}"
    fi

    # Return associative array (bash 4.0+)
    echo "$_SCR_ENV"
}


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