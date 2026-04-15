#!/usr/bin/env zsh
# Script Name: scrid2.zsh
# ID: SCR-ID-20260326023617-AIT7SLX4JJ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scrid2

SCR_ROOT="/d/scr-pac"

scrid_find() {
    local id="$1"

    echo "Searching scrid: $id"

    grep -R "SCRID:$id" "$SCR_ROOT" 2>/dev/null
}

scrid_tag() {
    local file="$1"
    local id="$2"

    echo "SCRID:$id" >> "$file"
    echo "tagged $file with $id"
}

case "$1" in
    find)
        scrid_find "$2"
        ;;
    tag)
        scrid_tag "$2" "$3"
        ;;
    *)
        echo "usage: scrid.zsh find <id> | tag <file> <id>"
        ;;
esac
