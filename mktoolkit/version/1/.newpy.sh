#!/usr/bin/env bash

set -u

BASE_PY="/mnt/c/scr/zpy"
BASE_ALIAS="/mnt/c/scr/aliases/lib/act"
TEMPLATE_FILE="$BASE_PY/.template.txt"

OPEN_EDITOR=0
NO_TEMPLATE=0
FORCE_OVERWRITE=0
TARGET_MODE=""
TARGET_SUBDIR=""
NAME=""

show_help() {
    cat << EOF
Usage:
  .newpy.sh [options] <name>

Modes:
  No mode given        Interactive menu
  -c                   Create in current working directory
  -p <subdir>          Create in Python tree: $BASE_PY/<subdir>
  -a <subdir>          Create in alias tree: $BASE_ALIAS/<subdir>

Options:
  -e                   Open in \$EDITOR after creation
  -n                   No template, shebang only
  -f                   Overwrite if file exists
  -h                   Show help

Examples:
  .newpy.sh zipcomb
  .newpy.sh -c testtool
  .newpy.sh -p file-ops zipcomb
  .newpy.sh -p file-ops/zipper/lib3 zipcomb
  .newpy.sh -a basic finder
  .newpy.sh -e zipcomb
EOF
}

pick_main_mode() {
    local choice
    echo "Create Python script in:"
    echo "  1) Current directory"
    echo "  2) Python tree ($BASE_PY)"
    echo "  3) Alias tree ($BASE_ALIAS)"
    echo "  0) Cancel"

    while true; do
        read -rp "Enter number: " choice
        case "$choice" in
            1)
                TARGET_MODE="cwd"
                return 0
                ;;
            2)
                TARGET_MODE="python"
                return 0
                ;;
            3)
                TARGET_MODE="alias"
                return 0
                ;;
            0)
                echo "Cancelled."
                exit 0
                ;;
            *)
                echo "Invalid choice."
                ;;
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
            0)
                echo "Cancelled."
                exit 0
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done
}

pick_top_level_subdir() {
    local base="$1"
    local label="$2"
    local dirs=()
    local i choice

    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(
        find "$base" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
    )

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
    local label="$2"
    local input

    echo "Enter relative path under $base"
    echo "Examples:"
    echo "  file-ops"
    echo "  file-ops/zipper/lib3"
    echo "  yt/lib"
    echo "  pass/lib/frag2"
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

ensure_py_extension() {
    local name="$1"
    if [[ "$name" == *.py ]]; then
        printf "%s" "$name"
    else
        printf "%s.py" "$name"
    fi
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

while [ $# -gt 0 ]; do
    case "$1" in
        -c)
            TARGET_MODE="cwd"
            shift
            ;;
        -p)
            shift
            [ $# -eq 0 ] && echo "Missing subdir after -p" && exit 1
            TARGET_MODE="python"
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
        -n)
            NO_TEMPLATE=1
            shift
            ;;
        -f)
            FORCE_OVERWRITE=1
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

[ $# -eq 0 ] && echo "Missing script name. Use -h for help." && exit 1
NAME="$(ensure_py_extension "$1")"

if [ -z "$TARGET_MODE" ]; then
    pick_main_mode
fi

case "$TARGET_MODE" in
    cwd)
        TARGET="$(pwd)/$NAME"
        ;;
    python)
        if [ -z "${TARGET_SUBDIR:-}" ]; then
            if pick_subdir_mode "Python"; then
                :
            fi
            mode_result=$?
            if [ "$mode_result" -eq 1 ]; then
                pick_top_level_subdir "$BASE_PY" "Python"
            elif [ "$mode_result" -eq 2 ]; then
                prompt_relative_subpath "$BASE_PY" "Python"
            fi
        fi
        TARGET="$BASE_PY/$TARGET_SUBDIR/$NAME"
        ;;
    alias)
        if [ -z "${TARGET_SUBDIR:-}" ]; then
            if pick_subdir_mode "Alias"; then
                :
            fi
            mode_result=$?
            if [ "$mode_result" -eq 1 ]; then
                pick_top_level_subdir "$BASE_ALIAS" "Alias"
            elif [ "$mode_result" -eq 2 ]; then
                prompt_relative_subpath "$BASE_ALIAS" "Alias"
            fi
        fi
        TARGET="$BASE_ALIAS/$TARGET_SUBDIR/$NAME"
        ;;
    *)
        echo "Invalid or missing target mode."
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

if [ "$NO_TEMPLATE" -eq 0 ] && [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

{
    printf '%s\n\n' '#!/usr/bin/env python3'

    if [ "$NO_TEMPLATE" -eq 0 ]; then
        sed \
            -e "s|__SCRIPT_NAME__|$SCRIPT_NAME|g" \
            -e "s|__DATE__|$DATE_NOW|g" \
            -e "s|__FULL_PATH__|$FULL_PATH|g" \
            "$TEMPLATE_FILE"
    fi
} > "$TARGET"

chmod +x "$TARGET"

echo "Created: $TARGET"

if [ "$OPEN_EDITOR" -eq 1 ]; then
    "${EDITOR:-vim}" "$TARGET"
fi
