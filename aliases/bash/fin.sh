#!/usr/bin/env bash
# Script Name: fin.sh
# ID: SCR-ID-20260326023526-KSUYNX1Z5R
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: fin

# findp.sh
# Recursive file search helper with:
# - saved default directories
# - all-defaults search
# - current-working-directory search
# - custom path search
# - case-insensitive matching
# - partial matching
# - extension filters
# - clipboard copy
# - optional opening of results
# - partial-search result output to file
# - clean machine-friendly output mode
# - txt/csv output
# - CSV activity logging
# - auto-save all results when output mode is used
#
# Run via resolver as:
#   findp

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.find_config"
LOG_DIR="$SCRIPT_DIR/log"
LOG_FILE="$LOG_DIR/find_log.csv"
CLIP="/mnt/c/Windows/System32/clip.exe"

mkdir -p "$LOG_DIR"

if [ ! -f "$LOG_FILE" ]; then
    echo 'timestamp,action,search_mode,search_dirs,pattern,partial,case_insensitive,extensions,result_count,notes' > "$LOG_FILE"
fi

DEFAULT_DIRS=()

load_defaults() {
    DEFAULT_DIRS=()
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && DEFAULT_DIRS+=("$line")
        done < "$CONFIG_FILE"
    fi

    if [ "${#DEFAULT_DIRS[@]}" -eq 0 ]; then
        DEFAULT_DIRS=(".")
    fi
}

save_defaults() {
    : > "$CONFIG_FILE"
    for dir in "$@"; do
        printf "%s\n" "$dir" >> "$CONFIG_FILE"
    done
}

csv_escape() {
    local s="${1//\"/\"\"}"
    printf '"%s"' "$s"
}

join_by() {
    local delim="$1"
    shift
    local first=1
    local item
    for item in "$@"; do
        if [ $first -eq 1 ]; then
            printf "%s" "$item"
            first=0
        else
            printf "%s%s" "$delim" "$item"
        fi
    done
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf "%s" "$s"
}

log_action() {
    local action="$1"
    local mode="$2"
    local dirs="$3"
    local pattern="$4"
    local partial="$5"
    local casei="$6"
    local exts="$7"
    local count="$8"
    local notes="$9"

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(csv_escape "$(date '+%Y-%m-%d %H:%M:%S')")" \
        "$(csv_escape "$action")" \
        "$(csv_escape "$mode")" \
        "$(csv_escape "$dirs")" \
        "$(csv_escape "$pattern")" \
        "$(csv_escape "$partial")" \
        "$(csv_escape "$casei")" \
        "$(csv_escape "$exts")" \
        "$(csv_escape "$count")" \
        "$(csv_escape "$notes")" \
        >> "$LOG_FILE"
}

show_help() {
    load_defaults
    cat << EOF
Usage:
  fin <filename>
      Search in primary saved default directory

  fin -af <filename>
      Search in all saved default directories

  fin -cwd <filename>
      Search in current working directory

  fin <path> <filename>
      Search in one custom path

  fin -e <dir1> [dir2 dir3 ...]
      Save one or more default directories

  fin -d
      Show saved default directories

  fin -l
      Show log file location

  fin [options] <filename>
  fin [options] <path> <filename>

Options:
  -af              Search all saved default directories
  -cwd             Search current working directory
  -ai              Case-insensitive match
  -p               Partial match + save report to script log folder
  -p-clean         Partial match + save clean raw result list to script log folder
  -pd DIR          Partial match + save report to specified directory
  -pa              Partial match + save report to current directory
  -pd-clean DIR    Partial match + save clean raw result list to specified directory
  -ext TYPE        Output format for saved results: txt or csv (default: txt)
  -x EXT[,EXT]     Filter by extension(s), e.g. zip or zip,7z,rar
  --open           Open selected result(s)
  -nr              No clipboard copy
  -h               Show help

Examples:
  fin main.rb
  fin -af example.zip
  fin -cwd example.zip
  fin -ai -p report
  fin -p report
  fin -p-clean report
  fin -p -ext csv report
  fin -pd /mnt/c/scr/results report
  fin -pa report
  fin -pd-clean /mnt/c/scr/aliases/tools/findp find0.sh
  fin -pd-clean /mnt/c/scr/aliases/tools/findp -ext csv find0.sh
  fin -af -p-clean findp.sh
  fin -af -pd-clean /mnt/c/scr/swap/ find0.sh
  fin -x zip backup
  fin -x zip,7z,rar -af archive
  fin /c/scr findp.sh
  fin -e /c/scr /d/projects /home/walker/Desktop
  fin -d
  fin -l

Saved default directories:
$(for d in "${DEFAULT_DIRS[@]}"; do echo "  - $d"; done)

Script directory:
  $SCRIPT_DIR

Log file:
  $LOG_FILE
EOF
}

