#!/usr/bin/env bash
# Script Name: zscr0.sh
# ID: SCR-ID-20260412153046-SSGAY4GCSU
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: zscr0

# zip_and_spread.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
CONFIG="$LOG_DIR/dirs.conf"

mkdir -p "$LOG_DIR"

# =======================
# Default config
# =======================
if [[ ! -f "$CONFIG" ]]; then
cat <<EOF > "$CONFIG"
# kind name path enabled default
source main /mnt/c/scr 1 1
dest d /mnt/d/scr 1 0
dest e /mnt/e/scr 1 0
dest f /mnt/f/scr 1 0
EOF
echo "✅ Created default config: $CONFIG"
fi

# =======================
# Helpers
# =======================
timestamp() {
  date +"%m-%d-%Y"
}

archive_name() {
  echo "scr-$(timestamp).tar.gz"
}

next_name() {
  local dir="$1"
  local base="$2"

  if [[ ! -e "$dir/$base" ]]; then
    echo "$base"
    return
  fi

  local stem="${base%.tar.gz}"
  local i=0

  while true; do
    suffix=$(printf "%c" $((97 + i))) # a, b, c...
    new="${stem}${suffix}.tar.gz"
    [[ ! -e "$dir/$new" ]] && echo "$new" && return
    ((i++))
  done
}

# =======================
# Load config
# =======================
SOURCE=""
DESTS=()

while read -r kind name path enabled is_default; do
  [[ "$kind" =~ ^# ]] && continue
  [[ -z "$kind" ]] && continue

  if [[ "$kind" == "source" && "$enabled" == "1" && "$is_default" == "1" ]]; then
    SOURCE="$path"
  fi

  if [[ "$kind" == "dest" && "$enabled" == "1" ]]; then
    DESTS+=("$name|$path")
  fi
done < "$CONFIG"

if [[ -z "$SOURCE" ]]; then
  echo "❌ No source defined"
  exit 1
fi

ARCHIVE="$SOURCE/$(archive_name)"

# =======================
# Create archive
# =======================
echo "📦 Creating archive..."
tar -czf "$ARCHIVE" -C "$SOURCE" .
echo "✅ Created: $ARCHIVE"

# =======================
# Spread
# =======================
for entry in "${DESTS[@]}"; do
  name="${entry%%|*}"
  path="${entry##*|}"

  [[ ! -d "$path" ]] && continue

  swap="$path/swap"
  new="$path/new-archives"

  mkdir -p "$swap" "$new"

  # rotate old
  for file in "$swap"/*.tar.gz; do
    [[ -e "$file" ]] || continue
    base=$(basename "$file")
    newname=$(next_name "$new" "$base")
    mv "$file" "$new/$newname"
    echo "📦 $name: rotated $newname"
  done

  # copy new archive
  cp "$ARCHIVE" "$swap/"
  echo "➡️ $name: copied"
done

echo "✅ Done."
