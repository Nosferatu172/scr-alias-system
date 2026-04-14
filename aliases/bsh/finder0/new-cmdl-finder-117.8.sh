#!/usr/bin/env bash
# Script Name: new-cmdl-finder-117.8.sh
# ID: SCR-ID-20260329042839-LMWBXL1HRB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: new-cmdl-finder-117.8

# find — search files recursively in default directory or custom path, copy selection to Windows clipboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.find_config"
CLIP="/c/Windows/System32/clip.exe"

# Load default directory
DEFAULT_DIR="."
[ -f "$CONFIG_FILE" ] && DEFAULT_DIR=$(cat "$CONFIG_FILE")

show_help() {
    cat << EOF
Usage:
  find <filename>           # Search in default directory ($DEFAULT_DIR)
  find <path> <filename>    # Search in a custom path
  find -e <directory>       # Set default search directory
  find -d                   # Display current default directory
  find -h                   # Show this help

Examples:
  find main.rb
  find /mnt/c/scr/ finder.sh
  find -e /d/projects
  find -d
EOF
}

# Handle help
[ "$1" == "-h" ] && show_help && exit 0

# Display current default directory
if [ "$1" == "-d" ]; then
    echo "Current default directory: $DEFAULT_DIR"
    exit 0
fi

# Edit default directory
if [ "$1" == "-e" ]; then
    [ -z "$2" ] && echo "Please provide a directory" && exit 1
    echo "$2" > "$CONFIG_FILE"
    echo "Default directory set to: $2"
    exit 0
fi

# Determine search path and filename
if [ -z "$1" ]; then
    echo "No filename provided. Use -h for help."
    exit 1
fi

if [ -f "$1" ] || [ -d "$1" ] || [[ "$1" == /mnt/* ]]; then
    # First argument is a path
    SEARCH_DIR="$1"
    shift
    [ -z "$1" ] && echo "No filename provided after path" && exit 1
    FILENAME="$1"
else
    # First argument is filename, use default directory
    SEARCH_DIR="$DEFAULT_DIR"
    FILENAME="$1"
fi

# Find matching files
mapfile -t RESULTS < <(find "$SEARCH_DIR" -type f -name "$FILENAME" 2>/dev/null)

if [ "${#RESULTS[@]}" -eq 0 ]; then
    echo "No files found matching '$FILENAME' in $SEARCH_DIR"
    exit 0
fi

# Single result → copy
if [ "${#RESULTS[@]}" -eq 1 ]; then
    echo "${RESULTS[0]}"
    echo -n "${RESULTS[0]}" | "$CLIP"
    echo "Copied to clipboard!"
else
    # Multiple results → select
    echo "Found multiple results:"
    for i in "${!RESULTS[@]}"; do
        printf "%d: %s\n" $((i+1)) "${RESULTS[$i]}"
    done

    read -p "Enter number(s) to copy (comma-separated) or 'a' for all: " CHOICE

    if [ "$CHOICE" == "a" ]; then
        printf "%s\n" "${RESULTS[@]}" | "$CLIP"
        echo "All results copied to clipboard!"
    else
        SELECTED=()
        IFS=',' read -ra NUMS <<< "$CHOICE"
        for n in "${NUMS[@]}"; do
            idx=$((n-1))
            [ "$idx" -ge 0 ] && [ "$idx" -lt "${#RESULTS[@]}" ] && SELECTED+=("${RESULTS[$idx]}")
        done
        printf "%s\n" "${SELECTED[@]}" | "$CLIP"
        echo "Selected results copied to clipboard!"
    fi
fi