open_path() {
    local path="$1"

    if command -v wslview >/dev/null 2>&1; then
        wslview "$path" >/dev/null 2>&1 &
        return 0
    fi

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$path" >/dev/null 2>&1 &
        return 0
    fi

    if command -v explorer.exe >/dev/null 2>&1; then
        explorer.exe "$(wslpath -w "$path")" >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

make_output_file_path() {
    local out_dir="$1"
    local out_ext="$2"
    local stamp

    stamp="$(date '+%Y-%m-%d_%H-%M-%S')"

    mkdir -p "$out_dir" || return 1
    printf "%s/%s.%s" "$out_dir" "$stamp" "$out_ext"
}

write_output_txt() {
    local output_file="$1"
    local pattern="$2"
    local mode="$3"
    local search_dirs="$4"
    shift 4

    mkdir -p "$(dirname "$output_file")" || return 1

    {
        echo "Search Pattern : $pattern"
        echo "Search Mode    : $mode"
        echo "Search Dirs    : $search_dirs"
        echo "Timestamp      : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Result Count   : $#"
        echo
        echo "Results"
        echo "----------------------------------------"
        echo

        local item
        for item in "$@"; do
            echo "$item"
        done
    } > "$output_file"
}

write_output_csv() {
    local output_file="$1"
    local pattern="$2"
    local mode="$3"
    local search_dirs="$4"
    shift 4

    mkdir -p "$(dirname "$output_file")" || return 1

    {
        printf '%s,%s\n' \
            "$(csv_escape "field")" \
            "$(csv_escape "value")"

        printf '%s,%s\n' \
            "$(csv_escape "search_pattern")" \
            "$(csv_escape "$pattern")"

        printf '%s,%s\n' \
            "$(csv_escape "search_mode")" \
            "$(csv_escape "$mode")"

        printf '%s,%s\n' \
            "$(csv_escape "search_dirs")" \
            "$(csv_escape "$search_dirs")"

        printf '%s,%s\n' \
            "$(csv_escape "timestamp")" \
            "$(csv_escape "$(date '+%Y-%m-%d %H:%M:%S')")"

        printf '%s,%s\n' \
            "$(csv_escape "result_count")" \
            "$(csv_escape "$#")"

        echo
        printf '%s\n' "$(csv_escape "result_path")"

        local item
        for item in "$@"; do
            printf '%s\n' "$(csv_escape "$item")"
        done
    } > "$output_file"
}

write_output_clean_txt() {
    local output_file="$1"
    shift

    mkdir -p "$(dirname "$output_file")" || return 1
    printf "%s\n" "$@" > "$output_file"
}

write_output_clean_csv() {
    local output_file="$1"
    shift

    mkdir -p "$(dirname "$output_file")" || return 1

    {
        printf '%s\n' "$(csv_escape "path")"
        local item
        for item in "$@"; do
            printf '%s\n' "$(csv_escape "$item")"
        done
    } > "$output_file"
}

write_output_clean() {
    local output_file="$1"
    local out_ext="$2"
    shift 2

    case "$out_ext" in
        txt) write_output_clean_txt "$output_file" "$@" ;;
        csv) write_output_clean_csv "$output_file" "$@" ;;
        *)   return 1 ;;
    esac
}

