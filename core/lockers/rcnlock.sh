#!/usr/bin/env bash
# Script Name: rcnlock.sh
# ID: SCR-ID-20260412153736-MFFFZ6AKZD
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rcnlock
set -e

SCRIPT_NAME="$(basename "$0")"
DEFAULT_FILE="rcn.txt"

FILE=""
CMD=""

# --------------------------------------------------
# ARG PARSING (FIXED)
# --------------------------------------------------

if [ $# -eq 0 ]; then
    CMD="help"
else
    case "$1" in
        -h|--help|help)
            CMD="help"
            ;;
        lock|unlock|status)
            CMD="$1"
            FILE="${2:-$DEFAULT_FILE}"
            ;;
        *)
            echo "❌ Invalid command: $1"
            CMD="help"
            ;;
    esac
fi

# --------------------------------------------------
# HELP
# --------------------------------------------------

show_help() {
    echo ""
    echo "🧠======================================"
    echo "        RCN LOCK MANAGER"
    echo "======================================"
    echo ""
    echo "USAGE:"
    echo "  $SCRIPT_NAME lock <file>"
    echo "  $SCRIPT_NAME unlock <file>"
    echo "  $SCRIPT_NAME status <file>"
    echo ""
    echo "DEFAULT:"
    echo "  file = rcn.txt"
    echo ""
    echo "EXAMPLES:"
    echo "  ./rcnlock.sh lock"
    echo "  ./rcnlock.sh lock rcn.txt"
    echo "  ./rcnlock.sh status rcn.txt"
    echo "  ./rcnlock.sh unlock"
    echo ""
    echo "LOCK METHODS:"
    echo "  chmod 444  → read-only"
    echo "  chattr +i  → immutable (strong lock)"
    echo ""
    echo "NOTE:"
    echo "  chattr may require sudo"
    echo ""
    echo "======================================"
    echo ""
}

# --------------------------------------------------
# STATUS
# --------------------------------------------------

status() {
    if [ ! -f "$FILE" ]; then
        echo "❌ File not found: $FILE"
        exit 1
    fi

    if lsattr "$FILE" 2>/dev/null | grep -q 'i'; then
        echo "🔒 IMMUTABLE LOCK ENABLED"
    elif [ ! -w "$FILE" ]; then
        echo "🔒 READ-ONLY (chmod)"
    else
        echo "🔓 UNLOCKED"
    fi
}

# --------------------------------------------------
# LOCK
# --------------------------------------------------

lock() {
    echo "🔒 Locking $FILE..."

    if command -v chattr >/dev/null 2>&1; then
        sudo chattr +i "$FILE" 2>/dev/null || true
    fi

    chmod 444 "$FILE" 2>/dev/null || true

    echo "✔ Locked"
}

# --------------------------------------------------
# UNLOCK
# --------------------------------------------------

unlock() {
    echo "🔓 Unlocking $FILE..."

    if command -v chattr >/dev/null 2>&1; then
        sudo chattr -i "$FILE" 2>/dev/null || true
    fi

    chmod 644 "$FILE" 2>/dev/null || true

    echo "✔ Unlocked"
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------

case "$CMD" in
    help)
        show_help
        ;;
    lock)
        lock
        ;;
    unlock)
        unlock
        ;;
    status)
        status
        ;;
esac
