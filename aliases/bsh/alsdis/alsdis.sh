#!/usr/bin/env bash
# Script Name: alsdis.sh
# ID: SCR-ID-20260329043000-0V945O0EMQ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alsdis

# Config file for aliases
CONFIG_FILE="$HOME/.alsdis_aliases"

# Make sure config file exists
[ ! -f "$CONFIG_FILE" ] && touch "$CONFIG_FILE"

# Function: display as a table
show_table() {
    column -t -s'|' "$CONFIG_FILE"
}

# Function: edit config
edit_config() {
    local dir="$1"

    if [ -z "$dir" ]; then
        echo "Usage: alsdis -edit /path/to/dir"
        return 1
    fi

    # Open the config file for editing
    ${EDITOR:-nano} "$CONFIG_FILE"

    # After editing, check for conflicts
    if [ "$2" = "-diff" ]; then
        diff_check "$dir"
    fi
}

# Function: check conflicts between config and real directory
diff_check() {
    local dir="$1"

    if [ -z "$dir" ]; then
        echo "Usage: alsdis -diff /path/to/dir"
        return 1
    fi

    echo "Checking conflicts with: $dir"
    echo

    # Extract paths from config
    grep -v '^#' "$CONFIG_FILE" | cut -d'|' -f3 | while read -r path; do
        [ -z "$path" ] && continue

        # If path doesn't exist in given dir → conflict
        if [ ! -e "$dir$(basename "$path")" ]; then
            echo "Conflict: $path not found in $dir"
        fi
    done
}

# CLI handler
if [ $# -eq 0 ]; then
    show_table
    exit 0
fi

case "$1" in
    -edit)
        if [ "$2" = "-diff" ]; then
            edit_config "$3" "-diff"
        else
            edit_config "$2"
        fi
        ;;
    -diff)
        diff_check "$2"
        ;;
    *)
        echo "Usage:"
        echo "  alsdis              # show table"
        echo "  alsdis -edit /dir   # edit config"
        echo "  alsdis -diff /dir   # show conflicts"
        echo "  alsdis -edit -diff /dir"
        ;;
esac
