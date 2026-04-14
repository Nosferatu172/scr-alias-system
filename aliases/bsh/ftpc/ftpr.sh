#!/usr/bin/env bash
# Script Name: ftpr.sh
# ID: SCR-ID-20260317130443-JQ9V80R314
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ftpr

set -Eeuo pipefail

# ============================================================
# ftpr — resolver-aware FTP GET / ADD controller using lftp
#
# Designed for launchers/resolvers that:
#   - run the script from its own directory
#   - export SCR_CALLER_PWD with the original caller location
#
# Behavior:
#   - config/logs live next to this script
#   - transfers use either:
#       * saved default local directory
#       * caller directory via -a / --active
#
# Modes:
#   (default) GET remote -> local
#   -A, --add, --put    ADD local -> remote
#   -G, --get           Force GET mode
#
# Common:
#   -a, --active        Use SCR_CALLER_PWD (or pwd fallback) for this run
#   -l, --list          Show saved default local directory
#   -e, --edit          Edit config file
#   -n, --dry-run       Show what would happen, do not transfer
#   -h, --help          Show help
#
# GET-only:
#   -r, --rm-remote     Delete remote files after successful download
#   -k, --keep-remote   Keep remote files (default)
#
# ADD-only:
#   --src PATH          File / dir / glob to upload
#                       quote globs, e.g. --src "./out/*"
#
# Remote:
#   [REMOTE_DIR]        Positional remote directory (default ".")
#   --dst DIR           Same as REMOTE_DIR, but explicit
# ============================================================

# -----------------------
# FTP Config
# -----------------------
# tablet
# HOST="10.0.0.133"
# PORT="2121"
# USER="demon"
# PASS="demon"

# iphone
HOST="10.0.0.50"
PORT="2121"
USER="demon"
PASS="demon"

# -----------------------
# Patterns used for GET,
# and default selection for ADD if --src is omitted
# -----------------------
EXTENSIONS=(
  "*.js" "*.zip" "*.pages" "*.csv" "*.txt" "*.rb" "*.py" "*.sh"
  "*.xlsx" "*.pdf" "*.docx" "*.mp3" "*.mp4" "*.MOV" "*.gz" "*.exe"
)

# -----------------------
# Script / config paths
# -----------------------
SCRIPT_PATH="${SCR_SCRIPT_PATH:-$(readlink -f "${BASH_SOURCE[0]}")}"
SCRIPT_DIR="${SCR_SCRIPT_DIR:-$(cd "$(dirname "$SCRIPT_PATH")" && pwd)}"
LOG_DIR="$SCRIPT_DIR/logs"
CONF_PATH="$LOG_DIR/defaults.conf"

mkdir -p "$LOG_DIR"

# -----------------------
# Helpers
# -----------------------
die() {
  echo "❌ $*" >&2
  exit 1
}

info() {
  echo "ℹ️  $*"
}

warn() {
  echo "⚠️  $*"
}

ok() {
  echo "✅ $*"
}

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

