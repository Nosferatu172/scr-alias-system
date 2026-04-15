# =========================================================
# scrwork
# Auto-tag scripts with SCR-ID (single or batch mode)
# =========================================================

set -u

SCRWORK_ROOT_DEFAULT="/mnt/c/scr"
SCRWORK_EXTS_DEFAULT="sh,zsh,bash,py,rb"
SCRWORK_CREATED_BY_DEFAULT="Tyler Jensen"
SCRWORK_EMAIL_DEFAULT="tylerjensen5@yahoo.com"
SCRWORK_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

# 🚫 EXCLUDED PATHS
SCRWORK_EXCLUDES=(
  "/mnt/c/scr/aliases/lib"
  "/mnt/c/scr/core/"
)

# ---------------------------------------------------------
# helpers
# ---------------------------------------------------------

scrwork_err() { printf '❌ %s\n' "$*" >&2; }

scrwork_clip() {
  local text="$1"

  command -v clip.exe >/dev/null && { printf '%s' "$text" | clip.exe; return; }
  [[ -x /mnt/c/Windows/System32/clip.exe ]] && { printf '%s' "$text" | /mnt/c/Windows/System32/clip.exe; return; }
  command -v wl-copy >/dev/null && { printf '%s' "$text" | wl-copy; return; }
  command -v xclip >/dev/null && { printf '%s' "$text" | xclip -selection clipboard; return; }

  return 1
}

scrwork_timestamp() { printf '%(%Y%m%d%H%M%S)T' -1; }

# ✅ NEW: pretty timestamp
scrwork_pretty_date() {
  printf '%(%Y_%m_%d_%H_%M_%S)T' -1
}

scrwork_rand() {
  local len="${1:-10}" out="" max=${#SCRWORK_ALPHABET}
  while ((${#out} < len)); do
    out+="${SCRWORK_ALPHABET:RANDOM%max:1}"
  done
  printf '%s' "$out"
}

scrwork_generate_id() {
  printf 'SCR-ID-%s-%s' "$(scrwork_timestamp)" "$(scrwork_rand "$1")"
}

scrwork_lang_to_exts() {
  case "$1" in
    ruby) echo 'rb' ;;
    python) echo 'py' ;;
    bash) echo 'sh,bash' ;;
    zsh) echo 'zsh' ;;
    shell) echo 'sh,bash,zsh' ;;
    all) echo 'sh,zsh,bash,py,rb' ;;
    *) return 1 ;;
  esac
}

scrwork_build_block() {
  local id="$1" file="$2"
  local name="${file##*/}"
  local alias="${name%.*}"
  local created
  created="$(scrwork_pretty_date)"

cat <<EOF
# Script Name: $name
# ID: $id
# Created: $created
# Assigned with:
# Created by: $SCRWORK_CREATED_BY_DEFAULT
# Email: $SCRWORK_EMAIL_DEFAULT
# Alias Call: $alias
EOF
}

# ---------------------------------------------------------
# APPLY SHEBANG
# ---------------------------------------------------------

scrwork_apply_shebang() {
  local file="$1" ext="${file##*.}" shebang=""

  case "$ext" in
    rb) shebang="#!/usr/bin/env ruby" ;;
    py) shebang="#!/usr/bin/env python3" ;;
    sh|bash) shebang="#!/usr/bin/env bash" ;;
    zsh) shebang="#!/usr/bin/env zsh" ;;
    *) return ;;
  esac

  [[ -f "$file" ]] || return

  head -n 1 "$file" | grep -q '^#!' && return

  tmp="$(mktemp)"
  { printf "%s\n" "$shebang"; cat "$file"; } > "$tmp"
  mv "$tmp" "$file"
}

# ---------------------------------------------------------
# APPLY HEADER
# ---------------------------------------------------------

scrwork_apply_header() {
  local file="$1" block="$2"

  grep -q 'SCR-ID' "$file" && return

  tmp="$(mktemp)"

  if head -n 1 "$file" | grep -q '^#!'; then
    {
      head -n 1 "$file"
      echo
      echo "$block"
      echo
      tail -n +2 "$file"
    } > "$tmp"
  else
    {
      echo "$block"
      echo
      cat "$file"
    } > "$tmp"
  fi

  mv "$tmp" "$file"
}

