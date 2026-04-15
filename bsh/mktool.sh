#!/usr/bin/env bash
set -euo pipefail
VER="1.0.0"

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
ASK_SUBFOLDER=0
CUSTOM_TEMPLATE=""

LANGUAGE=""
NAME=""
PURPOSE=""
SUBFOLDER=""
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
# SCR-ID GENERATION
# ==================================================

SCRID_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

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

# ==================================================
# HELP
# ==================================================

show_help() {
cat <<EOF
mktool v$VER

Usage:
  mktool <language> [path...] <name> [flags]

Languages:
  py | python
  rb | ruby
  sh | bash
  zsh

Examples:
  mktool sh sample
  mktool sh setup sample
  mktool py ai trainer
  mktool sh tools/net/utils scan --template apt_installs.sh.tpl

Flags:
  -o   open editor
  -f   force overwrite
  -n   no template
  -q   quiet mode
  -p   skip purpose prompt
  -l   enable logging
  -t, --template <file>  use specific template file
  -v   show version
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
        sh|bash) echo "bash" ;;
        zsh) echo "zsh" ;;
        *) return 1 ;;
    esac
}

apply_extension() {
    case "$1" in
        bash) [[ "$2" == *.sh ]] && echo "$2" || echo "$2.sh" ;;
        zsh) [[ "$2" == *.zsh ]] && echo "$2" || echo "$2.zsh" ;;
        python) [[ "$2" == *.py ]] && echo "$2" || echo "$2.py" ;;
        ruby) [[ "$2" == *.rb ]] && echo "$2" || echo "$2.rb" ;;
    esac
}

# ==================================================
# TEMPLATE RESOLVE
# ==================================================

get_template() {
    if [ -n "$CUSTOM_TEMPLATE" ]; then
        local template="$MKTOOLKITHOME/templates/$CUSTOM_TEMPLATE"
        if [ -f "$template" ]; then
            echo "$template"
        else
            echo ""
        fi
        return
    fi

    local lang="$1"
    local ext=""
    case "$lang" in
        bash|sh) ext="sh" ;;
        zsh) ext="zsh" ;;
        python|py) ext="py" ;;
        ruby|rb) ext="rb" ;;
        *) return 1 ;;
    esac
    local template="$MKTOOLKITHOME/templates/${lang}.${ext}.tpl"
    if [ -f "$template" ]; then
        echo "$template"
    elif [ "$lang" = "zsh" ] && [ -f "$MKTOOLKITHOME/templates/bash.sh.tpl" ]; then
        echo "$MKTOOLKITHOME/templates/bash.sh.tpl"
    else
        echo ""
    fi
}

shebang() {
    case "$1" in
        bash) echo '#!/usr/bin/env bash' ;;
        zsh) echo '#!/usr/bin/env zsh' ;;
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
        zsh) echo "/mnt/c/scr/zsh" ;;
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
        -t|--template) 
            [[ $# -ge 2 ]] || { echo "Missing value for $1"; exit 1; }
            CUSTOM_TEMPLATE="$2"; shift 2 ;;
        -v|--version) echo "$VER"; exit 0 ;;
        -h|--help) show_help; exit 0 ;;
        *) break ;;
    esac
done

[ $# -lt 2 ] && { show_help; exit 1; }

# ==================================================
# INPUT HANDLING (CORE MAGIC)
# ==================================================

LANGUAGE_RAW="$1"
LANGUAGE="$(normalize_language "$LANGUAGE_RAW")" || {
    echo "Invalid language: $LANGUAGE_RAW"
    exit 1
}
shift

BASE="$(resolve_base "$LANGUAGE")"

# Last argument = filename
NAME="${@: -1}"

# Everything before = subfolder path
if [ $# -gt 1 ]; then
    SUBFOLDER="${*:1:$#-1}"
else
    SUBFOLDER=""
fi

# Normalize spacing -> proper path
IFS=' ' read -r -a PARTS <<< "$SUBFOLDER"
SUBFOLDER="$(IFS=/; echo "${PARTS[*]}")"

# Apply extension
NAME="$(apply_extension "$LANGUAGE" "$NAME")"

# Build target path
if [ -n "$SUBFOLDER" ]; then
    TARGET="$BASE/$SUBFOLDER/$NAME"
else
    TARGET="$BASE/$NAME"
fi

log "lang=$LANGUAGE"
log "target=$TARGET"
log "version=$VER"

# ==================================================
# PURPOSE PROMPT
# ==================================================

if [ "$ASK_PURPOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
    read -rp "Purpose (optional): " PURPOSE
fi

# ==================================================
# GENERATE SCR-ID
# ==================================================

scr_id="$(scrid_generate)"
alias_call="${NAME%.*}"

# ==================================================
# CREATE FILE
# ==================================================

if [ -e "$TARGET" ] && [ "$FORCE_OVERWRITE" -ne 1 ]; then
    echo "File exists: $TARGET"
    exit 1
fi

mkdir -p "$(dirname "$TARGET")"

if [ "$NO_TEMPLATE" -eq 0 ]; then
    TEMPLATE_FILE="$(get_template "$LANGUAGE")"
    if [ -n "$TEMPLATE_FILE" ] && [ -f "$TEMPLATE_FILE" ]; then
        sed \
            -e "s/__SCRIPT_NAME__/${NAME//\//\\/}/g" \
            -e "s/__PURPOSE__/${PURPOSE//\//\\/}/g" \
            -e "s/__DATE__/$(date '+%Y-%m-%d %H:%M:%S')/g" \
            -e "s/__FULL_PATH__/${TARGET//\//\\/}/g" \
            -e "s/__SCR_ID__/${scr_id}/g" \
            -e "s/__ALIAS_CALL__/${alias_call}/g" \
            "$TEMPLATE_FILE" > "$TARGET"
        if [ "$LANGUAGE" = "zsh" ]; then
            sed -i "s|#!/usr/bin/env bash|#!/usr/bin/env zsh|g" "$TARGET"
        fi
    else
        # Fallback to basic template
        {
            shebang "$LANGUAGE"
            echo ""
            cat <<EOF
# ============================================
# Script Name: $NAME
# ID: $scr_id
# Purpose: $PURPOSE
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Path: $TARGET
# Assigned with: mktool
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: $alias_call
# ============================================

# Your code here
EOF
        } > "$TARGET"
    fi
else
    # No template
    {
        shebang "$LANGUAGE"
        echo ""
        echo "# Your code here"
    } > "$TARGET"
fi

chmod +x "$TARGET"

log "created"

echo "Created: $TARGET"

# ==================================================
# OPEN EDITOR
# ==================================================

if [ "$OPEN_EDITOR" -eq 1 ]; then
    nano "$TARGET"
fi