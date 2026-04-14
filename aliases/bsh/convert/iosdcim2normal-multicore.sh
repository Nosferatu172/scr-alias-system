#!/usr/bin/env bash
# Script Name: iosdcim2normal-multicore.sh
# ID: SCR-ID-20260329043023-0166GXFEV3
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: iosdcim2normal-multicore

# Default source directory
CONFIG_LOG="/d/scr-pac/sample/logs/mov_to_mp4_config.log"
DEFAULT_SOURCE="/d/scr-pac/sample/logs/"

# Load previous source if config exists
if [[ -f "$CONFIG_LOG" ]]; then
    source "$CONFIG_LOG"
fi

# Ask for source directory
read -p "Source directory [$DEFAULT_SOURCE]: " SRC_DIR
SRC_DIR=${SRC_DIR:-$DEFAULT_SOURCE}

# Save to config for next run
echo "SRC_DIR=\"$SRC_DIR\"" > "$CONFIG_LOG"

# Check if directory exists
if [[ ! -d "$SRC_DIR" ]]; then
    echo "Source directory does not exist: $SRC_DIR"
    exit 1
fi

# Ensure GNU parallel is installed
if ! command -v parallel &>/dev/null; then
    echo "GNU parallel is not installed. Please install it first."
    exit 1
fi

# Find all MOV, HEIC, HEIF files recursively
FILES=$(find "$SRC_DIR" -type f \( -iname "*.mov" -o -iname "*.heic" -o -iname "*.heif" \))

if [[ -z "$FILES" ]]; then
    echo "No MOV, HEIC, or HEIF files found in $SRC_DIR"
    exit 0
fi

# Function to process a single file
convert_file() {
    file="$1"
    dir=$(dirname "$file")
    filename=$(basename "$file")
    name="${filename%.*}"
    ext="${filename##*.}"

    case "${ext,,}" in
        mov)
            output="$dir/${name}.mp4"
            if [[ -f "$output" ]]; then
                echo "Skipping $file (output exists)"
                return
            fi
            echo "Converting video $file -> $output"
            if ffmpeg -i "$file" -c:v libx264 -preset fast -crf 23 -c:a aac "$output"; then
                echo "Conversion successful, deleting original: $file"
                rm -f "$file"
            else
                echo "Conversion failed for: $file"
            fi
            ;;
        heic|heif)
            output="$dir/${name}.jpg"
            if [[ -f "$output" ]]; then
                echo "Skipping $file (output exists)"
                return
            fi
            echo "Converting image $file -> $output"
            if ffmpeg -i "$file" "$output"; then
                echo "Conversion successful, deleting original: $file"
                rm -f "$file"
            else
                echo "Conversion failed for: $file"
            fi
            ;;
    esac
}

export -f convert_file

# Run conversions in parallel, using all CPU cores
echo "$FILES" | parallel -j 0 convert_file {}

echo "All conversions complete! Originals deleted after successful conversion."
