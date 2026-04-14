#!/usr/bin/env bash
# Script Name: mov2mp4conv.sh
# ID: SCR-ID-20260329042814-5S5RJPETOL
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mov2mp4conv

# Default source directory
CONFIG_LOG="/d/scr-pac/sample/logs/mov_to_mp4_config.log"
DEFAULT_SOURCE="/d/scr-pac/sample/logs/"

# Load previous source/output if config exists
if [[ -f "$CONFIG_LOG" ]]; then
    source "$CONFIG_LOG"
fi

# Ask for source directory
read -p "Source directory [$DEFAULT_SOURCE]: " SRC_DIR
SRC_DIR=${SRC_DIR:-$DEFAULT_SOURCE}

# Ask for output directory
read -p "Output directory [same as source]: " OUT_DIR
OUT_DIR=${OUT_DIR:-$SRC_DIR}

# Save to config for next run
echo "SRC_DIR=\"$SRC_DIR\"" > "$CONFIG_LOG"
echo "OUT_DIR=\"$OUT_DIR\"" >> "$CONFIG_LOG"

# Check if directories exist
if [[ ! -d "$SRC_DIR" ]]; then
    echo "Source directory does not exist: $SRC_DIR"
    exit 1
fi
mkdir -p "$OUT_DIR"

# Find all .MOV and .mov files
FILES=$(find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.mov" \))

if [[ -z "$FILES" ]]; then
    echo "No MOV files found in $SRC_DIR"
    exit 0
fi

# Loop and convert
for file in $FILES; do
    filename=$(basename "$file")
    name="${filename%.*}"
    output="$OUT_DIR/${name}.mp4"

    echo "Converting $filename -> ${name}.mp4"
    ffmpeg -i "$file" -c:v libx264 -preset fast -crf 23 -c:a aac "$output"
done

echo "All conversions complete! Output saved to $OUT_DIR"
