#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------
# README.txt CREATOR
# ---------------------------------------------
# original directories

#ROOT="/mnt/c/scr"
#TEMPLATE="$ROOT/readme-template.txt"

# ---------------------------------------------
# given directories

ROOT="/mnt/c/scr/aliases/swap"
TEMPLATE="$ROOT/readme-template.txt"



TARGET_DIR="${1:-$(pwd)}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory does not exist: $TARGET_DIR"
    exit 1
fi

README="$TARGET_DIR/README.txt"

if [ -f "$README" ]; then
    echo "README already exists: $README"
    read -p "Overwrite? (y/N): " ans
    [[ "$ans" != "y" ]] && exit 0
fi

PROJECT_NAME="$(basename "$TARGET_DIR")"
FULL_PATH="$(realpath "$TARGET_DIR")"
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"

sed \
-e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
-e "s|__FULL_PATH__|$FULL_PATH|g" \
-e "s|__DATE__|$DATE_NOW|g" \
"$TEMPLATE" > "$README"

echo "Created: $README"

nano "$README"