# ---------------------------------------------------------
# HELP
# ---------------------------------------------------------

scrwork_help() {
cat <<'EOF'
scrwork - auto apply SCR-ID headers

Usage:
  scrwork [options] [query]

Options:
  -p, --path <dir>
  -t, --types <list>
  -l, --lang <name>
  -n, --limit <num>
  -1, --first
  -i, --ignore-case
  --id-only
  -r, --random-length <n>
  --no-clip
  --print-only
  --all               apply to ALL matches (batch mode)
  -h, --help
EOF
}

# ---------------------------------------------------------
# main
# ---------------------------------------------------------

main() {
  local root="$SCRWORK_ROOT_DEFAULT"
  local exts="$SCRWORK_EXTS_DEFAULT"
  local limit=25
  local first_only=0
  local ignore_case=0
  local id_only=0
  local no_clip=0
  local print_only=0
  local rand_len=10
  local all_mode=0
  local query=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--path) root="$2"; shift 2 ;;
      -t|--types|--exts) exts="$2"; shift 2 ;;
      -l|--lang) exts="$(scrwork_lang_to_exts "$2")" || return 1; shift 2 ;;
      -n|--limit) limit="$2"; shift 2 ;;
      -1|--first) first_only=1; limit=1; shift ;;
      -i|--ignore-case) ignore_case=1; shift ;;
      --id-only) id_only=1; shift ;;
      -r|--random-length) rand_len="$2"; shift 2 ;;
      --no-clip) no_clip=1; shift ;;
      --print-only) print_only=1; shift ;;
      --all) all_mode=1; shift ;;
      -h|--help) scrwork_help; return 0 ;;
      *) query="$1"; shift ;;
    esac
  done

  [[ -d "$root" ]] || return 1

  IFS=',' read -r -a ext_arr <<< "$exts"

  find_cmd=(/usr/bin/find "$root")

  for ex in "${SCRWORK_EXCLUDES[@]}"; do
    find_cmd+=( -path "$ex" -prune -o )
  done

  find_cmd+=( -type f "(" )

  first_ext=1
  for ext in "${ext_arr[@]}"; do
    ext="${ext#.}"
    [[ $first_ext -eq 1 ]] && {
      find_cmd+=( -iname "*.${ext}" )
      first_ext=0
    } || find_cmd+=( -o -iname "*.${ext}" )
  done

  find_cmd+=( ")" -print )

  mapfile -t files < <("${find_cmd[@]}" 2>/dev/null | sort)

  matches=()

  for file in "${files[@]}"; do
    grep -q 'SCR-ID' "$file" && continue

    if [[ -n "$query" ]]; then
      name="${file##*/}"
      [[ "$name" == *"$query"* || "$file" == *"$query"* ]] || continue
    fi

    matches+=("$file")
    [[ $all_mode -eq 0 && ${#matches[@]} -ge $limit ]] && break
  done

  [[ ${#matches[@]} -eq 0 ]] && return 1

  if [[ $all_mode -eq 1 ]]; then
    for file in "${matches[@]}"; do
      id="$(scrwork_generate_id "$rand_len")"
      block="$(scrwork_build_block "$id" "$file")"

      [[ $no_clip -eq 0 ]] && scrwork_clip "$block"

      scrwork_apply_shebang "$file"
      [[ $id_only -eq 0 ]] && scrwork_apply_header "$file" "$block"

      printf '✅ %s\n' "$file"
    done
    return 0
  fi

  selected="${matches[0]}"

  id="$(scrwork_generate_id "$rand_len")"
  payload="$id"
  [[ $id_only -eq 0 ]] && payload="$(scrwork_build_block "$id" "$selected")"

  printf '%s\n' "$payload"

  [[ $no_clip -eq 0 ]] && scrwork_clip "$payload"
  [[ $print_only -eq 1 ]] && return 0

  scrwork_apply_shebang "$selected"
  [[ $id_only -eq 0 ]] && scrwork_apply_header "$selected" "$payload"

  printf '✅ Applied: %s\n' "$selected"
}

main "$@"