#!/usr/bin/env bash

# =========================================================
# scr audit
# Analyze SCR scripts for issues (IDs, shebangs, duplicates)
# =========================================================

set -u

ROOT="/mnt/c/scr"
EXTS="sh,zsh,bash,py,rb"

EXCLUDES=(
  "/mnt/c/scr/aliases/lib"
  "/mnt/c/scr/core/"
)

# ---------------------------------------------------------
# counters
# ---------------------------------------------------------

missing_id=0
missing_shebang=0
duplicates=0
total=0

declare -A id_map

# ---------------------------------------------------------
# utils
# ---------------------------------------------------------

info() { printf '🔎 %s\n' "$*"; }
warn() { printf '⚠️ %s\n' "$*"; }
err()  { printf '❌ %s\n' "$*"; }

# ---------------------------------------------------------
# build find
# ---------------------------------------------------------

IFS=',' read -r -a ext_arr <<< "$EXTS"

find_cmd=(/usr/bin/find "$ROOT")

for ex in "${EXCLUDES[@]}"; do
  find_cmd+=( -path "$ex" -prune -o )
done

find_cmd+=( -type f "(" )

first=1
for ext in "${ext_arr[@]}"; do
  ext="${ext#.}"
  if [[ $first -eq 1 ]]; then
    find_cmd+=( -iname "*.${ext}" )
    first=0
  else
    find_cmd+=( -o -iname "*.${ext}" )
  fi
done

find_cmd+=( ")" -print )

mapfile -t files < <("${find_cmd[@]}" 2>/dev/null | sort)

# ---------------------------------------------------------
# scan
# ---------------------------------------------------------

info "Scanning ${#files[@]} files..."

for file in "${files[@]}"; do
  ((total++))

  # -------------------------
  # SCR-ID check
  # -------------------------

  id="$(grep -m1 'SCR-ID' "$file" 2>/dev/null | sed -E 's/.*(SCR-ID-[^ ]+).*/\1/')"

  if [[ -z "$id" ]]; then
    ((missing_id++))
    warn "Missing ID: $file"
  else
    if [[ -n "${id_map[$id]:-}" ]]; then
      ((duplicates++))
      err "Duplicate ID: $id"
      printf '   ↳ %s\n' "$file"
      printf '   ↳ %s\n' "${id_map[$id]}"
    else
      id_map["$id"]="$file"
    fi
  fi

  # -------------------------
  # shebang check
  # -------------------------

  if ! head -n 1 "$file" | grep -q '^#!'; then
    ((missing_shebang++))
    warn "Missing shebang: $file"
  fi

done

# ---------------------------------------------------------
# summary
# ---------------------------------------------------------

echo
printf '========== SCR AUDIT ==========\n'
printf 'Total files:        %d\n' "$total"
printf 'Missing SCR-ID:     %d\n' "$missing_id"
printf 'Missing shebang:    %d\n' "$missing_shebang"
printf 'Duplicate IDs:      %d\n' "$duplicates"

# ---------------------------------------------------------
# exit status
# ---------------------------------------------------------

((missing_id > 0 || missing_shebang > 0 || duplicates > 0)) && exit 1
exit 0