expand_path() {
  local p="$1"
  if [[ "$p" == "~"* ]]; then
    printf '%s\n' "${p/#\~/$HOME}"
  else
    printf '%s\n' "$p"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

prompt_line() {
  echo
  echo "$1"
  echo "↳"
  read -r REPLY
}

get_conf_value() {
  local key="$1"
  [[ -f "$CONF_PATH" ]] || return 1
  awk -F'=' -v k="$key" '
    $1 == k {
      sub(/^[^=]*=/, "", $0)
      print $0
      exit
    }
  ' "$CONF_PATH"
}

set_conf_value() {
  local key="$1"
  local value="$2"

  touch "$CONF_PATH"

  if grep -qE "^${key}=" "$CONF_PATH" 2>/dev/null; then
    awk -v k="$key" -v v="$value" '
      BEGIN { done=0 }
      $0 ~ "^" k "=" {
        print k "=" v
        done=1
        next
      }
      { print }
      END {
        if (!done) print k "=" v
      }
    ' "$CONF_PATH" > "${CONF_PATH}.tmp"
    mv "${CONF_PATH}.tmp" "$CONF_PATH"
  else
    printf '%s=%s\n' "$key" "$value" >> "$CONF_PATH"
  fi
}

ensure_conf_or_prompt() {
  local saved
  saved="$(trim "$(get_conf_value default_dir || true)")"
  if [[ -n "$saved" ]]; then
    return 0
  fi

  info "First run: no saved default local directory found."
  info "Config file: $CONF_PATH"

  while true; do
    prompt_line "📂 Enter a DEFAULT local directory:"
    local ans
    ans="$(expand_path "$(trim "$REPLY")")"

    [[ -n "$ans" ]] || {
      warn "Please enter a path."
      continue
    }

    if [[ ! -d "$ans" ]]; then
      info "Directory does not exist. Creating:"
      echo "$ans"
      mkdir -p "$ans"
    fi

    set_conf_value "default_dir" "$ans"
    ok "Saved default local directory: $ans"
    break
  done
}

open_editor() {
  "${EDITOR:-nano}" "$CONF_PATH"
}

show_help() {
  cat <<'EOF'
Usage:
  ftpr [options] [REMOTE_DIR]

Modes:
  (default) GET remote -> local
  -A, --add, --put      Upload local -> remote
  -G, --get             Force GET mode

Common:
  -a, --active          Use SCR_CALLER_PWD (or pwd fallback) for this run
  -l, --list            Show saved default local directory
  -e, --edit            Edit config file
  -n, --dry-run         Show what would run, do not transfer
  -h, --help            Show help

GET-only:
  -r, --rm-remote       Delete remote files after download
  -k, --keep-remote     Keep remote files (default)

ADD-only:
  --src PATH            Upload source:
                          - single file
                          - single directory
                          - quoted glob, e.g. "./out/*"
                        If omitted, uploads matching EXTENSIONS
                        from the local dir (non-recursive).

Remote:
  [REMOTE_DIR]          Positional remote directory (default ".")
  --dst DIR             Same as REMOTE_DIR, but explicit

Examples:
  ftpr
  ftpr -a
  ftpr -r /inbox
  ftpr -A --src ./build.zip
  ftpr -A --src ./folder --dst /drop
  ftpr -A --src "./out/*" --dst /drop
EOF
}

show_list() {
  echo "📌 Saved default local directory:"
  local val
  val="$(trim "$(get_conf_value default_dir || true)")"
  [[ -n "$val" ]] && echo "$val" || echo "(none set)"
}

# -----------------------
# Resolver-aware context
# -----------------------
CALLER_DIR="${SCR_CALLER_PWD:-$(pwd)}"
CALLER_DIR="$(expand_path "$CALLER_DIR")"

# -----------------------
# Defaults
# -----------------------
MODE="get"
USE_ACTIVE=false
DO_LIST=false
DO_EDIT=false
DELETE_REMOTE=false
REMOTE_DIR="."
SRC_SPEC=""
DRY_RUN=false

# -----------------------
# Parse args
# -----------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;

    -A|--add|--put)
      MODE="add"
      shift
      ;;

    -G|--get)
      MODE="get"
      shift
      ;;

    -a|--active)
      USE_ACTIVE=true
      shift
      ;;

    -l|--list)
      DO_LIST=true
      shift
      ;;

    -e|--edit)
      DO_EDIT=true
      shift
      ;;

    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;

    -r|--rm-remote)
      DELETE_REMOTE=true
      shift
      ;;

    -k|--keep-remote)
      DELETE_REMOTE=false
      shift
      ;;

    --src)
      shift
      [[ $# -gt 0 ]] || die "--src requires a value"
      SRC_SPEC="$1"
      shift
      ;;

    --dst)
      shift
      [[ $# -gt 0 ]] || die "--dst requires a value"
      REMOTE_DIR="$1"
      shift
      ;;

    -*)
      die "Unknown option: $1"
      ;;

    *)
      if [[ "$REMOTE_DIR" != "." ]]; then
        die "Too many positional arguments. Only one REMOTE_DIR is supported."
      fi
      REMOTE_DIR="$1"
      shift
      ;;
  esac
done

# -----------------------
# Utility actions
# -----------------------
if $DO_LIST; then
  show_list
  exit 0
fi

if $DO_EDIT; then
  [[ -f "$CONF_PATH" ]] || ensure_conf_or_prompt
  open_editor
  exit 0
fi

# -----------------------
# Checks
# -----------------------
require_cmd lftp
require_cmd awk
require_cmd sed
require_cmd readlink

[[ -d "$CALLER_DIR" ]] || die "Caller directory does not exist: $CALLER_DIR"

# -----------------------
# Resolve local dir
# -----------------------
if $USE_ACTIVE; then
  LOCAL_DIR="$CALLER_DIR"
else
  ensure_conf_or_prompt
  LOCAL_DIR="$(trim "$(get_conf_value default_dir || true)")"
  [[ -n "$LOCAL_DIR" ]] || die "default_dir is missing from config"
  LOCAL_DIR="$(expand_path "$LOCAL_DIR")"
fi

[[ -d "$LOCAL_DIR" ]] || die "Local directory does not exist: $LOCAL_DIR"

# -----------------------
# Sanity
# -----------------------
if [[ "$MODE" == "add" && "$DELETE_REMOTE" == "true" ]]; then
  warn "--rm-remote is GET-only; ignoring in ADD mode."
  DELETE_REMOTE=false
fi

# -----------------------
# lftp script builders
# -----------------------
build_lftp_common() {
  cat <<EOF
set ftp:ssl-allow no
set ftp:passive-mode on
set xfer:clobber yes
set cmd:interactive no
set net:max-retries 1
set net:timeout 20
EOF
}

build_get_script() {
  local local_dir="$1"
  local remote_dir="$2"
  local delete_remote="$3"
  local mget_cmd="mget"

  if [[ "$delete_remote" == "true" ]]; then
    mget_cmd="mget -E"
  fi

  {
    build_lftp_common
    echo "lcd \"$local_dir\""
    echo "cd \"$remote_dir\""
    echo
    local pat
    for pat in "${EXTENSIONS[@]}"; do
      echo "echo \"▶ Trying $pat\""
      echo "$mget_cmd \"$pat\" || true"
    done
    echo
    echo "bye"
  }
}

build_add_default_patterns_script() {
  local local_dir="$1"
  local remote_dir="$2"

  {
    build_lftp_common
    echo "lcd \"$local_dir\""
    echo "cd \"$remote_dir\""
    echo
    local pat
    for pat in "${EXTENSIONS[@]}"; do
      echo "echo \"▶ Putting $pat\""
      echo "mput \"$pat\" || true"
    done
    echo
    echo "bye"
  }
}

build_add_file_script() {
  local file_path="$1"
  local remote_dir="$2"

  {
    build_lftp_common
    echo "cd \"$remote_dir\""
    echo "echo \"▶ Putting file: $file_path\""
    echo "put \"$file_path\""
    echo
    echo "bye"
  }
}

build_add_dir_script() {
  local dir_path="$1"
  local remote_dir="$2"
  local remote_name="$3"

  {
    build_lftp_common
    echo "cd \"$remote_dir\""
    echo "echo \"▶ Mirroring directory: $dir_path\""
    echo "mirror -R \"$dir_path\" \"$remote_name\""
    echo
    echo "bye"
  }
}

build_add_glob_script() {
  local local_dir="$1"
  local remote_dir="$2"
  local src_spec="$3"

  {
    build_lftp_common
    echo "lcd \"$local_dir\""
    echo "cd \"$remote_dir\""
    echo "echo \"▶ Putting glob: $src_spec\""
    echo "mput $src_spec || true"
    echo
    echo "bye"
  }
}

run_lftp_script() {
  local script_body="$1"

  if $DRY_RUN; then
    echo "----- BEGIN LFTP SCRIPT -----"
    printf '%s\n' "$script_body"
    echo "------ END LFTP SCRIPT ------"
    return 0
  fi

  lftp -u "$USER","$PASS" "ftp://$HOST:$PORT" <<< "$script_body"
}

# -----------------------
# Status
# -----------------------
echo "🌐 FTP:         ftp://$HOST:$PORT"
echo "🧭 Script dir:  $SCRIPT_DIR"
echo "📍 Caller dir:  $CALLER_DIR"
echo "📁 Remote dir:  $REMOTE_DIR"
echo "💾 Local dir:   $LOCAL_DIR"
echo "🔁 Mode:        $MODE"
echo "🧪 Dry run:     $DRY_RUN"

if [[ "$MODE" == "get" ]]; then
  echo "🧹 Delete remote after download: $DELETE_REMOTE"
else
  echo "➕ Upload source: ${SRC_SPEC:-"(default: EXTENSIONS in local dir)"}"
fi
echo

# -----------------------
# Execute
# -----------------------
if [[ "$MODE" == "get" ]]; then
  LFTP_SCRIPT="$(build_get_script "$LOCAL_DIR" "$REMOTE_DIR" "$DELETE_REMOTE")"
  run_lftp_script "$LFTP_SCRIPT"
  echo
  ok "GET done."

else
  if [[ -z "$SRC_SPEC" ]]; then
    LFTP_SCRIPT="$(build_add_default_patterns_script "$LOCAL_DIR" "$REMOTE_DIR")"
    run_lftp_script "$LFTP_SCRIPT"
    echo
    ok "ADD done."
  else
    EXPANDED_SRC="$(expand_path "$SRC_SPEC")"

    if [[ "$EXPANDED_SRC" == /* ]]; then
      if [[ -f "$EXPANDED_SRC" ]]; then
        LFTP_SCRIPT="$(build_add_file_script "$EXPANDED_SRC" "$REMOTE_DIR")"
        run_lftp_script "$LFTP_SCRIPT"

      elif [[ -d "$EXPANDED_SRC" ]]; then
        SRC_BASENAME="$(basename "$EXPANDED_SRC")"
        LFTP_SCRIPT="$(build_add_dir_script "$EXPANDED_SRC" "$REMOTE_DIR" "$SRC_BASENAME")"
        run_lftp_script "$LFTP_SCRIPT"

      else
        die "Absolute source path not found: $EXPANDED_SRC"
      fi

    else
      REL_CLEAN="${EXPANDED_SRC#./}"
      CANDIDATE="$LOCAL_DIR/$REL_CLEAN"

      if [[ -f "$CANDIDATE" ]]; then
        LFTP_SCRIPT="$(build_add_file_script "$CANDIDATE" "$REMOTE_DIR")"
        run_lftp_script "$LFTP_SCRIPT"

      elif [[ -d "$CANDIDATE" ]]; then
        SRC_BASENAME="$(basename "$CANDIDATE")"
        LFTP_SCRIPT="$(build_add_dir_script "$CANDIDATE" "$REMOTE_DIR" "$SRC_BASENAME")"
        run_lftp_script "$LFTP_SCRIPT"

      else
        LFTP_SCRIPT="$(build_add_glob_script "$LOCAL_DIR" "$REMOTE_DIR" "$SRC_SPEC")"
        run_lftp_script "$LFTP_SCRIPT"
      fi
    fi

    echo
    ok "ADD done."
  fi
fi

echo
ok "Finished. Local directory:"
echo "$LOCAL_DIR"
