# =========================================================
# idtodo
# Find script files missing an SCR-ID
# Standalone executable for resolver-based setup
# =========================================================

set -u

IDTODO_ROOT_DEFAULT="/mnt/c/scr"
IDTODO_EXTS_DEFAULT="sh,zsh,bash,py,rb"

idtodo_err() {
  printf '❌ %s\n' "$*" >&2
}

idtodo_help() {
  cat <<'EOF'
idtodo - find script files missing an SCR-ID

Usage:
  idtodo [options]

Options:
  -p, --path <dir>         search root path
  -t, --types <list>       comma-separated extensions (example: sh,zsh,py,rb)
  -l, --lang <name>        preset language filter:
                           ruby | python | bash | zsh | shell | all
  -n, --limit <num>        limit number of results
  -1, --first              same as --limit 1
  --paths-only             print only full paths
  --names-only             print only filenames
  --basename-only          print filename without extension
  --no-clip                do not copy output to clipboard
  -h, --help               show help

Examples:
  idtodo
  idtodo --paths-only
  idtodo --names-only
  idtodo -n 10
  idtodo -1 --paths-only
  idtodo -l ruby
  idtodo -l python --paths-only
  idtodo -l bash --names-only
  idtodo -t "rb"
EOF
}

idtodo_clip() {
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

idtodo_lang_to_exts() {
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

main() {
  local root="$IDTODO_ROOT_DEFAULT"
  local exts="$IDTODO_EXTS_DEFAULT"
  local limit=0
  local paths_only=0
  local names_only=0
  local basename_only=0
  local no_clip=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--path)
        [[ $# -ge 2 ]] || { idtodo_err "Missing value for $1"; return 1; }
        root="$2"
        shift 2
        ;;
      -t|--types|--exts)
        [[ $# -ge 2 ]] || { idtodo_err "Missing value for $1"; return 1; }
        exts="$2"
        shift 2
        ;;
      -l|--lang)
        [[ $# -ge 2 ]] || { idtodo_err "Missing value for $1"; return 1; }
        exts="$(idtodo_lang_to_exts "$2")" || {
          idtodo_err "Unknown language: $2"
          return 1
        }
        shift 2
        ;;
      -n|--limit)
        [[ $# -ge 2 ]] || { idtodo_err "Missing value for $1"; return 1; }
        limit="$2"
        shift 2
        ;;
      -1|--first)
        limit=1
        shift
        ;;
      --paths-only)
        paths_only=1
        shift
        ;;
      --names-only)
        names_only=1
        shift
        ;;
      --basename-only)
        basename_only=1
        shift
        ;;
      --no-clip)
        no_clip=1
        shift
        ;;
      -h|--help)
        idtodo_help
        return 0
        ;;
      *)
        idtodo_err "Unknown arg: $1"
        return 1
        ;;
    esac
  done

  [[ -d "$root" ]] || { idtodo_err "Search path does not exist: $root"; return 1; }
  [[ "$limit" =~ ^[0-9]+$ ]] || { idtodo_err "--limit must be an integer"; return 1; }

  local mode_count=0
  (( paths_only )) && ((mode_count+=1))
  (( names_only )) && ((mode_count+=1))
  (( basename_only )) && ((mode_count+=1))

  if (( mode_count > 1 )); then
    idtodo_err "Use only one of: --paths-only, --names-only, --basename-only"
    return 1
  fi

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

  local results=()
  local file name base out
  local count=0

  while IFS= read -r file; do
    if /bin/grep -q 'SCR-ID' "$file" 2>/dev/null; then
      continue
    fi

    name="${file##*/}"
    base="${name%.*}"

    if (( basename_only )); then
      results+=("$base")
    elif (( names_only )); then
      results+=("$name")
    elif (( paths_only )); then
      results+=("$file")
    else
      results+=("$name :: $file")
    fi

    ((count+=1))
    if (( limit > 0 && count >= limit )); then
      break
    fi
  done < <(/usr/bin/find "${find_args[@]}" 2>/dev/null | /usr/bin/sort)

  if [[ ${#results[@]} -eq 0 ]]; then
    out="✅ No scripts missing SCR-ID under: $root"
    printf '%s\n' "$out"
    if [[ $no_clip -eq 0 ]]; then
      idtodo_clip "$out" || true
    fi
    return 0
  fi

  out=""
  local line
  for line in "${results[@]}"; do
    if [[ -n "$out" ]]; then
      out+=$'\n'
    fi
    out+="$line"
  done

  printf '%s\n' "$out"

  if [[ $no_clip -eq 0 ]]; then
    idtodo_clip "$out" || true
  fi
}

main "$@"
