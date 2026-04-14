#!/usr/bin/env bash

set -u

#MKTOOLKITHOME="/mnt/c/scr/mktoolkit"

SCRIPT_PATH="$(readlink -f "$0")"
MKTOOLKITHOME="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

BASH_BASE="$MKTOOLKITHOME/bash"
PY_BASE="$MKTOOLKITHOME/zpy"
RB_BASE="$MKTOOLKITHOME/zru"
ALIAS_BASE="$MKTOOLKITHOME/aliases/lib/"

BASH_TEMPLATE="$MKTOOLKITHOME/bash-template.txt"
PY_TEMPLATE="$MKTOOLKITHOME/python-template.txt"
RB_TEMPLATE="$MKTOOLKITHOME/ruby-template.txt"

#BASH_TEMPLATE="/mnt/c/mktoolkit/bash-template.txt"
#PY_TEMPLATE="/mnt/c/mktoolkit/python-template.txt"
#RB_TEMPLATE="/mnt/c/mktoolkit/swap/ruby-template.txt"

OPEN_EDITOR=0
FORCE_OVERWRITE=0
NO_TEMPLATE=0

LANGUAGE=""
NAME=""
TARGET_MODE=""
TARGET_SUBDIR=""

show_help() {
    cat << EOF
Usage:
  mktool.sh [options] <language> <name>

Languages:
  bash | sh
  py   | python
  rb   | ruby

Modes:
  No mode given         Interactive menu
  -c                    Create in current working directory
  -t <subdir>           Create in language tree subdirectory
  -a <subdir>           Create in alias tree subdirectory

Options:
  -e                    Open in \$EDITOR after creation
  -f                    Overwrite if file exists
  -n                    No template, shebang only
  -h, --help            Show help

Examples:
  mktool.sh bash finder
  mktool.sh py zipcomb
  mktool.sh rb weather
  mktool.sh -c py testtool
  mktool.sh -t file-ops py zipcomb
  mktool.sh -t file-ops/music/renamer rb musicfix
  mktool.sh -a basic bash mycmd
EOF
}

normalize_language() {
    case "$1" in
        bash|sh)
            printf "bash"
            ;;
        py|python)
            printf "python"
            ;;
        rb|ruby)
            printf "ruby"
            ;;
        *)
            return 1
            ;;
    esac
}

language_base() {
    case "$1" in
        bash) printf "%s" "$BASH_BASE" ;;
        python) printf "%s" "$PY_BASE" ;;
        ruby) printf "%s" "$RB_BASE" ;;
    esac
}

language_template() {
    case "$1" in
        bash) printf "%s" "$BASH_TEMPLATE" ;;
        python) printf "%s" "$PY_TEMPLATE" ;;
        ruby) printf "%s" "$RB_TEMPLATE" ;;
    esac
}

language_shebang() {
    case "$1" in
        bash) printf '%s\n' '#!/usr/bin/env bash' ;;
        python) printf '%s\n' '#!/usr/bin/env python3' ;;
        ruby) printf '%s\n' '#!/usr/bin/env ruby' ;;
    esac
}

apply_extension() {
    local lang="$1"
    local name="$2"

    case "$lang" in
        bash)
            printf "%s" "$name"
            ;;
        python)
            [[ "$name" == *.py ]] && printf "%s" "$name" || printf "%s.py" "$name"
            ;;
        ruby)
            [[ "$name" == *.rb ]] && printf "%s" "$name" || printf "%s.rb" "$name"
            ;;
    esac
}

normalize_target_path() {
    local path="$1"
    local dir base

    dir="$(dirname "$path")"
    base="$(basename "$path")"

    mkdir -p "$dir" || exit 1
    dir="$(cd "$dir" && pwd)" || exit 1

    printf "%s/%s" "$dir" "$base"
}

pick_main_mode() {
    local base="$1"
    local label="$2"
    local choice

    echo "Create $label script in:"
    echo "  1) Current directory"
    echo "  2) $label tree ($base)"
    echo "  3) Alias tree ($ALIAS_BASE)"
    echo "  0) Cancel"

    while true; do
        read -rp "Enter number: " choice
        case "$choice" in
            1) TARGET_MODE="cwd"; return 0 ;;
            2) TARGET_MODE="tree"; return 0 ;;
            3) TARGET_MODE="alias"; return 0 ;;
            0) echo "Cancelled."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
}

pick_subdir_mode() {
    local label="$1"
    local choice

    echo "Choose $label folder mode:"
    echo "  1) Top-level category menu"
    echo "  2) Enter relative subpath manually"
    echo "  0) Cancel"

    while true; do
        read -rp "Enter number: " choice
        case "$choice" in
            1) return 1 ;;
            2) return 2 ;;
            0) echo "Cancelled."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
}

