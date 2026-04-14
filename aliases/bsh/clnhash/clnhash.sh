#!/usr/bin/env bash
# Script Name: clnhash.sh
# ID: SCR-ID-20260317130340-CMU5606YPK
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: clnhash

# clnhash / hashcleaner
#
# Features:
#   -h            Show help
#   -l            List assigned/default settings
#   -e            Edit saved settings
#   -a            Use active/current directory instead of saved default directory
#   -u            Undo last output file created by this script
#   -f FILE       Use a specific input file directly
#   -d DIR        Use a specific directory directly
#   -t TYPE       Hash type to keep (example: $pkzip$)
#   -k MODE       Keep mode: first or all
#   -o NAME       Output filename (default comes from config)
#
# Config stored in:
#   /d/scr-pac/bash/logs/.hashcleaner.conf
#
# Undo metadata stored in:
#   /d/scr-pac/bash/logs/.hashcleaner_last_undo

set -u

SCRIPT_NAME="$(basename "$0")"
LOGDIR="/d/scr-pac/bash/logs"
CONFIG_FILE="$LOGDIR/.hashcleaner.conf"
UNDO_FILE="$LOGDIR/.hashcleaner_last_undo"

mkdir -p "$LOGDIR"

# -----------------------------
# Defaults
# -----------------------------
FALLBACK_DEFAULT_DIR="/d/scr-pac/bash/lib"
FALLBACK_DEFAULT_HASH_FILE="hashes.txt"
FALLBACK_DEFAULT_OUT_NAME="cleaned_hashes.txt"

DEFAULT_DIR="$FALLBACK_DEFAULT_DIR"
DEFAULT_HASH_FILE="$FALLBACK_DEFAULT_HASH_FILE"
DEFAULT_OUT_NAME="$FALLBACK_DEFAULT_OUT_NAME"

# -----------------------------
# Helpers
# -----------------------------
die() {
    echo "❌ $1" >&2
    exit 1
}

info() {
    echo "▶ $1"
}

success() {
    echo "✅ $1"
}

warn() {
    echo "⚠ $1"
}

pause_if_needed() {
    :
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE"
    fi

    DEFAULT_DIR="${DEFAULT_DIR:-$FALLBACK_DEFAULT_DIR}"
    DEFAULT_HASH_FILE="${DEFAULT_HASH_FILE:-$FALLBACK_DEFAULT_HASH_FILE}"
    DEFAULT_OUT_NAME="${DEFAULT_OUT_NAME:-$FALLBACK_DEFAULT_OUT_NAME}"
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
DEFAULT_DIR="$DEFAULT_DIR"
DEFAULT_HASH_FILE="$DEFAULT_HASH_FILE"
DEFAULT_OUT_NAME="$DEFAULT_OUT_NAME"
EOF
}

show_help() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -h            Show this help menu
  -l            List assigned/default settings
  -e            Edit saved settings
  -a            Use active/current directory
  -u            Undo last output created by this script
  -f FILE       Use a specific input file
  -d DIR        Use a specific directory
  -t TYPE       Hash type to keep (example: \$pkzip\$)
  -k MODE       Keep mode: first | all
  -o NAME       Output filename

What it does:
  - Scans a selected file for hash markers like \$pkzip\$, \$zip2\$, etc.
  - Lets you keep either the first matching line or all matching lines
  - Saves cleaned output into the logs directory

Saved config:
  $CONFIG_FILE

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME -a
  $SCRIPT_NAME -l
  $SCRIPT_NAME -e
  $SCRIPT_NAME -a -f dump.txt -t '\$pkzip\$' -k all
  $SCRIPT_NAME -d /mnt/c/scr/hashfiles -o result.txt
  $SCRIPT_NAME -u
EOF
}

list_settings() {
    cat <<EOF
Assigned / saved settings:
  LOGDIR:             $LOGDIR
  CONFIG_FILE:        $CONFIG_FILE
  DEFAULT_DIR:        $DEFAULT_DIR
  DEFAULT_HASH_FILE:  $DEFAULT_HASH_FILE
  DEFAULT_OUT_NAME:   $DEFAULT_OUT_NAME
  UNDO_FILE:          $UNDO_FILE
EOF
}

