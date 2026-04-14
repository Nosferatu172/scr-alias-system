#!/usr/bin/env bash
# Script Name: mp4tomp3.sh
# ID: SCR-ID-20260317130405-7WBVF95H90
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: mp4tomp3

# mp4tomp3.sh - Convert all MP4 files (recursively) to MP3, preserving folder structure.
# After successful conversion, original MP4s are deleted.
# If GNU parallel is installed, it will be used for faster conversion.

set -euo pipefail

# --- Functions ---

convert_file() {
    local file="$1"
    local dir base mp3_file

    dir=$(dirname "$file")
    base=$(basename "$file" .mp4)
    mp3_file="$dir/$base.mp3"

    if [[ -f "$mp3_file" ]]; then
        echo "Skipping existing: $mp3_file"
    else
        echo "Converting: $file -> $mp3_file"
        if ffmpeg -i "$file" -vn -ab 192k -ar 44100 -y "$mp3_file"; then
            echo "✅ Conversion successful, deleting: $file"
            rm -f "$file"
        else
            echo "❌ Conversion failed, keeping: $file"
        fi
    fi
}

export -f convert_file

# --- Main ---

target_dir="${1:-$(pwd)}"

if [[ ! -d "$target_dir" ]]; then
    echo "Error: Directory '$target_dir' does not exist."
    exit 1
fi

echo "Searching for .mp4 files under: $target_dir"

# If GNU parallel is installed, use it
if command -v parallel >/dev/null 2>&1; then
    echo "GNU parallel detected -> running in parallel mode."
    find "$target_dir" -type f -iname "*.mp4" \
        | parallel --bar -j0 convert_file {}
else
    echo "GNU parallel not found -> running sequentially."
    find "$target_dir" -type f -iname "*.mp4" -exec bash -c 'convert_file "$0"' {} \;
fi

echo "✅ All conversions completed."
