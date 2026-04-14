#!/usr/bin/env bash
# Script Name: heic2jpg.sh
# ID: SCR-ID-20260404034958-FPUNEX3D0L
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: heic2jpg

# HEIC → JPG Converter

CONFIG_LOG="/d/scr-pac/sample/logs/heic_to_jpg_config.log"
DEFAULT_SOURCE="/d/scr-pac/sample/logs/"

# Load config
[[ -f "$CONFIG_LOG" ]] && source "$CONFIG_LOG"

read -p "Source directory [$DEFAULT_SOURCE]: " SRC_DIR
SRC_DIR=${SRC_DIR:-$DEFAULT_SOURCE}

echo "SRC_DIR=\"$SRC_DIR\"" > "$CONFIG_LOG"

[[ ! -d "$SRC_DIR" ]] && echo "Invalid directory" && exit 1

FILES=$(find "$SRC_DIR" -type f -iname "*.heic")

[[ -z "$FILES" ]] && echo "No HEIC files found" && exit 0

for file in $FILES; do
    dir=$(dirname "$file")
    filename=$(basename "$file")
    name="${filename%.*}"
    output="$dir/${name}.jpg"

    # Skip if JPG already exists
    if [[ -f "$output" ]]; then
        echo "Skipping $file (exists)"
        continue
    fi

    echo "Converting $file -> $output"

    if heif-convert -q 90 "$file" "$output"; then
        echo "Success, deleting original: $file"
        rm -f "$file"
    else
        echo "Failed: $file"
    fi
done

echo "Done."
