#!/usr/bin/env bash
# Script Name: convert_mp4_to_mp3_parallel.sh
# ID: SCR-ID-20260329043011-MF530MN74X
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: convert_mp4_to_mp3_parallel

convert_mp4_to_mp3_parallel() {
    local target_dir
    local cores

    # Ask for directory if not provided
    if [ -n "$1" ]; then
        target_dir="$1"
    else
        read -rp "Enter directory to convert mp4 to mp3 (default: current directory): " input_dir
        target_dir="${input_dir:-$(pwd)}"
    fi

    # Check if directory exists
    if [ ! -d "$target_dir" ]; then
        echo "Directory '$target_dir' does not exist."
        return 1
    fi

    # Detect number of CPU cores
    cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)

    echo "Using $cores cores for conversion..."

    # Export ffmpeg command to preserve context in xargs
    export -f ffmpeg

    # Find mp4 files and process them in parallel
    find "$target_dir" -type f -iname "*.mp4" | while IFS= read -r file; do
        dir=$(dirname "$file")
        base=$(basename "$file" .mp4)
        mp3_file="$dir/$base.mp3"

        # Skip if mp3 already exists
        if [ ! -f "$mp3_file" ]; then
            echo "$file"
        fi
    done | xargs -I {} -P "$cores" bash -c '
        file="{}"
        dir=$(dirname "$file")
        base=$(basename "$file" .mp4)
        mp3_file="$dir/$base.mp3"
        echo "Converting $file -> $mp3_file"
        ffmpeg -i "$file" -vn -ab 192k -ar 44100 -y "$mp3_file"
    '

    echo "All conversions completed."
}
