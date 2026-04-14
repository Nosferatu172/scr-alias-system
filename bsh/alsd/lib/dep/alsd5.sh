#!/usr/bin/env bash
# Script Name: alsd5.sh
# ID: SCR-ID-20260412153504-1YYWF3FBFZ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alsd5

add_alias() {
    local name=""
    local dir=""
    local list_flag=""

    # Parse args for alias name, directory, and optional -L
    for arg in "$@"; do
        if [ "$arg" = "-L" ]; then
            list_flag="L"
        elif [ -z "$name" ]; then
            name="$arg"
        elif [ -z "$dir" ]; then
            dir="$arg"
        fi
    done

    if [ -z "$name" ] || [ -z "$dir" ]; then
        echo "Usage: actd -a <alias_name> <directory> [-L]"
        exit 1
    fi

    if grep -q "^$name," "$CONFIG_FILE"; then
        echo "Alias '$name' already exists. Use -e to edit."
        exit 1
    fi

    # Add to CSV with optional L flag
    if [ "$list_flag" = "L" ]; then
        echo "$name,$dir,L" >> "$CONFIG_FILE"
    else
        echo "$name,$dir" >> "$CONFIG_FILE"
    fi

    rebuild_alias_file
    echo "Added alias: $name -> $dir ${list_flag:+(+ ll -ah)}"
}

edit_alias() {
    local name=""
    local dir=""
    local list_flag=""

    # Parse args for alias name, directory, and optional -L
    for arg in "$@"; do
        if [ "$arg" = "-L" ]; then
            list_flag="L"
        elif [ -z "$name" ]; then
            name="$arg"
        elif [ -z "$dir" ]; then
            dir="$arg"
        fi
    done

    if [ -z "$name" ] || [ -z "$dir" ]; then
        echo "Usage: actd -e <alias_name> <directory> [-L]"
        exit 1
    fi

    if ! grep -q "^$name," "$CONFIG_FILE"; then
        echo "Alias '$name' does not exist. Use -a to add."
        exit 1
    fi

    if [ "$list_flag" = "L" ]; then
        sed -i "s|^$name,.*|$name,$dir,L|" "$CONFIG_FILE"
    else
        sed -i "s|^$name,.*|$name,$dir|" "$CONFIG_FILE"
    fi

    rebuild_alias_file
    echo "Updated alias: $name -> $dir ${list_flag:+(+ ll -ah)}"
}