edit_settings() {
    echo "Current saved settings:"
    echo "  1) Default directory       : $DEFAULT_DIR"
    echo "  2) Default hash filename   : $DEFAULT_HASH_FILE"
    echo "  3) Default output filename : $DEFAULT_OUT_NAME"
    echo

    read -r -p "New default directory [$DEFAULT_DIR]: " new_dir
    new_dir="${new_dir:-$DEFAULT_DIR}"

    if [ ! -d "$new_dir" ]; then
        warn "Directory does not exist. Keeping previous value: $DEFAULT_DIR"
        new_dir="$DEFAULT_DIR"
    fi

    read -r -p "New default hash filename [$DEFAULT_HASH_FILE]: " new_hash_file
    new_hash_file="${new_hash_file:-$DEFAULT_HASH_FILE}"

    read -r -p "New default output filename [$DEFAULT_OUT_NAME]: " new_out_name
    new_out_name="${new_out_name:-$DEFAULT_OUT_NAME}"

    DEFAULT_DIR="$new_dir"
    DEFAULT_HASH_FILE="$new_hash_file"
    DEFAULT_OUT_NAME="$new_out_name"

    save_config
    success "Settings updated."
    list_settings
}

undo_last_output() {
    if [ ! -f "$UNDO_FILE" ]; then
        die "No undo information found."
    fi

    last_output="$(cat "$UNDO_FILE")"

    if [ -z "$last_output" ]; then
        die "Undo file is empty."
    fi

    if [ -f "$last_output" ]; then
        rm -f -- "$last_output" || die "Failed to remove: $last_output"
        success "Removed last output file: $last_output"
        : > "$UNDO_FILE"
    else
        warn "Last output file no longer exists: $last_output"
        : > "$UNDO_FILE"
    fi
}

select_file_from_directory() {
    local target_dir="$1"
    local default_pick="$2"

    [ -d "$target_dir" ] || die "Directory not found: $target_dir"

    mapfile -t files < <(find "$target_dir" -maxdepth 1 -type f -printf '%f\n' | sort)

    if [ "${#files[@]}" -eq 0 ]; then
        die "No regular files found in: $target_dir"
    fi

    echo
    echo "Files in: $target_dir"
    local i=1
    for file in "${files[@]}"; do
        printf "  %2d) %s\n" "$i" "$file"
        i=$((i + 1))
    done
    echo

    if [ -n "$default_pick" ] && [ -f "$target_dir/$default_pick" ]; then
        read -r -p "Select file number or press Enter for [$default_pick]: " selection
        if [ -z "$selection" ]; then
            echo "$default_pick"
            return 0
        fi
    else
        read -r -p "Select file number: " selection
    fi

    [[ "$selection" =~ ^[0-9]+$ ]] || die "Invalid selection."

    if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#files[@]}" ]; then
        die "Selection out of range."
    fi

    echo "${files[$((selection - 1))]}"
}

detect_hash_markers() {
    local input_file="$1"
    grep -o '\$[[:alnum:]_./-]\+\$' "$input_file" | sort -u
}

prompt_for_hash_type() {
    local input_file="$1"

    echo
    info "Detected hash markers in $input_file:"
    markers="$(detect_hash_markers "$input_file" || true)"

    if [ -n "$markers" ]; then
        echo "$markers"
    else
        warn "No \$---\$ style markers were detected automatically."
    fi
    echo

    read -r -p "Enter hash type to keep (example: \$pkzip\$): " chosen
    [ -n "$chosen" ] || die "Hash type cannot be empty."
    echo "$chosen"
}

prompt_for_keep_mode() {
    read -r -p "Keep first match or all? [first/all] (default: first): " mode
    mode="${mode:-first}"

    case "$mode" in
        first|all) ;;
        *) die "Invalid keep mode: $mode. Use 'first' or 'all'." ;;
    esac

    echo "$mode"
}

sanitize_output_name() {
    local name="$1"
    name="${name##*/}"
    [ -n "$name" ] || die "Invalid output filename."
    echo "$name"
}

# -----------------------------
# Load config first
# -----------------------------
load_config

# -----------------------------
# Flag parsing
# -----------------------------
USE_ACTIVE_DIR=0
RUN_EDIT=0
RUN_LIST=0
RUN_UNDO=0

INPUT_FILE=""
TARGET_DIR=""
HASH_TYPE=""
KEEP_MODE=""
OUTPUT_NAME=""

while getopts ":hlauef:d:t:k:o:" opt; do
    case "$opt" in
        h) show_help; exit 0 ;;
        l) RUN_LIST=1 ;;
        e) RUN_EDIT=1 ;;
        a) USE_ACTIVE_DIR=1 ;;
        u) RUN_UNDO=1 ;;
        f) INPUT_FILE="$OPTARG" ;;
        d) TARGET_DIR="$OPTARG" ;;
        t) HASH_TYPE="$OPTARG" ;;
        k) KEEP_MODE="$OPTARG" ;;
        o) OUTPUT_NAME="$OPTARG" ;;
        \?) die "Unknown option: -$OPTARG" ;;
        :) die "Option -$OPTARG requires an argument." ;;
    esac
