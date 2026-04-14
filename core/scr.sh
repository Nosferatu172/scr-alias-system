#!/usr/bin/env bash
# SCR Unified CLI

#CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#CORE_DIR="/mnt/c/scr/"

: "${CORE_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

INDEX="$CORE_DIR/index/commands.map"
OUT="$CORE_DIR/index/generated/core.sh"

# -------------------------
# JSON PATHS
# -------------------------
JSON_DIR="$CORE_DIR/index"

COMMANDS_JSON="$JSON_DIR/commands.json"
ALIASES_JSON="$JSON_DIR/aliases.json"
TAGS_JSON="$JSON_DIR/tags.json"
GRAPH_JSON="$JSON_DIR/graph.json"

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
# BUILD SYSTEM (alpha)
# -------------------------
scr_build() {
    local SCR_ROOT="$(cd "$CORE_DIR/.." && pwd)"

    local ALIAS_ROOT="$SCR_ROOT/aliases"
    local BSH_ROOT="$SCR_ROOT/bsh"
    local ZPY_ROOT="$SCR_ROOT/zpy"
    local ZRU_ROOT="$SCR_ROOT/zru"
    local ZSH_ROOT="$SCR_ROOT/aliases/zsh"

    local OUT_DIR="$CORE_DIR/index/generated"
    local INDEX_DIR="$CORE_DIR/index"
    local MAP="$INDEX_DIR/commands.map"
    local CORE_FILE="$OUT_DIR/core.sh"

    #mkdir -p "$OUT_DIR"/{bash,bsh,python,ruby,zsh}
    mkdir -p "$OUT_DIR/bash" "$OUT_DIR/bsh" "$OUT_DIR/python" "$OUT_DIR/ruby" "$OUT_DIR/zsh"
    mkdir -p "$INDEX_DIR"
    # -------------------------
    # INIT JSON SYSTEM
    # -------------------------
    init_json() {
        local file="$1"
        local default="$2"
        [[ ! -f "$file" ]] && echo "$default" > "$file"
    }

    init_json "$INDEX_DIR/runtime.json" '{
      "bash": "bash",
      "zsh": "zsh",
      "python": "python3",
      "ruby": "ruby"
    }'

    init_json "$INDEX_DIR/permissions.json" '{
      "logs": "deny",
      "swap": "deny",
      "keys": "deny",
      "bsh": "allow",
      "zpy": "allow",
      "zru": "allow"
    }'
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

        local base func dir tag

        base=$(basename "$file" ."$ext")
        dir=$(basename "$(dirname "$file")")
        tag="$dir"

        is_reserved "$base" && return

        func=$(safe_name "$base")

        case "$ext" in
            sh)  echo "$func() { bash \"$file\" \"\$@\"; }" >> "$out" ;;
            py)  echo "$func() { python3 \"$file\" \"\$@\"; }" >> "$out" ;;
            rb)  echo "$func() { ruby \"$file\" \"\$@\"; }" >> "$out" ;;
            zsh) echo "$func() { zsh \"$file\" \"\$@\"; }" >> "$out" ;;
        esac

        # JSON collectors
        echo "\"$base\": \"$func\"," >> "$ALIASES_TMP"
        echo "\"$base\": \"$file\"," >> "$COMMANDS_TMP"
        echo "$tag|$base" >> "$TAGS_TMP"
        echo "$base|$tag" >> "$GRAPH_TMP"
    }

    # temp files
    ALIASES_TMP="$INDEX_DIR/.aliases.tmp"
    COMMANDS_TMP="$INDEX_DIR/.commands.tmp"
    TAGS_TMP="$INDEX_DIR/.tags.tmp"
    GRAPH_TMP="$INDEX_DIR/.graph.tmp"

    : > "$ALIASES_TMP"
    : > "$COMMANDS_TMP"
    : > "$TAGS_TMP"
    : > "$GRAPH_TMP"
    # reset
    : > "$OUT_DIR/bash/aliases.sh"
    : > "$OUT_DIR/bsh/bsh.sh"
    : > "$OUT_DIR/python/tools.sh"
    : > "$OUT_DIR/ruby/tools.sh"
    : > "$OUT_DIR/zsh/tools.sh"
    : > "$CORE_FILE"
    : > "$MAP"

    # build layers
    [[ -d "$ALIAS_ROOT" ]] && while IFS= read -r f; do
        register "$f" "sh" "$OUT_DIR/bash/aliases.sh"
    done < <(find "$ALIAS_ROOT" -type f -name "*.sh")

    [[ -d "$BSH_ROOT" ]] && while IFS= read -r f; do
        register "$f" "sh" "$OUT_DIR/bsh/bsh.sh"
    done < <(find "$BSH_ROOT" -type f -name "*.sh")

    [[ -d "$ZPY_ROOT" ]] && while IFS= read -r f; do
        register "$f" "py" "$OUT_DIR/python/tools.sh"
    done < <(find "$ZPY_ROOT" -type f -name "*.py")

    [[ -d "$ZRU_ROOT" ]] && while IFS= read -r f; do
        register "$f" "rb" "$OUT_DIR/ruby/tools.sh"
    done < <(find "$ZRU_ROOT" -type f -name "*.rb")

    [[ -d "$ZSH_ROOT" ]] && while IFS= read -r f; do
        register "$f" "zsh" "$OUT_DIR/zsh/tools.sh"
    done < <(find "$ZSH_ROOT" -type f -name "*.zsh")

    # build core + map
    for f in "$OUT_DIR"/*/*.sh; do
        [[ -f "$f" ]] || continue
        echo "source \"$f\"" >> "$CORE_FILE"

        name="$(basename "$f" .sh)"
        [[ "$name" != *"generated"* ]] && echo "$name=$f" >> "$MAP"
    done
    # -------------------------
    # BUILD JSON FILES
    # -------------------------

    # aliases.json
    {
        echo "{"
        sed '$ s/,$//' "$ALIASES_TMP"
        echo "}"
    } > "$INDEX_DIR/aliases.json"

    # commands.json (🔥 core registry)
    {
        echo "{"
        sed '$ s/,$//' "$COMMANDS_TMP"
        echo "}"
    } > "$INDEX_DIR/commands.json"

    # graph.json
    {
        echo "{"
        sed '$ s/,$//' "$GRAPH_TMP" | awk -F'|' '{print "  \""$1"\": [\"" $2 "\"],"}'
        echo "}"
    } > "$INDEX_DIR/graph.json"
    # tags.json
    {
        echo "{"
        awk -F'|' '{print "  \""$1"\": [\"" $2 "\"],"}' "$TAGS_TMP" | sed '$ s/,$//'
        echo "}"
    } > "$INDEX_DIR/tags.json"
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

    # map lookup
    if [[ -n "${SCR_MAP[$name]}" ]]; then
        pick_file "$name"
        return
    fi

    # function fallback
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
    local file
    file="$(resolve_file "$name")"

    if [[ -n "$file" ]]; then
        echo "$file"
    else
        echo "[SCR] Not found: $name"
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
# JSON HELPERS
# -------------------------
json_get() {
    local file="$1"
    local key="$2"

    grep -oP "\"$key\":\s*\"[^\"]+\"" "$file" | head -n1 | cut -d'"' -f4
}

# -------------------------
# QUERY
# -------------------------
cmd_query() {
    local cmd="$1"

    local path
    path=$(json_get "$COMMANDS_JSON" "$cmd")

    [[ -z "$path" ]] && {
        echo "[SCR] Command not found: $cmd"
        return 1
    }

    echo "=== $cmd ==="
    echo "Path: $path"

    echo "Tags:"
    grep -B1 "\"$cmd\"" "$TAGS_JSON" \
        | grep -oP '"[^"]+"' \
        | tr -d '"' \
        | head -n1
}

# -------------------------
# TAG
# -------------------------
cmd_tag() {
    local tag="$1"

    [[ -z "$tag" ]] && {
        echo "Usage: scr -tag <tag>"
        return 1
    }

    echo "=== Tag: $tag ==="

    jq -r --arg t "$tag" '.[$t][]? // empty' "$TAGS_JSON" \
        | sed 's/^/ - /'
}

# -------------------------
# GRAPH
# -------------------------
cmd_graph() {
    local cmd="$1"

    echo "=== Graph: $cmd ==="

    grep "\"$cmd\"" "$GRAPH_JSON" \
        | sed 's/.*\[\(.*\)\].*/\1/' \
        | tr ',' '\n' \
        | sed 's/[ "]*//g' \
        | sed '/^$/d' \
        | sed 's/^/ - /'
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
  -clean    Clean generated files
  -h        Help

Examples:
  scr fin
  scr -e fin
  scr -v tools
  scr -c zscr
  scr -w fin
  scr -l
  scr -f scr
  scr -set
  scr -clean
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
        -q|--query) mode="query";;
        -tag) mode="tag";;
        -graph) mode="graph";;
        -set) scr_build; return 0 2>/dev/null || exit 0 ;;
        -clean)
            echo "[SCR] Cleaning index..."

            rm -rf "$CORE_DIR/index/generated"
            mkdir -p "$CORE_DIR/index/generated"

            rm -f "$CORE_DIR/index/"*.json
            rm -f "$CORE_DIR/index/commands.map"

            echo "[SCR] Clean complete"
            return 0 2>/dev/null || exit 0
            ;;
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
    query)
        cmd_query "$cmd"
        return 0 2>/dev/null || exit 0
        ;;
    tag)
        cmd_tag "$cmd"
        return 0 2>/dev/null || exit 0
        ;;
    graph)
        cmd_graph "$cmd"
        return 0 2>/dev/null || exit 0
        ;;
