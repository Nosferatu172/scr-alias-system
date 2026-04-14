#!/usr/bin/env bash
# Script Name: webp2mp4conv.sh
# ID: SCR-ID-20260404035010-CPP3IQLSYV
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: webp2mp4conv

# Script Name: webp2mp4conv-1.0.sh

CONFIG_LOG="/d/scr-pac/sample/logs/webp_to_mp4_config.log"
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

# Find all .webp files recursively
FILES=$(find "$SRC_DIR" -type f -iname "*.webp")

if [[ -z "$FILES" ]]; then
    echo "No WEBP files found in $SRC_DIR"
    exit 0
fi

# Loop and convert
for file in $FILES; do
    dir=$(dirname "$file")
    filename=$(basename "$file")
    name="${filename%.*}"
    output="$dir/${name}.mp4"

    # Skip if mp4 already exists
    if [[ -f "$output" ]]; then
        echo "Skipping $file (output already exists: $output)"
        continue
    fi

    echo "Converting $file -> $output"

    # Convert WEBP (animated or static) to MP4
    if ffmpeg -y -i "$file" \
        -movflags faststart \
        -pix_fmt yuv420p \
        -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        -c:v libx264 -preset fast -crf 23 \
        "$output"; then

        echo "Conversion successful, deleting original: $file"
        rm -f "$file"
    else
        echo "Conversion failed for: $file (keeping original)"
    fi
done

echo "All conversions complete! Originals deleted after successful conversion."