pick_top_level_subdir() {
    local base="$1"
    local dirs=()
    local i choice

    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

    if [ "${#dirs[@]}" -eq 0 ]; then
        echo "No subdirectories found in $base"
        exit 1
    fi

    echo "Choose a folder in $base:"
    for i in "${!dirs[@]}"; do
        printf "  %d) %s\n" "$((i + 1))" "${dirs[$i]}"
    done
    echo "  0) Cancel"

    while true; do
        read -rp "Enter number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -eq 0 ]; then
                echo "Cancelled."
                exit 0
            fi
            if [ "$choice" -ge 1 ] && [ "$choice" -le "${#dirs[@]}" ]; then
                TARGET_SUBDIR="${dirs[$((choice - 1))]}"
                return 0
            fi
        fi
        echo "Invalid choice."
    done
}

prompt_relative_subpath() {
    local base="$1"
    local input

    echo "Enter relative path under $base"
    echo "Examples:"
    echo "  file-ops"
    echo "  file-ops/zipper/lib3"
    echo "  yt/dl/3/lib"
    echo "  pass/lib"
    echo

    while true; do
        read -rp "Relative path: " input
        input="${input#/}"
        input="${input%/}"

        if [ -z "$input" ]; then
            echo "Path cannot be empty."
            continue
        fi

        if [ -d "$base/$input" ]; then
            TARGET_SUBDIR="$input"
            return 0
        fi

        echo "Directory does not exist: $base/$input"
    done
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c)
            TARGET_MODE="cwd"
            shift
            ;;
        -t)
            shift
            [ $# -eq 0 ] && echo "Missing subdir after -t" && exit 1
            TARGET_MODE="tree"
            TARGET_SUBDIR="$1"
            shift
            ;;
        -a)
            shift
            [ $# -eq 0 ] && echo "Missing subdir after -a" && exit 1
            TARGET_MODE="alias"
            TARGET_SUBDIR="$1"
            shift
            ;;
        -e)
            OPEN_EDITOR=1
            shift
            ;;
        -f)
            FORCE_OVERWRITE=1
            shift
            ;;
        -n)
            NO_TEMPLATE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

[ $# -lt 2 ] && echo "Need <language> and <name>. Use -h for help." && exit 1

LANGUAGE="$(normalize_language "$1")" || {
    echo "Invalid language: $1"
    exit 1
}
shift

NAME="$(apply_extension "$LANGUAGE" "$1")"

BASE="$(language_base "$LANGUAGE")"
TEMPLATE="$(language_template "$LANGUAGE")"

if [ -z "$TARGET_MODE" ]; then
    pick_main_mode "$BASE" "$LANGUAGE"
fi

case "$TARGET_MODE" in
    cwd)
        TARGET="$(pwd)/$NAME"
        ;;
    tree)
        if [ -z "${TARGET_SUBDIR:-}" ]; then
            if pick_subdir_mode "$LANGUAGE"; then
                :
            fi
            mode_result=$?
            if [ "$mode_result" -eq 1 ]; then
                pick_top_level_subdir "$BASE"
            elif [ "$mode_result" -eq 2 ]; then
                prompt_relative_subpath "$BASE"
            fi
        fi
        TARGET="$BASE/$TARGET_SUBDIR/$NAME"
        ;;
    alias)
        if [ -z "${TARGET_SUBDIR:-}" ]; then
            if pick_subdir_mode "alias"; then
                :
            fi
            mode_result=$?
            if [ "$mode_result" -eq 1 ]; then
                pick_top_level_subdir "$ALIAS_BASE"
            elif [ "$mode_result" -eq 2 ]; then
                prompt_relative_subpath "$ALIAS_BASE"
            fi
        fi
        TARGET="$ALIAS_BASE/$TARGET_SUBDIR/$NAME"
        ;;
    *)
        echo "Invalid target mode."
        exit 1
        ;;
esac

TARGET="$(normalize_target_path "$TARGET")"

if [ -e "$TARGET" ] && [ "$FORCE_OVERWRITE" -ne 1 ]; then
    echo "File already exists: $TARGET"
    echo "Use -f to overwrite."
    exit 1
fi

SCRIPT_NAME="$(basename "$TARGET")"
FULL_PATH="$TARGET"
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"

if [ "$NO_TEMPLATE" -eq 0 ] && [ ! -f "$TEMPLATE" ]; then
    echo "Template file not found: $TEMPLATE"
    exit 1
fi

{
    language_shebang "$LANGUAGE"
    printf '\n'
    if [ "$NO_TEMPLATE" -eq 0 ]; then
        sed \
            -e "s|__SCRIPT_NAME__|$SCRIPT_NAME|g" \
            -e "s|__DATE__|$DATE_NOW|g" \
            -e "s|__FULL_PATH__|$FULL_PATH|g" \
            "$TEMPLATE"
    fi
} > "$TARGET"

chmod +x "$TARGET"

echo "Created: $TARGET"

if [ "$OPEN_EDITOR" -eq 1 ]; then
    nano "$TARGET"
fi