write_output_file() {
    local output_file="$1"
    local out_ext="$2"
    local pattern="$3"
    local mode="$4"
    local search_dirs="$5"
    shift 5

    case "$out_ext" in
        txt) write_output_txt "$output_file" "$pattern" "$mode" "$search_dirs" "$@" ;;
        csv) write_output_csv "$output_file" "$pattern" "$mode" "$search_dirs" "$@" ;;
        *)   return 1 ;;
    esac
}

load_defaults

# -----------------------
# Early flags
# -----------------------
[ "${1:-}" = "-h" ] && show_help && exit 0

if [ "${1:-}" = "-d" ]; then
    echo "Saved default directories:"
    for d in "${DEFAULT_DIRS[@]}"; do
        echo "  - $d"
    done
    exit 0
fi

if [ "${1:-}" = "-l" ]; then
    echo "Log file: $LOG_FILE"
    exit 0
fi

if [ "${1:-}" = "-e" ]; then
    shift
    [ $# -eq 0 ] && echo "Please provide at least one directory." && exit 1

    VALID_DIRS=()
    local_dir=""
    for local_dir in "$@"; do
        if [ -d "$local_dir" ]; then
            VALID_DIRS+=("$(cd "$local_dir" && pwd)")
        else
            echo "Skipping invalid directory: $local_dir"
        fi
    done

    if [ "${#VALID_DIRS[@]}" -eq 0 ]; then
        echo "No valid directories provided."
        exit 1
    fi

    save_defaults "${VALID_DIRS[@]}"

    echo "Saved default directories:"
    for d in "${VALID_DIRS[@]}"; do
        echo "  - $d"
    done

    log_action \
        "set_defaults" \
        "config" \
        "$(join_by " | " "${VALID_DIRS[@]}")" \
        "" "" "" "" \
        "${#VALID_DIRS[@]}" \
        "Updated default search directories"

    exit 0
fi

# -----------------------
# Parse options
# -----------------------
SEARCH_ALL_DEFAULTS=0
SEARCH_CWD=0
CASE_INSENSITIVE=0
PARTIAL_MATCH=0
OPEN_RESULTS=0
NO_CLIPBOARD=0
WRITE_OUTPUT=0
CLEAN_OUTPUT=0
OUTPUT_DIR=""
OUTPUT_EXT="txt"
EXT_FILTER_RAW=""

POSITIONAL=()

while [ $# -gt 0 ]; do
    case "$1" in
        -af)
            SEARCH_ALL_DEFAULTS=1
            shift
            ;;
        -cwd)
            SEARCH_CWD=1
            shift
            ;;
        -ai)
            CASE_INSENSITIVE=1
            shift
            ;;
        -p-clean)
            PARTIAL_MATCH=1
            WRITE_OUTPUT=1
            CLEAN_OUTPUT=1
            OUTPUT_DIR="$LOG_DIR"
            shift
            ;;
        -p)
            PARTIAL_MATCH=1
            WRITE_OUTPUT=1
            OUTPUT_DIR="$LOG_DIR"
            shift
            ;;
        -pd-clean)
            PARTIAL_MATCH=1
            WRITE_OUTPUT=1
            CLEAN_OUTPUT=1
            shift
            [ $# -eq 0 ] && echo "Missing directory for -pd-clean" && exit 1
            OUTPUT_DIR="$1"
            shift
            ;;
        -pd)
            PARTIAL_MATCH=1
            WRITE_OUTPUT=1
            shift
            [ $# -eq 0 ] && echo "Missing directory for -pd" && exit 1
            OUTPUT_DIR="$1"
            shift
            ;;
        -pa)
            PARTIAL_MATCH=1
            WRITE_OUTPUT=1
            OUTPUT_DIR="$(pwd)"
            shift
            ;;
        -ext)
            shift
            [ $# -eq 0 ] && echo "Missing value for -ext" && exit 1
            OUTPUT_EXT="$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')"
            case "$OUTPUT_EXT" in
                txt|csv) ;;
                *)
                    echo "Invalid output format: $OUTPUT_EXT"
                    echo "Allowed values: txt, csv"
                    exit 1
                    ;;
            esac
            shift
            ;;
        -x)
            shift
            [ $# -eq 0 ] && echo "Missing value for -x" && exit 1
            EXT_FILTER_RAW="$1"
            shift
            ;;
        --open)
            OPEN_RESULTS=1
            shift
            ;;
        -nr)
            NO_CLIPBOARD=1
            shift
            ;;
        -h)
            show_help
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [ $# -eq 0 ]; then
    echo "No filename provided. Use -h for help."
    exit 1
fi

# -----------------------
# Determine mode / target
# -----------------------
SEARCH_DIRS=()
PATTERN=""
MODE="primary_default"

if [ "$SEARCH_CWD" -eq 1 ]; then
    SEARCH_DIRS=("$(pwd)")
    PATTERN="$1"
    MODE="cwd"
elif [ $# -ge 2 ] && [ -d "$1" ]; then
    SEARCH_DIRS=("$(cd "$1" && pwd)")
    PATTERN="$2"
    MODE="custom_path"
else
    PATTERN="$1"
    if [ "$SEARCH_ALL_DEFAULTS" -eq 1 ]; then
        SEARCH_DIRS=("${DEFAULT_DIRS[@]}")
        MODE="all_defaults"
    else
        SEARCH_DIRS=("${DEFAULT_DIRS[0]}")
        MODE="primary_default"
    fi
fi

NORMALIZED_SEARCH_DIRS=()
for dir in "${SEARCH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        NORMALIZED_SEARCH_DIRS+=("$(cd "$dir" && pwd)")
    fi
done
SEARCH_DIRS=("${NORMALIZED_SEARCH_DIRS[@]}")

if [ "${#SEARCH_DIRS[@]}" -eq 0 ]; then
    echo "No valid search directories found."
    exit 1
fi

if [ "$WRITE_OUTPUT" -eq 1 ] && [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$LOG_DIR"
fi

SEARCH_DIRS_STR="$(join_by " | " "${SEARCH_DIRS[@]}")"

# -----------------------
# Build search conditions
# -----------------------
FIND_NAME_FLAG="-name"
[ "$CASE_INSENSITIVE" -eq 1 ] && FIND_NAME_FLAG="-iname"

MATCH_PATTERN="$PATTERN"
[ "$PARTIAL_MATCH" -eq 1 ] && MATCH_PATTERN="*${PATTERN}*"

EXTENSIONS=()
if [ -n "$EXT_FILTER_RAW" ]; then
    IFS=',' read -ra RAW_EXTS <<< "$EXT_FILTER_RAW"
    for ext in "${RAW_EXTS[@]}"; do
        ext="$(trim "$ext")"
        ext="${ext#.}"
        [ -n "$ext" ] && EXTENSIONS+=("$ext")
    done
fi

# -----------------------
# Search
# -----------------------
RESULTS=()

for dir in "${SEARCH_DIRS[@]}"; do
    [ -d "$dir" ] || continue

    if [ "${#EXTENSIONS[@]}" -eq 0 ]; then
        while IFS= read -r file; do
            RESULTS+=("$file")
        done < <(command find "$dir" -type f "$FIND_NAME_FLAG" "$MATCH_PATTERN" 2>/dev/null)
    else
        while IFS= read -r file; do
            base="$(basename "$file")"
            name_match=0

            if [ "$CASE_INSENSITIVE" -eq 1 ]; then
                base_lc="$(printf "%s" "$base" | tr '[:upper:]' '[:lower:]')"
                pattern_lc="$(printf "%s" "$MATCH_PATTERN" | tr '[:upper:]' '[:lower:]')"
                case "$base_lc" in
                    $pattern_lc) name_match=1 ;;
                esac
            else
                case "$base" in
                    $MATCH_PATTERN) name_match=1 ;;
                esac
            fi

            if [ "$name_match" -eq 1 ]; then
                lower_file="$(printf "%s" "$file" | tr '[:upper:]' '[:lower:]')"
                for ext in "${EXTENSIONS[@]}"; do
                    lower_ext="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"
                    case "$lower_file" in
                        *".${lower_ext}")
                            RESULTS+=("$file")
                            break
                            ;;
                    esac
                done
            fi
        done < <(command find "$dir" -type f 2>/dev/null)
    fi
