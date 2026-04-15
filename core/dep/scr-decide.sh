#!/usr/bin/env bash

# Script Name: scr-decide.sh
# ID: SCR-ID-20260414184227-168G3719LZ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scr-decide

# SCR Unified CLI

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX="$CORE_DIR/index/commands.map"
OUT="$CORE_DIR/index/generated/core.sh"

# Load runtime
[[ -f "$OUT" ]] && source "$OUT"

# -------------------------
# LOAD MAP
# -------------------------
declare -A SCR_MAP

if [[ -f "$INDEX" ]]; then
    while IFS='=' read -r key value; do
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        [[ -z "$key" || -z "$value" ]] && continue

        if [[ -n "${SCR_MAP[$key]}" ]]; then
            SCR_MAP["$key"]+=$'\n'"$value"
        else
            SCR_MAP["$key"]="$value"
        fi
    done < "$INDEX"
fi

# -------------------------
# BUILD SYSTEM
# -------------------------
scr_build() {
    local SCR_ROOT="$(cd "$CORE_DIR/.." && pwd)"
    local ALIAS_ROOT="$SCR_ROOT/aliases"
    local BSH_ROOT="$SCR_ROOT/bsh"

    local OUT_DIR="$CORE_DIR/index/generated"
    local INDEX_DIR="$CORE_DIR/index"
    local MAP="$INDEX_DIR/commands.map"
    local CORE_FILE="$OUT_DIR/core.sh"

    mkdir -p "$OUT_DIR"/{bash,bsh,python,ruby,zsh}
    mkdir -p "$INDEX_DIR"

    echo "[SCR] Building system..."

    safe_name() {
        echo "scr_${1//[^a-zA-Z0-9_]/_}"
    }

    is_reserved() {
        case "$1" in
            time|cd|pwd|eval|exec|echo|read|kill|test|set|unset|export)
                return 0 ;;
        esac
        return 1
    }

    register() {
        local file="$1"
        local ext="$2"
        local out="$3"

        local base func
        base=$(basename "$file" ."$ext")

        is_reserved "$base" && return

        func=$(safe_name "$base")

        case "$ext" in
            sh)  echo "$func() { bash \"$file\" \"\$@\"; }" >> "$out" ;;
            py)  echo "$func() { python3 \"$file\" \"\$@\"; }" >> "$out" ;;
            rb)  echo "$func() { ruby \"$file\" \"\$@\"; }" >> "$out" ;;
            zsh) echo "$func() { zsh \"$file\" \"\$@\"; }" >> "$out" ;;
        esac
    }

    # reset
    : > "$OUT_DIR/bash/aliases.sh"
    : > "$OUT_DIR/bsh/bsh.sh"
    : > "$OUT_DIR/python/tools.sh"
    : > "$OUT_DIR/ruby/tools.sh"
    : > "$OUT_DIR/zsh/tools.sh"
    : > "$CORE_FILE"
    : > "$MAP"

    # build layers (SAFE loop)
    while IFS= read -r f; do
        register "$f" "sh" "$OUT_DIR/bash/aliases.sh"
    done < <(find "$ALIAS_ROOT" -type f -name "*.sh")

    while IFS= read -r f; do
        register "$f" "sh" "$OUT_DIR/bsh/bsh.sh"
    done < <(find "$BSH_ROOT" -type f -name "*.sh")

    while IFS= read -r f; do
        register "$f" "py" "$OUT_DIR/python/tools.sh"
    done < <(find "$SCR_ROOT/zpy" -type f -name "*.py")

    while IFS= read -r f; do
        register "$f" "rb" "$OUT_DIR/ruby/tools.sh"
    done < <(find "$SCR_ROOT/zru" -type f -name "*.rb")

    while IFS= read -r f; do
        register "$f" "zsh" "$OUT_DIR/zsh/tools.sh"
    done < <(find "$ALIAS_ROOT/zsh" -type f -name "*.zsh")

    # build core + map
    for f in "$OUT_DIR"/*/*.sh; do
        [[ -f "$f" ]] || continue
        echo "source \"$f\"" >> "$CORE_FILE"

        name="$(basename "$f" .sh)"
        [[ "$name" != *"generated"* ]] && echo "$name=$f" >> "$MAP"
    done

    echo "[SCR] Build complete"
}

# -------------------------
# PICK FILE
# -------------------------
pick_file() {
    local key="$1"
    local entries="${SCR_MAP[$key]}"

    [[ -z "$entries" ]] && return 1

    if [[ "$entries" != *$'\n'* ]]; then
        echo "$entries"
        return
    fi

    echo "[SCR] Multiple targets for '$key':"
    local i=1
    local options=()

    while IFS= read -r line; do
        printf "  [%d] %s\n" "$i" "$line"
        options+=("$line")
        ((i++))
    done <<< "$entries"

    echo -n "Select: "
    read -r choice

    [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )) || return 1
    echo "${options[$((choice-1))]}"
}

# -------------------------
# RESOLVE FILE
# -------------------------
resolve_file() {
    local name="$1"

    if [[ -n "${SCR_MAP[$name]}" ]]; then
        pick_file "$name"
        return
    fi

    local fn="scr_${name}"

    if declare -f "$fn" >/dev/null 2>&1; then
        local def file
        def="$(declare -f "$fn")"
        file="$(echo "$def" | grep -oE '(bash|python3|ruby|zsh) "[^"]+"' | cut -d'"' -f2)"
        [[ -f "$file" ]] && echo "$file"
        return
    fi

    return 1
}

# -------------------------
# COMMANDS
# -------------------------
cmd_list() {
    echo "== Mapped Commands =="
    for k in "${!SCR_MAP[@]}"; do echo "  $k"; done | sort

    echo ""
    echo "== Runtime Commands =="
    declare -F | awk '{print $3}' | grep '^scr_' | sed 's/^scr_//' | sort
}

cmd_which() {
    local file
    file="$(resolve_file "$1")"
    [[ -n "$file" ]] && echo "$file" || echo "[SCR] Not found: $1"
}

cmd_find() {
    (
        for k in "${!SCR_MAP[@]}"; do echo "$k"; done
        declare -F | awk '{print $3}' | grep '^scr_' | sed 's/^scr_//'
    ) | sort | grep -i "$1"
}

# -------------------------
# HELP
# -------------------------
help() {
cat <<EOF
SCR Unified CLI

Usage:
  scr [mode] <command>

Modes:
  -e        Edit
  -v        View
  -c        Cd into directory
  -w        Which (show path)
  -l        List commands
  -f <pat>  Find command
  -set      Rebuild system
  -h        Help
EOF
}

# -------------------------
# PARSE
# -------------------------
mode=""
pattern=""

while [[ "$1" == -* ]]; do
    case "$1" in
        -e) mode="edit" ;;
        -v) mode="view" ;;
        -c) mode="cd" ;;
        -w) mode="which" ;;
        -l) mode="list" ;;
        -f) mode="find"; shift; pattern="$1" ;;
        -set) mode="build" ;;
        -h) help; return 0 2>/dev/null || exit 0 ;;
        *) break ;;
    esac
    shift
done

cmd="$1"

# -------------------------
# MODE ROUTING
# -------------------------
case "$mode" in
    build) scr_build; return 0 ;;
    list) cmd_list; return 0 ;;
    find) cmd_find "$pattern"; return 0 ;;
    which) cmd_which "$cmd"; return 0 ;;
esac

[[ -z "$cmd" ]] && { help; return 0; }

file="$(resolve_file "$cmd")"

[[ -z "$file" ]] && { echo "[SCR] Not found: $cmd"; return 1; }

# -------------------------
# EXECUTION
# -------------------------
case "$mode" in
    edit) ${EDITOR:-nano} "$file" ;;
    view) less "$file" ;;
    cd) cd "$(dirname "$file")" || return 1 ;;
    *) ${EDITOR:-nano} "$file" ;;
esac
