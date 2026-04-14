#!/usr/bin/env bash
# Script Name: word-replacer-1.3.sh
# ID: SCR-ID-20260329042902-QKWEMCY09N
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: word-replacer-1.3

# Usage: word-replacer.sh [-n] [directory]
# -n : dry run (preview changes)
# directory : optional, defaults to current folder
# Example: word-replacer.sh -n ~/myproject

DRYRUN=0

# Check for -n
if [ "$1" == "-n" ]; then
    DRYRUN=1
    shift
fi

# Optional directory argument
DIR="${1:-.}"   # default to current directory

# Collect word pairs
declare -a FINDS
declare -a REPLACES

while true; do
    read -p "Word to find (or /done to finish): " FIND
    if [[ "$FIND" == "/done" ]]; then
        break
    fi
    read -p "Word to replace with: " REPLACE
    FINDS+=("$FIND")
    REPLACES+=("$REPLACE")
done

TOTAL=${#FINDS[@]}

if [ $TOTAL -eq 0 ]; then
    echo "No replacements specified. Exiting."
    exit 0
fi

echo "Searching in: $DIR"
echo "Total replacements to run: $TOTAL"

# Loop over each replacement pair
for ((i=0; i<TOTAL; i++)); do
    FIND="${FINDS[$i]}"
    REPLACE="${REPLACES[$i]}"

    echo "Round $((i+1))/$TOTAL - Replacing '$FIND' with '$REPLACE'..."

    find "$DIR" -xdev -type f ! -path "*/.*/*" | while read -r file; do
        if grep -q "$FIND" "$file"; then
            echo "File: $(realpath "$file")"
            if [ $DRYRUN -eq 1 ]; then
                grep -n --color=always "$FIND" "$file"
            else
                sed -i "s|$FIND|$REPLACE|g" "$file"
                echo "Updated: $(realpath "$file")"
            fi
        fi
    done

    echo "$((i+1))/$TOTAL done."
done

echo "Operation complete: $TOTAL/$TOTAL done."