done

if [ "${#RESULTS[@]}" -gt 0 ]; then
    mapfile -t RESULTS < <(printf "%s\n" "${RESULTS[@]}" | awk '!seen[$0]++')
fi

EXTS_STR="$(join_by "," "${EXTENSIONS[@]}")"

if [ "${#RESULTS[@]}" -eq 0 ]; then
    echo "No files found."
    echo "Pattern: $PATTERN"
    echo "Search dirs:"
    for d in "${SEARCH_DIRS[@]}"; do
        echo "  $d"
    done

    log_action \
        "search" \
        "$MODE" \
        "$SEARCH_DIRS_STR" \
        "$PATTERN" \
        "$PARTIAL_MATCH" \
        "$CASE_INSENSITIVE" \
        "$EXTS_STR" \
        "0" \
        "No results"

    exit 0
fi

# -----------------------
# Single result
# -----------------------
if [ "${#RESULTS[@]}" -eq 1 ]; then
    OUTPUT_NOTE="Single result"

    echo "${RESULTS[0]}"

    if [ "$NO_CLIPBOARD" -eq 0 ]; then
        if [ -x "$CLIP" ]; then
            printf "%s" "${RESULTS[0]}" | "$CLIP"
            echo "Copied to clipboard!"
        else
            echo "Clipboard tool not found: $CLIP"
        fi
    fi

    if [ "$WRITE_OUTPUT" -eq 1 ]; then
        OUTPUT_FILE="$(make_output_file_path "$OUTPUT_DIR" "$OUTPUT_EXT")"

        if [ "$CLEAN_OUTPUT" -eq 1 ]; then
            if write_output_clean "$OUTPUT_FILE" "$OUTPUT_EXT" "${RESULTS[0]}"; then
                echo "Saved clean output to: $OUTPUT_FILE"
                OUTPUT_NOTE="$OUTPUT_NOTE | Clean output file: $OUTPUT_FILE"
            else
                echo "Could not write clean output file."
                OUTPUT_NOTE="$OUTPUT_NOTE | Clean output file write failed"
            fi
        else
            if write_output_file "$OUTPUT_FILE" "$OUTPUT_EXT" "$PATTERN" "$MODE" "$SEARCH_DIRS_STR" "${RESULTS[0]}"; then
                echo "Saved output to: $OUTPUT_FILE"
                OUTPUT_NOTE="$OUTPUT_NOTE | Output file: $OUTPUT_FILE"
            else
                echo "Could not write output file."
                OUTPUT_NOTE="$OUTPUT_NOTE | Output file write failed"
            fi
        fi
    fi

    if [ "$OPEN_RESULTS" -eq 1 ]; then
        if open_path "${RESULTS[0]}"; then
            echo "Opened result."
        else
            echo "Could not open result."
        fi
    fi

    log_action \
        "search" \
        "$MODE" \
        "$SEARCH_DIRS_STR" \
        "$PATTERN" \
        "$PARTIAL_MATCH" \
        "$CASE_INSENSITIVE" \
        "$EXTS_STR" \
        "1" \
        "$OUTPUT_NOTE"

    exit 0
