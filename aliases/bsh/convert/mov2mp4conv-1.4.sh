#!/usr/bin/env bash
# Script Name: mov2mp4conv-1.4.sh
# ID: SCR-ID-20260329042808-KGV5IXIE4O
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mov2mp4conv-1.4

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

# Find all .MOV and .mov files recursively
FILES=$(find "$SRC_DIR" -type f \( -iname "*.mov" \))

if [[ -z "$FILES" ]]; then
    echo "No MOV files found in $SRC_DIR"
    exit 0
fi

# Loop and convert
for file in $FILES; do
    dir=$(dirname "$file")       # folder of the current file
    filename=$(basename "$file") # full filename
    name="${filename%.*}"        # name without extension
    output="$dir/${name}.mp4"    # keep in same folder

    # Skip if mp4 already exists
    if [[ -f "$output" ]]; then
        echo "Skipping $file (output already exists: $output)"
        continue
    fi

    echo "Converting $file -> $output"
    if ffmpeg -i "$file" -c:v libx264 -preset fast -crf 23 -c:a aac "$output"; then
        echo "Conversion successful, deleting original: $file"
        rm -f "$file"
    else
        echo "Conversion failed for: $file (keeping original)"
    fi
done

echo "All conversions complete! Originals deleted after successful conversion."

