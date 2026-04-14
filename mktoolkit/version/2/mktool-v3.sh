#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# BOOTSTRAP
# ==================================================

SCRIPT_PATH="$(readlink -f "$0")"
MKTOOLKITHOME="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

CONFIG_FILE="$MKTOOLKITHOME/mktool.conf.csv"
LOG_DIR="$MKTOOLKITHOME/logs"

# ==================================================
# FLAGS (TOGGLES)
# ==================================================

QUIET=0
ASK_PURPOSE=1
OPEN_EDITOR=0
FORCE_OVERWRITE=0
NO_TEMPLATE=0
LOG_ENABLED=0

LANGUAGE=""
NAME=""
PURPOSE=""

# ==================================================
# LOGGING
# ==================================================

log() {
    [ "$LOG_ENABLED" -eq 1 ] || return 0
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/mktool.log"
}

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF
mktool v3

Usage:
  mktool.sh <language> <name> [flags]

Languages:
  python | ruby | bash

Flags:
  -o   open editor
  -f   force overwrite
  -n   no template
  -q   quiet mode (minimal prompts)
  -p   skip purpose prompt
  -l   enable logging
  -h   help

Examples:
  mktool.sh python tool
  mktool.sh ruby cleaner -o
  mktool.sh bash netcheck -q -p
EOF
}

# ==================================================
# Subfolder Prompt
# ==================================================
get_subfolder() {
    local base="$1"
    local input

    echo ""
    echo "Subfolder (optional)"
    echo "Examples:"
    echo "  file-ops"
    echo "  file-ops/net/tools"
    echo "  leave blank for root"
    echo ""

    read -rp "Path: " input

    # clean input
    input="${input#/}"
    input="${input%/}"

    if [ -z "$input" ]; then
        echo ""
        return
    fi

    echo "$input"
}



# ==================================================
# LANGUAGE NORMALIZATION
# ==================================================

normalize_language() {
    case "$1" in
        py|python) echo "python" ;;
        rb|ruby) echo "ruby" ;;
        bash|sh) echo "bash" ;;
        *) return 1 ;;
    esac
}

apply_extension() {
    case "$1" in
        bash) echo "$2" ;;
        python) [[ "$2" == *.py ]] && echo "$2" || echo "$2.py" ;;
        ruby) [[ "$2" == *.rb ]] && echo "$2" || echo "$2.rb" ;;
    esac
}

shebang() {
    case "$1" in
        bash) echo '#!/usr/bin/env bash' ;;
        python) echo '#!/usr/bin/env python3' ;;
        ruby) echo '#!/usr/bin/env ruby' ;;
    esac
}

# ==================================================
# BASE DIRECTORY RESOLVE
# ==================================================

resolve_base() {
    case "$1" in
        python) echo "/mnt/c/scr/zpy" ;;
        ruby) echo "/mnt/c/scr/zru" ;;
        bash) echo "/mnt/c/scr/bsh" ;;
    esac
}

# ==================================================
# ARG PARSING
# ==================================================

while [ $# -gt 0 ]; do
    case "$1" in
        -o) OPEN_EDITOR=1; shift ;;
        -f) FORCE_OVERWRITE=1; shift ;;
        -n) NO_TEMPLATE=1; shift ;;
        -q) QUIET=1; shift ;;
        -p) ASK_PURPOSE=0; shift ;;
        -l) LOG_ENABLED=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) break ;;
    esac
done

[ $# -lt 2 ] && echo "Usage: mktool.sh <language> <name>" && exit 1

# ==================================================
# INPUT
# ==================================================

LANGUAGE="$(normalize_language "$1")"
shift
NAME="$1"

BASE="$(resolve_base "$LANGUAGE")"
#TARGET="$BASE/$NAME"
SUBFOLDER=""

if [ "$ASK_SUBFOLDER" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
    SUBFOLDER="$(get_subfolder "$BASE")"
fi

if [ -n "$SUBFOLDER" ]; then
    TARGET="$BASE/$SUBFOLDER/$NAME"
else
    TARGET="$BASE/$NAME"
fi

log "lang=$LANGUAGE"
log "target=$TARGET"

# ==================================================
# PURPOSE (TOGGLEABLE)
# ==================================================

if [ "$ASK_PURPOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
    read -rp "Purpose (optional): " PURPOSE
fi

# ==================================================
# CREATE FILE
# ==================================================

if [ -e "$TARGET" ] && [ "$FORCE_OVERWRITE" -ne 1 ]; then
    echo "File exists: $TARGET"
    exit 1
fi

#mkdir -p "$(dirname "$TARGET")"
mkdir -p "$(dirname "$TARGET")"

{
    shebang "$LANGUAGE"
    echo ""

    cat <<EOF
# ============================================
# Script: $NAME
# Purpose: $PURPOSE
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Path: $TARGET
# ============================================

# Your code here
EOF

} > "$TARGET"

chmod +x "$TARGET"

log "created"

echo "Created: $TARGET"

# ==================================================
# OPEN EDITOR (TOGGLE)
# ==================================================

if [ "$OPEN_EDITOR" -eq 1 ]; then
    nano "$TARGET"
fi
