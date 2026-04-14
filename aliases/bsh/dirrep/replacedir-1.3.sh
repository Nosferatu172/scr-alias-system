#!/usr/bin/env bash
# Script Name: replacedir-1.3.sh
# ID: SCR-ID-20260329042826-VBZMEJQVKZ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: replacedir-1.3

# Usage: replace-mnt.sh [-n] <from_drive> <to_drive> [directory]
# -n : dry run (preview changes)
# Example: replace-mnt.sh -n d c ~/projects/scr

DRYRUN=0

# Check for -n
if [ "$1" == "-n" ]; then
    DRYRUN=1
    shift
fi

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 [-n] <from_drive> <to_drive> [directory]"
    exit 1
fi

FROM="$1"
TO="$2"
DIR="${3:-.}"   # default to current dir if not given

grep -rl "/mnt/$FROM/" "$DIR" | while read -r file; do
    echo "File: $file"
    if [ $DRYRUN -eq 1 ]; then
        # Highlight only the /mnt/d/ part in color
        grep -n "/mnt/$FROM/" "$file" | sed "s|/mnt/$FROM/|$(tput setaf 3)&$(tput sgr0)|g"
    else
        sed -i "s|/mnt/$FROM/|/mnt/$TO/|g" "$file"
        echo "Updated: $file"
    fi
done