fi

# -----------------------
# Multiple results
# -----------------------
echo "Found multiple results:"
for i in "${!RESULTS[@]}"; do
    printf "%d: %s\n" $((i + 1)) "${RESULTS[$i]}"
done

SELECTED=()

if [ "$WRITE_OUTPUT" -eq 1 ]; then
    SELECTED=("${RESULTS[@]}")
    echo "Output flag detected. Saving all results by default."
else
    read -rp "Enter number(s) to copy/open/save (comma-separated) or 'a' for all: " CHOICE

    if [ "$CHOICE" = "a" ]; then
        SELECTED=("${RESULTS[@]}")
    else
        IFS=',' read -ra NUMS <<< "$CHOICE"
        for n in "${NUMS[@]}"; do
            n="$(trim "$n")"
            if [[ "$n" =~ ^[0-9]+$ ]]; then
                idx=$((n - 1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#RESULTS[@]}" ]; then
                    SELECTED+=("${RESULTS[$idx]}")
                fi
            fi
        done
    fi
fi

if [ "${#SELECTED[@]}" -eq 0 ]; then
    echo "No valid selection made."

    log_action \
        "search" \
        "$MODE" \
        "$SEARCH_DIRS_STR" \
        "$PATTERN" \
        "$PARTIAL_MATCH" \
        "$CASE_INSENSITIVE" \
        "$EXTS_STR" \
        "${#RESULTS[@]}" \
        "Multiple results, no valid selection"

    exit 1
fi

printf "%s\n" "${SELECTED[@]}"

OUTPUT_NOTE="Selected from multiple results"

if [ "$NO_CLIPBOARD" -eq 0 ]; then
    if [ -x "$CLIP" ]; then
        printf "%s\n" "${SELECTED[@]}" | "$CLIP"
        echo "Selected result(s) copied to clipboard!"
    else
        echo "Clipboard tool not found: $CLIP"
    fi
fi

if [ "$WRITE_OUTPUT" -eq 1 ]; then
    OUTPUT_FILE="$(make_output_file_path "$OUTPUT_DIR" "$OUTPUT_EXT")"

    if [ "$CLEAN_OUTPUT" -eq 1 ]; then
        if write_output_clean "$OUTPUT_FILE" "$OUTPUT_EXT" "${SELECTED[@]}"; then
            echo "Saved clean output to: $OUTPUT_FILE"
            OUTPUT_NOTE="$OUTPUT_NOTE | Clean output file: $OUTPUT_FILE"
        else
            echo "Could not write clean output file."
            OUTPUT_NOTE="$OUTPUT_NOTE | Clean output file write failed"
        fi
    else
        if write_output_file "$OUTPUT_FILE" "$OUTPUT_EXT" "$PATTERN" "$MODE" "$SEARCH_DIRS_STR" "${SELECTED[@]}"; then
            echo "Saved output to: $OUTPUT_FILE"
            OUTPUT_NOTE="$OUTPUT_NOTE | Output file: $OUTPUT_FILE"
        else
            echo "Could not write output file."
            OUTPUT_NOTE="$OUTPUT_NOTE | Output file write failed"
        fi
    fi
fi

if [ "$OPEN_RESULTS" -eq 1 ]; then
    for item in "${SELECTED[@]}"; do
        if open_path "$item"; then
            echo "Opened: $item"
        else
            echo "Could not open: $item"
        fi
    done
fi

log_action \
    "search" \
    "$MODE" \
    "$SEARCH_DIRS_STR" \
    "$PATTERN" \
    "$PARTIAL_MATCH" \
    "$CASE_INSENSITIVE" \
    "$EXTS_STR" \
    "${#SELECTED[@]}" \
    "$OUTPUT_NOTE"
