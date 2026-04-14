# =========================================================
# scrid
# Standalone SCR-ID generator
# Safe against resolver/path alias interference
# =========================================================

set -u

SCRID_CREATED_BY_DEFAULT="Tyler Jensen"
SCRID_EMAIL_DEFAULT="tylerjensen5@yahoo.com"
SCRID_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

scrid_err() {
  printf '❌ %s\n' "$*" >&2
}

scrid_timestamp() {
  printf '%(%Y%m%d%H%M%S)T' -1
}

scrid_rand() {
  local len="${1:-10}"
  local out=""
  local max=${#SCRID_ALPHABET}
  local idx

  while ((${#out} < len)); do
    idx=$((RANDOM % max))
    out+="${SCRID_ALPHABET:idx:1}"
  done

  printf '%s' "$out"
}

scrid_generate() {
  local rand_len="${1:-10}"
  printf 'SCR-ID-%s-%s' "$(scrid_timestamp)" "$(scrid_rand "$rand_len")"
}

scrid_clip() {
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

show_help() {
  cat <<'EOF'
scrid - generate SCR-ID headers

Usage:
  scrid [options]

Options:
  -n, --number N              number of IDs/templates to generate
  -r, --random-length N       random section length (default: 10)
  --script-name NAME          fill in Script Name
  --assigned-with TEXT        fill in Assigned with
  --created-by NAME           fill in Created by
  --email EMAIL               fill in Email
  --assigned-script-id ID     fill in Assigned Script ID
  --alias-call NAME           fill in Alias Call
  --id-only                   output only the SCR-ID
  --no-clip                   do not copy to clipboard
  -h, --help                  show this help

Examples:
  scrid
  scrid --id-only
  scrid -n 3
  scrid --script-name vpy --alias-call vpy
EOF
}

main() {
  local number=1
  local rand_len=10
  local script_name=""
  local assigned_with=""
  local created_by="$SCRID_CREATED_BY_DEFAULT"
  local email="$SCRID_EMAIL_DEFAULT"
  local assigned_script_id=""
  local alias_call=""
  local id_only=0
  local no_clip=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--number)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        number="$2"
        shift 2
        ;;
      -r|--random-length)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        rand_len="$2"
        shift 2
        ;;
      --script-name)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        script_name="$2"
        shift 2
        ;;
      --assigned-with)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        assigned_with="$2"
        shift 2
        ;;
      --created-by)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        created_by="$2"
        shift 2
        ;;
      --email)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        email="$2"
        shift 2
        ;;
      --assigned-script-id)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        assigned_script_id="$2"
        shift 2
        ;;
      --alias-call)
        [[ $# -ge 2 ]] || { scrid_err "Missing value for $1"; return 1; }
        alias_call="$2"
        shift 2
        ;;
      --id-only)
        id_only=1
        shift
        ;;
      --no-clip)
        no_clip=1
        shift
        ;;
      -h|--help)
        show_help
        return 0
        ;;
      *)
        scrid_err "Unknown arg: $1"
        return 1
        ;;
    esac
  done

  [[ "$number" =~ ^[0-9]+$ ]] || { scrid_err "--number must be an integer"; return 1; }
  [[ "$rand_len" =~ ^[0-9]+$ ]] || { scrid_err "--random-length must be an integer"; return 1; }
  (( number >= 1 )) || { scrid_err "--number must be at least 1"; return 1; }
  (( rand_len >= 1 )) || { scrid_err "--random-length must be at least 1"; return 1; }

  local outputs=()
  local i scr_id block final_output

  for ((i=1; i<=number; i++)); do
    scr_id="$(scrid_generate "$rand_len")"

    if [[ $id_only -eq 1 ]]; then
      outputs+=("$scr_id")
    else
      block="# Script Name: $script_name
# ID: $scr_id
# Assigned with: $assigned_with
# Created by: $created_by
# Email: $email
# Alias Call: $alias_call"
      outputs+=("$block")
    fi
  done

  final_output=""
  for block in "${outputs[@]}"; do
    if [[ -n "$final_output" ]]; then
      final_output+=$'\n\n'
    fi
    final_output+="$block"
  done

  printf '%s\n' "$final_output"

  if [[ $no_clip -eq 0 ]]; then
    scrid_clip "$final_output" || true
  fi
}

main "$@"