done

shift $((OPTIND - 1))

# -----------------------------
# Single-action flags
# -----------------------------
if [ "$RUN_LIST" -eq 1 ]; then
    list_settings
    exit 0
fi

if [ "$RUN_EDIT" -eq 1 ]; then
    edit_settings
    exit 0
fi

if [ "$RUN_UNDO" -eq 1 ]; then
    undo_last_output
    exit 0
fi

# -----------------------------
# Determine working directory
# -----------------------------
if [ -n "$TARGET_DIR" ]; then
    WORK_DIR="$TARGET_DIR"
elif [ "$USE_ACTIVE_DIR" -eq 1 ]; then
    WORK_DIR="$(pwd)"
else
    WORK_DIR="$DEFAULT_DIR"
fi

[ -d "$WORK_DIR" ] || die "Directory not found: $WORK_DIR"

# -----------------------------
# Determine input file
# -----------------------------
if [ -n "$INPUT_FILE" ]; then
    if [ -f "$INPUT_FILE" ]; then
        FULL_INPUT_FILE="$INPUT_FILE"
        WORK_DIR="$(cd "$(dirname "$FULL_INPUT_FILE")" && pwd)"
        INPUT_BASENAME="$(basename "$FULL_INPUT_FILE")"
    elif [ -f "$WORK_DIR/$INPUT_FILE" ]; then
        FULL_INPUT_FILE="$WORK_DIR/$INPUT_FILE"
        INPUT_BASENAME="$INPUT_FILE"
    else
        die "Input file not found: $INPUT_FILE"
    fi
else
    INPUT_BASENAME="$(select_file_from_directory "$WORK_DIR" "$DEFAULT_HASH_FILE")"
    FULL_INPUT_FILE="$WORK_DIR/$INPUT_BASENAME"
fi

[ -f "$FULL_INPUT_FILE" ] || die "Selected file does not exist: $FULL_INPUT_FILE"

# -----------------------------
# Determine hash type and keep mode
# -----------------------------
if [ -z "$HASH_TYPE" ]; then
    HASH_TYPE="$(prompt_for_hash_type "$FULL_INPUT_FILE")"
fi

if [ -z "$KEEP_MODE" ]; then
    KEEP_MODE="$(prompt_for_keep_mode)"
fi

case "$KEEP_MODE" in
    first|all) ;;
    *) die "Invalid keep mode: $KEEP_MODE. Use 'first' or 'all'." ;;
esac

# -----------------------------
# Determine output name
# -----------------------------
if [ -z "$OUTPUT_NAME" ]; then
    OUTPUT_NAME="$DEFAULT_OUT_NAME"
fi

OUTPUT_NAME="$(sanitize_output_name "$OUTPUT_NAME")"
OUTFILE="$LOGDIR/$OUTPUT_NAME"

# Prevent silent overwrite
if [ -f "$OUTFILE" ]; then
    timestamp="$(date +"%Y%m%d-%H%M%S")"
    base="${OUTPUT_NAME%.*}"
    ext="${OUTPUT_NAME##*.}"

    if [ "$base" = "$ext" ]; then
        OUTFILE="$LOGDIR/${OUTPUT_NAME}_${timestamp}"
    else
        OUTFILE="$LOGDIR/${base}_${timestamp}.${ext}"
    fi
fi

# -----------------------------
# Extract hashes
# -----------------------------
info "Input file: $FULL_INPUT_FILE"
info "Working directory: $WORK_DIR"
info "Hash type: $HASH_TYPE"
info "Keep mode: $KEEP_MODE"
info "Output file: $OUTFILE"

if [ "$KEEP_MODE" = "first" ]; then
    grep -m 1 -F "$HASH_TYPE" "$FULL_INPUT_FILE" > "$OUTFILE" || true
else
    grep -F "$HASH_TYPE" "$FULL_INPUT_FILE" > "$OUTFILE" || true
fi

# -----------------------------
# Result handling + undo record
# -----------------------------
if [ -s "$OUTFILE" ]; then
    echo "$OUTFILE" > "$UNDO_FILE"
    success "Saved $KEEP_MODE matching hash line(s) to: $OUTFILE"
    success "Undo is available with: $SCRIPT_NAME -u"
else
    rm -f -- "$OUTFILE"
    warn "No lines found with hash type $HASH_TYPE in: $FULL_INPUT_FILE"
fiy

