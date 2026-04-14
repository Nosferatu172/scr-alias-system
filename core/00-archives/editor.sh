#!/bin/bash
# editor.sh — SCR Inspector Tool

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX="$CORE_DIR/index/commands.map"
OUT="$CORE_DIR/index/generated/core.sh"

# Load runtime (for functions)
[[ -f "$OUT" ]] && source "$OUT"

# -------------------------
# LOAD MAP
# -------------------------
declare -A SCR_MAP

if [[ -f "$INDEX" ]]; then
    while IFS='=' read -r key value; do
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | xargs)"
        [[ -z "$key" || -z "$value" ]] && continue

        if [[ -n "${SCR_MAP[$key]}" ]]; then
            SCR_MAP["$key"]+=$'\n'"$value"
        else
            SCR_MAP["$key"]="$value"
        fi
    done < "$INDEX"
fi

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

    echo "[SCR0] Multiple targets for '$key':"
    local i=1
    local options=()

    while IFS= read -r line; do
        printf "  [%d] %s\n" "$i" "$line"
        options+=("$line")
        ((i++))
    done <<< "$entries"

    echo -n "Select: "
    read -r choice

    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    echo "${options[$((choice-1))]}"
}

# -------------------------
# RESOLVE FILE
# -------------------------
resolve_file() {
    local name="$1"

    # map
    if [[ -n "${SCR_MAP[$name]}" ]]; then
        pick_file "$name"
        return
    fi

    # function → extract file
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
    local name="$1"
    file="$(resolve_file "$name")"

    if [[ -n "$file" ]]; then
        echo "$file"
    else
        echo "[SCR0] Not found: $name"
    fi
}

cmd_find() {
    local pattern="$1"

    echo "== Matches =="
    (
        for k in "${!SCR_MAP[@]}"; do echo "$k"; done
        declare -F | awk '{print $3}' | grep '^scr_' | sed 's/^scr_//'
    ) | sort | grep -i "$pattern"
}

# -------------------------
# HELP
# -------------------------
help() {
    cat <<EOF
SCR0 Inspector

Usage:
  scr0 [mode] <command>

Modes:
  -e        Edit
  -v        View
  -c        Cd
  -w        Which (show path)
  -l        List all commands
  -f <pat>  Find command
  -h        Help

Examples:
  scr0 -e fin
  scr0 -v tools
  scr0 -c zscr
  scr0 -w fin
  scr0 -l
  scr0 -f scr

EOF
}

# -------------------------
# PARSE
# -------------------------
mode=""
cmd=""
pattern=""

while [[ "$1" == -* ]]; do
    case "$1" in
        -e) mode="edit" ;;
        -v) mode="view" ;;
        -c) mode="cd" ;;
        -w) mode="which" ;;
        -l) mode="list" ;;
        -f) mode="find"; shift; pattern="$1" ;;
        -h) help; return 0 2>/dev/null || exit 0 ;;
        *) break ;;
    esac
    shift
done

cmd="$1"

# -------------------------
# EXECUTION
# -------------------------
case "$mode" in
    list)
        cmd_list
        return 0 2>/dev/null || exit 0
        ;;
    find)
        cmd_find "$pattern"
        return 0 2>/dev/null || exit 0
        ;;
    which)
        cmd_which "$cmd"
        return 0 2>/dev/null || exit 0
        ;;
esac

[[ -z "$cmd" ]] && { help; return 0 2>/dev/null || exit 0; }

file="$(resolve_file "$cmd")"

if [[ -z "$file" ]]; then
    echo "[SCR0] Not found: $cmd"
    return 1 2>/dev/null || exit 1
fi

case "$mode" in
    edit) ${EDITOR:-nano} "$file" ;;
    view) less "$file" ;;
    cd) cd "$(dirname "$file")" || return 1 ;;
    *) ${EDITOR:-nano} "$file" ;;
esac
