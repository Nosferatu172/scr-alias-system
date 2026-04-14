#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# BOOTSTRAP
# ==================================================

SCRIPT_PATH="$(readlink -f "$0")"
MKTOOLKITHOME="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

CONFIG_FILE="$MKTOOLKITHOME/mktool.conf.csv"
LOG_DIR="$MKTOOLKITHOME/logs"

LOG_ENABLED=0
OPEN_EDITOR=0
FORCE_OVERWRITE=0
NO_TEMPLATE=0

LANGUAGE=""
NAME=""
TARGET_MODE="cwd"
TARGET_SUBDIR=""

# ==================================================
# LOGGING
# ==================================================

log() {
    [ "$LOG_ENABLED" -eq 1 ] || return 0
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/mktool.log"
}

# ==================================================
# CONFIG SYSTEM
# ==================================================

load_override() {
    local lang="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    grep "^$lang," "$CONFIG_FILE" | cut -d',' -f2 || true
}

resolve_base() {
    local lang="$1"
    local override

    override="$(load_override "$lang")"

    if [ -n "${override:-}" ]; then
        echo "$override"
        return
    fi

    case "$lang" in
        python) echo "/mnt/c/scr/zpy" ;;
        ruby) echo "/mnt/c/scr/zru" ;;
        bash) echo "/mnt/c/scr/bsh" ;;
        alias) echo "/mnt/c/scr/aliases/lib" ;;
    esac
}

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF
mktool.sh

Usage:
  mktool.sh <language> <name>

Languages:
  python | ruby | bash | alias

Flags:
  -e   open editor
  -f   force overwrite
  -n   no template
  -l   enable logging
  -h   help
EOF
}

# ==================================================
# LANGUAGE NORMALIZATION
# ==================================================

normalize_language() {
    case "$1" in
        py|python) echo "python" ;;
        rb|ruby) echo "ruby" ;;
        bash|sh) echo "bash" ;;
        alias) echo "alias" ;;
        *) return 1 ;;
    esac
}

apply_extension() {
    case "$1" in
        bash) echo "$2" ;;
        python) [[ "$2" == *.py ]] && echo "$2" || echo "$2.py" ;;
        ruby) [[ "$2" == *.rb ]] && echo "$2" || echo "$2.rb" ;;
        alias) echo "$2" ;;
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
# TEMPLATE LOADER
# ==================================================

get_template() {
    case "$1" in
        bash) echo "$MKTOOLKITHOME/templates/bash.sh.tpl" ;;
        python) echo "$MKTOOLKITHOME/templates/python.py.tpl" ;;
        ruby) echo "$MKTOOLKITHOME/templates/ruby.rb.tpl" ;;
        alias) echo "$MKTOOLKITHOME/templates/alias.txt.tpl" ;;
    esac
}

# ==================================================
# PATH
# ==================================================

normalize_path() {
    mkdir -p "$(dirname "$1")"
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# ==================================================
# ARG PARSING
# ==================================================

while [ $# -gt 0 ]; do
    case "$1" in
        -e) OPEN_EDITOR=1; shift ;;
        -f) FORCE_OVERWRITE=1; shift ;;
        -n) NO_TEMPLATE=1; shift ;;
        -l) LOG_ENABLED=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) break ;;
    esac
done

[ $# -lt 2 ] && echo "Usage: mktool.sh <language> <name>" && exit 1

LANGUAGE="$(normalize_language "$1")"
shift
NAME="$1"

BASE="$(resolve_base "$LANGUAGE")"
NAME="$(apply_extension "$LANGUAGE" "$NAME")"

TARGET="$BASE/$NAME"
TARGET="$(normalize_path "$TARGET")"

log "language=$LANGUAGE"
log "target=$TARGET"

# ==================================================
# CREATE FILE
# ==================================================

if [ -e "$TARGET" ] && [ "$FORCE_OVERWRITE" -ne 1 ]; then
    echo "File exists: $TARGET"
    exit 1
fi

TPL="$(get_template "$LANGUAGE")"

{
    shebang "$LANGUAGE"
    echo ""

    if [ "$NO_TEMPLATE" -eq 0 ] && [ -f "$TPL" ]; then
        sed \
            -e "s|__SCRIPT_NAME__|$NAME|g" \
            -e "s|__FULL_PATH__|$TARGET|g" \
            -e "s|__DATE__|$(date '+%Y-%m-%d %H:%M:%S')|g" \
            "$TPL"
    fi
} > "$TARGET"

chmod +x "$TARGET"

log "created"

echo "Created: $TARGET"

[ "$OPEN_EDITOR" -eq 1 ] && nano "$TARGET"