esac

[[ -z "$cmd" ]] && { help; return 0 2>/dev/null || exit 0; }

file="$(resolve_file "$cmd")"

if [[ -z "$file" ]]; then
    echo "[SCR] Not found: $cmd"
    return 1 2>/dev/null || exit 1
fi

# -------------------------
# EXECUTION
# -------------------------
fn="scr_${cmd}"
args=("${@:2}")

case "$mode" in
    edit)
        ${EDITOR:-nano} "$file"
        ;;

    view)
        less "$file"
        ;;

    cd)
        cd "$(dirname "$file")" || return 1
        ;;

    *)
        # 🔥 AUTO MODE (this is the key change)

        if declare -f "$fn" >/dev/null 2>&1; then
            # Prefer runtime/generated function
            "$fn" "${args[@]}"
        else
            # fallback to file
            if [[ -n "$file" ]]; then
                if [[ ${#args[@]} -gt 0 ]]; then
                    # run if args provided
                    if [[ -x "$file" ]]; then
                        "$file" "${args[@]}"
                    else
                        bash "$file" "${args[@]}"
                    fi
                else
                    # no args → open editor
                    ${EDITOR:-nano} "$file"
                fi
            else
                echo "[SCR] Not found: $cmd"
                return 1
            fi
        fi
        ;;
esac