rl
# =========================================================
# scrwork
# Find next script missing SCR-ID, generate SCR-ID block,
# copy block to clipboard, open chosen file in nano.
#
# Resolver-friendly standalone executable.
# =========================================================

set -u

SCRWORK_ROOT_DEFAULT="/mnt/c/scr"
SCRWORK_EXTS_DEFAULT="sh,zsh,bash,py,rb"
SCRWORK_CREATED_BY_DEFAULT="Tyler Jensen"
SCRWORK_EMAIL_DEFAULT="tylerjensen5@yahoo.com"
SCRWORK_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

# ---------------------------------------------------------
# helpers
# ---------------------------------------------------------

scrwork_err() {
  printf '❌ %s\n' "$*" >&2
}

scrwork_clip() {
  local text="$1"

  if command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$text" | clip.exe >/dev/null 2>&1
    return 0
  fi

  if [[ -x /mnt/c/Windows/System32/clip.exe ]]; then
    printf '%s' "$text" | /mnt/c/Windows/System32/clip.exe >/dev/null 2>&1
    return 0
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy >/dev/null 2>&1
    return 0
  fi

  if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$text" | xclip -selection clipboard >/dev/null 2>&1
    return 0
  fi

  return 1
}

scrwork_timestamp() {
  printf '%(%Y%m%d%H%M%S)T' -1
}

scrwork_rand() {
  local len="${1:-10}"
  local out=""
  local max=${#SCRWORK_ALPHABET}
  local idx

  while ((${#out} < len)); do
    idx=$((RANDOM % max))
    out+="${SCRWORK_ALPHABET:idx:1}"
  done

  printf '%s' "$out"
}

scrwork_generate_id() {
  local rand_len="${1:-10}"
  printf 'SCR-ID-%s-%s' "$(scrwork_timestamp)" "$(scrwork_rand "$rand_len")"
}

scrwork_lang_to_exts() {
  case "$1" in
    ruby)   printf 'rb' ;;
    python) printf 'py' ;;
    bash)   printf 'sh,bash' ;;
    zsh)    printf 'zsh' ;;
    shell)  printf 'sh,bash,zsh' ;;
    all)    printf 'sh,zsh,bash,py,rb' ;;
    *)
      return 1
      ;;
  esac
}

scrwork_build_block() {
  local scr_id="$1"
  local file_path="$2"
  local script_name alias_call

  script_name="${file_path##*/}"
  alias_call="${script_name%.*}"

  cat <<EOF
# Script Name: $script_name
# ID: $scr_id
# Assigned with:
# Created by: $SCRWORK_CREATED_BY_DEFAULT
# Email: $SCRWORK_EMAIL_DEFAULT
# Alias Call: $alias_call
EOF
}

# ---------------------------------------------------------
# NEW: shebang injector
# ---------------------------------------------------------

scrwork_apply_shebang() {
  local file="$1"
  local ext="${file##*.}"
  local shebang=""

  case "$ext" in
    rb)
      shebang="#!/usr/bin/env ruby"
      ;;
    py)
      shebang="#!/usr/bin/env python3"
      ;;
    bash|sh)
      shebang="#!/usr/bin/env bash"
      ;;
    zsh)
      shebang="#!/usr/bin/env zsh"
      ;;
    *)
      return 0
      ;;
  esac

  # ensure file exists
  [[ -f "$file" ]] || return 0

  # if first line already shebang → exit
  if head -n 1 "$file" 2>/dev/null | grep -q '^#!'; then
    return 0
  fi

  # safer overwrite method (avoids WSL pipe / race issues)
  {
    printf "%s\n" "$shebang"
    cat "$file"
  } | sponge "$file" 2>/dev/null || {
    # fallback if sponge not installed
    local tmp
    tmp="$(mktemp)"
    {
      printf "%s\n" "$shebang"
      cat "$file"
    } > "$tmp"
    mv "$tmp" "$file"
  }
}

