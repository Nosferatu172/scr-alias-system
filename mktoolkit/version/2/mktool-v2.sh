#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# BOOTSTRAP (SELF DISCOVERY)
# ==================================================

SCRIPT_PATH="$(readlink -f "$0")"
MKTOOLKITHOME="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

CONFIG_FILE="$MKTOOLKITHOME/mktool.conf.csv"
LOG_DIR="$MKTOOLKITHOME/logs"
INDEX_FILE="$MKTOOLKITHOME/.mktool_index.txt"

LOG_ENABLED=0
OPEN_EDITOR=0
FORCE_OVERWRITE=0
NO_TEMPLATE=0
UPDATE_MODE=0

LANGUAGE=""
NAME=""
TARGET=""

# ==================================================
# LOGGING
# ==================================================

log() {
    [ "$LOG_ENABLED" -eq 1 ] || return 0
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/mktool.log"
}

# ==================================================
# CONFIG SYSTEM (CSV OVERRIDES)
# ==================================================

#resolve_base() {
#    local lang="$1"
#
#    [ -f "$CONFIG_FILE" ] || {
#        echo ""
#        return
#    }
#
#    local override
#    override="$(grep "^$lang," "$CONFIG_FILE" | cut -d',' -f2 || true)"
#
#    if [ -n "${override:-}" ]; then
#        echo "$override"
#        return
#    fi
#
#    case "$lang" in
#        python) echo "/mnt/c/scr/zpy" ;;
#        ruby) echo "/mnt/c/scr/zru" ;;
#        bash) echo "/mnt/c/scr/bsh" ;;
#        alias) echo "/mnt/c/scr/aliases/lib" ;;
#    esac
#}
# ==================================================
bootstrap() {
    mkdir -p "$MKTOOLKITHOME/templates"
    mkdir -p "$MKTOOLKITHOME/logs"

    # create default config if missing
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
python,/mnt/c/scr/zpy
ruby,/mnt/c/scr/zru
bash,/mnt/c/scr/bsh
alias,/mnt/c/scr/aliases/lib
EOF
        echo "Created default config: $CONFIG_FILE"
    fi

    # create index file if missing
    [ -f "$INDEX_FILE" ] || touch "$INDEX_FILE"
}
# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF
mktool v2

Usage:
  mktool.sh <language> <name>

Flags:
  -e   open editor
  -f   force overwrite
  -n   no template
  -l   enable logging
  -u   update existing script
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
# TEMPLATE SYSTEM
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
# DEPENDENCY SCANNING (LIGHTWEIGHT)
# ==================================================

scan_deps() {
    local file="$1"
    grep -E "import |require|source|from " "$file" 2>/dev/null || true
}

write_deps_header() {
    local file="$1"

    local deps
    deps="$(scan_deps "$file")"

    if [ -n "$deps" ]; then
        echo "# Dependencies:"
        echo "$deps" | sed 's/^/#   /'
    fi
}

# ==================================================
# INDEX REGISTRY (SIMPLE)
# ==================================================

register() {
    local file="$1"
    local lang="$2"

    echo "$lang|$file" >> "$INDEX_FILE"
}

# ==================================================
# UPDATE MODE (KEY FEATURE)
# ==================================================

update_file() {
    local file="$1"
    local lang="$2"
    local tpl="$3"

    [ -f "$file" ] || {
        echo "File not found: $file"
        exit 1
    }

    cp "$file" "$file.bak"

    # extract body (remove old header block if exists)
    awk '
        BEGIN { skip=1 }
        /^# ============================================/ { skip=0 }
        skip==0 { print }
    ' "$file" > "$file.body" || true

    {
        shebang "$lang"
        echo ""

        if [ -f "$tpl" ] && [ "$NO_TEMPLATE" -eq 0 ]; then
            sed \
                -e "s|__SCRIPT_NAME__|$(basename "$file")|g" \
                -e "s|__FULL_PATH__|$file|g" \
                -e "s|__DATE__|$(date '+%Y-%m-%d %H:%M:%S')|g" \
                "$tpl"
        fi

        echo ""
        write_deps_header "$file"

        if [ -f "$file.body" ]; then
            cat "$file.body"
        fi
    } > "$file"

    rm -f "$file.body"

    echo "Updated: $file"
}

# ==================================================
# ARGUMENTS
# ==================================================

while [ $# -gt 0 ]; do
    case "$1" in
        -e) OPEN_EDITOR=1; shift ;;
        -f) FORCE_OVERWRITE=1; shift ;;
        -n) NO_TEMPLATE=1; shift ;;
        -l) LOG_ENABLED=1; shift ;;
        -u) UPDATE_MODE=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) break ;;
    esac
done

[ $# -lt 2 ] && echo "Usage: mktool.sh <language> <name>" && exit 1

LANGUAGE="$(normalize_language "$1")"
shift
NAME="$1"

BASE="$(resolve_base "$LANGUAGE")"
TPL="$(get_template "$LANGUAGE")"

NAME="$(apply_extension "$LANGUAGE" "$NAME")"
TARGET="$BASE/$NAME"

log "lang=$LANGUAGE"
log "target=$TARGET"

# ==================================================
# UPDATE MODE FLOW
# ==================================================

if [ "$UPDATE_MODE" -eq 1 ]; then
    update_file "$TARGET" "$LANGUAGE" "$TPL"
    exit 0
fi

# ==================================================
# CREATE MODE FLOW
# ==================================================

if [ -e "$TARGET" ] && [ "$FORCE_OVERWRITE" -ne 1 ]; then
    echo "File exists: $TARGET"
    exit 1
fi

mkdir -p "$(dirname "$TARGET")"

{
    shebang "$LANGUAGE"
    echo ""

    if [ -f "$TPL" ] && [ "$NO_TEMPLATE" -eq 0 ]; then
        sed \
            -e "s|__SCRIPT_NAME__|$NAME|g" \
            -e "s|__FULL_PATH__|$TARGET|g" \
            -e "s|__DATE__|$(date '+%Y-%m-%d %H:%M:%S')|g" \
            "$TPL"
    fi

    echo ""
    write_deps_header "$TARGET"
} > "$TARGET"

chmod +x "$TARGET"

register "$TARGET" "$LANGUAGE"

log "created"

echo "Created: $TARGET"

[ "$OPEN_EDITOR" -eq 1 ] && nano "$TARGET"
