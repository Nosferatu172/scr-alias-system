#!/bin/bash
# Script Name: dispatcher.sh

# ----------------------------
# LOAD ENV
# ----------------------------
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX="$CORE_DIR/index/commands.map"
OUT="$CORE_DIR/index/generated/core.sh"

# -------------------------
# RUNTIME GUARD (CRITICAL)
# -------------------------
export SCR_RUNTIME=1
export SCR_LOADED=1

# -------------------------
# SAFE LOAD CORE (ONCE)
# -------------------------
if [[ -f "$OUT" ]]; then
    source "$OUT"
fi

# -------------------------
# LOAD COMMAND MAP (FAST LOOKUP)
# -------------------------
declare -A SCR_MAP

if [[ -f "$INDEX" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || -z "$value" ]] && continue
        SCR_MAP["$key"]="$value"
    done < "$INDEX"
fi

# -------------------------
# HELP SYSTEM
# -------------------------
show_help() {
    cat <<EOF
SCR Dispatcher

Usage:
  scr <command> [args]
  scr e-<command>     Edit target
  scr v-<command>     View target
  scr c-<command>     Cd into target directory

Options:
  -h, --help, help    Show this help page

Description:
  Dispatcher resolves commands from a fast lookup map and executes
  editor/view/cd actions or falls back to internal functions.

Available Commands:
EOF

    if [[ ${#SCR_MAP[@]} -eq 0 ]]; then
        echo "  (no commands indexed)"
    else
        for key in "${!SCR_MAP[@]}"; do
            printf "  %-20s -> %s\n" "$key" "${SCR_MAP[$key]}"
        done | sort
    fi

    cat <<EOF

Examples:
  scr myscript        Open script in editor
  scr e-myscript      Edit script
  scr v-myscript      View script
  scr c-myscript      Cd into script directory

EOF
}

# -------------------------
# NORMALIZE INPUT
# -------------------------
run_cmd="$1"
shift || true

# -------------------------
# HELP FLAG CHECK (EARLY EXIT)
# -------------------------
case "$run_cmd" in
    ""|-h|--help|help)
        show_help
        exit 0
        ;;
esac

# -------------------------
# RESOLVER ENGINE
# -------------------------
resolve() {
    local cmd="$1"

    # Prefix commands (e-, v-, c-)
    if [[ "$cmd" == e-* || "$cmd" == c-* || "$cmd" == v-* ]]; then
        local action="${cmd%%-*}"
        local target="${cmd#*-}"

        local file="${SCR_MAP[$target]}"

        [[ -z "$file" ]] && {
            echo "[SCR] Unknown target: $target"
            return 1
        }

        case "$action" in
            e) ${EDITOR:-nano} "$file" ;;
            v) less "$file" ;;
            c) cd "$(dirname "$file")" || return 1 ;;
        esac

        return 0
    fi

    # Direct lookup
    local file="${SCR_MAP[$cmd]}"

    if [[ -n "$file" ]]; then
        ${EDITOR:-nano} "$file"
        return 0
    fi

    return 1
}

# -------------------------
# RUN RESOLVER FIRST
# -------------------------
if resolve "$run_cmd"; then
    exit 0
fi

# -------------------------
# FUNCTION FALLBACK
# -------------------------
fn="scr_${run_cmd}"

if declare -f "$fn" >/dev/null 2>&1; then
    "$fn" "$@"
    exit 0
fi

# -------------------------
# FAIL SAFE
# -------------------------
echo "[SCR] Command not found: $run_cmd"
echo "Try: scr --help"
exit 1