scrwork_help() {
  cat <<'EOF'
scrwork - pick an untagged script, copy SCR-ID block, open in nano

Usage:
  scrwork [options] [name]

Options:
  -p, --path <dir>         search root path
  -t, --types <list>       comma-separated extensions
  -l, --lang <name>        ruby | python | bash | zsh | shell | all
  -n, --limit <num>        limit candidate list before selection
  -1, --first              auto-pick first match
  -i, --ignore-case        case-insensitive name filter
  --id-only                copy only SCR-ID instead of full block
  -r, --random-length <n>  SCR-ID random section length
  --no-clip                do not copy to clipboard
  --print-only             print selected file + block, do not open nano
  -h, --help               show help
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
  local query=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--path)
        root="$2"; shift 2 ;;
      -t|--types|--exts)
        exts="$2"; shift 2 ;;
      -l|--lang)
        exts="$(scrwork_lang_to_exts "$2")" || return 1
        shift 2 ;;
      -n|--limit)
        limit="$2"; shift 2 ;;
      -1|--first)
        first_only=1
        limit=1
        shift ;;
      -i|--ignore-case)
        ignore_case=1
        shift ;;
      --id-only)
        id_only=1
        shift ;;
      -r|--random-length)
        rand_len="$2"; shift 2 ;;
      --no-clip)
        no_clip=1
        shift ;;
      --print-only)
        print_only=1
        shift ;;
      -h|--help)
        scrwork_help
        return 0 ;;
      *)
        query="$1"
        shift ;;
    esac
  done

  [[ -d "$root" ]] || return 1

  local IFS=','
  local ext_arr=()
  read -r -a ext_arr <<< "$exts"

  local find_args=()
  find_args+=("$root" -type f "(")

  local first_ext=1
  local ext=""
  for ext in "${ext_arr[@]}"; do
    ext="${ext#.}"
    [[ -n "$ext" ]] || continue

    if [[ $first_ext -eq 1 ]]; then
      find_args+=(-iname "*.${ext}")
      first_ext=0
    else
      find_args+=(-o -iname "*.${ext}")
    fi
  done
  find_args+=(")")

  local matches=()
  local file name stem q count=0

  [[ $ignore_case -eq 1 ]] && q="${query,,}" || q="$query"

  while IFS= read -r file; do
    grep -q 'SCR-ID' "$file" 2>/dev/null && continue

    if [[ -n "$query" ]]; then
      name="${file##*/}"
      stem="${name%.*}"

      if [[ $ignore_case -eq 1 ]]; then
        [[ "${name,,}" == *"$q"* || "${stem,,}" == *"$q"* || "${file,,}" == *"$q"* ]] || continue
      else
        [[ "$name" == *"$q"* || "$stem" == *"$q"* || "$file" == *"$q"* ]] || continue
      fi
    fi

    matches+=("$file")
    ((count++))
    (( count >= limit )) && break
  done < <(/usr/bin/find "${find_args[@]}" 2>/dev/null | /usr/bin/sort)

  [[ ${#matches[@]} -eq 0 ]] && return 1

  local selected=""
  if [[ ${#matches[@]} -eq 1 || $first_only -eq 1 ]]; then
    selected="${matches[0]}"
  else
    printf 'Pick:\n'
    local i
    for i in "${!matches[@]}"; do
      printf '%d: %s\n' $((i + 1)) "${matches[$i]}"
    done

    read -r choice
    selected="${matches[$((choice - 1))]}"
  fi

  local scr_id payload
  scr_id="$(scrwork_generate_id "$rand_len")"

  payload="$scr_id"
  [[ $id_only -eq 0 ]] && payload="$(scrwork_build_block "$scr_id" "$selected")"

  printf '%s\n' "$payload"

  [[ $no_clip -eq 0 ]] && scrwork_clip "$payload"

  [[ $print_only -eq 1 ]] && return 0

  # NEW BEHAVIOR
  scrwork_apply_shebang "$selected"

  nano "$selected"
}

main "$@"
