#!/usr/bin/env bash
# Script Name: lock.sh
# ID: SCR-ID-20260412153729-9P6P0BE38N
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: lock

set -e

DEFAULT_TARGET="rcn.txt"

MODE="${1:-help}"
TARGET="${2:-$DEFAULT_TARGET}"

REPORT_FILE="/tmp/rcnlock_report_$$.log"

# --------------------------------------------------
# HELP
# --------------------------------------------------

show_help() {
    echo ""
    echo "🧠======================================"
    echo "          RCN LOCK SYSTEM"
    echo "======================================"
    echo ""
    echo "USAGE:"
    echo "  rcnlock.sh lock <file|folder>"
    echo "  rcnlock.sh unlock <file|folder>"
    echo "  rcnlock.sh status <file|folder>"
    echo "  rcnlock.sh help"
    echo ""
    echo "FEATURES:"
    echo "  ✔ File locking"
    echo "  ✔ Recursive folder locking"
    echo "  ✔ Safe permission restore"
    echo "  ✔ Optional immutable mode (chattr)"
    echo "  ✔ Lock report logging"
    echo ""
    echo "LOCK RULES:"
    echo "  Files      → 444 (read-only)"
    echo "  Folders    → 555 (readable + traversable)"
    echo "  Unlock     → 644 / 755"
    echo ""
    echo "EXCLUDES:"
    echo "  __pycache__ , .git (never modified)"
    echo ""
    echo "======================================"
    echo ""
}

# --------------------------------------------------
# STATUS
# --------------------------------------------------

status() {
    if [ ! -e "$TARGET" ]; then
        echo "❌ Not found: $TARGET"
        exit 1
    fi

    if [ -d "$TARGET" ]; then
        echo "📁 Folder target"

        if command -v lsattr >/dev/null 2>&1 && lsattr -d "$TARGET" 2>/dev/null | grep -q 'i'; then
            echo "🔒 IMMUTABLE (folder)"
        else
            echo "📊 Permissions:"
            find "$TARGET" -maxdepth 1 -type f -printf "%m %p\n" | head
        fi

    else
        echo "📄 File target"

        if command -v lsattr >/dev/null 2>&1 && lsattr "$TARGET" 2>/dev/null | grep -q 'i'; then
            echo "🔒 IMMUTABLE"
        else
            ls -l "$TARGET"
        fi
    fi
}

# --------------------------------------------------
# LOCK LOGIC
# --------------------------------------------------

lock_target() {
    echo "🔒 Locking: $TARGET"
    echo "🧾 Report: $REPORT_FILE"
    echo ""

    echo "TARGET: $TARGET" >> "$REPORT_FILE"

    if [ -f "$TARGET" ]; then

        # FILE MODE
        if command -v chattr >/dev/null 2>&1; then
            sudo chattr +i "$TARGET" 2>/dev/null || true
        fi

        chmod 444 "$TARGET" 2>/dev/null || true

        echo "✔ file locked" | tee -a "$REPORT_FILE"
        return
    fi

    if [ -d "$TARGET" ]; then

        # FOLDER MODE
        echo "📁 folder detected"

        # exclude system dirs
        FIND_CMD="find \"$TARGET\" \
            -path \"*/.git\" -prune -o \
            -path \"*/__pycache__\" -prune -o \
            -print"

        # immutable first (optional)
        if command -v chattr >/dev/null 2>&1; then
            eval "$FIND_CMD" | while read -r item; do
                sudo chattr +i "$item" 2>/dev/null || true
            done
        fi

        # permissions
        eval "$FIND_CMD" | while read -r item; do
            if [ -d "$item" ]; then
                chmod 555 "$item" 2>/dev/null || true
            else
                chmod 444 "$item" 2>/dev/null || true
            fi

            echo "locked: $item" >> "$REPORT_FILE"
        done

        echo "✔ folder locked"
        return
    fi

    echo "❌ Invalid target"
    exit 1
}

# --------------------------------------------------
# UNLOCK LOGIC
# --------------------------------------------------

unlock_target() {
    echo "🔓 Unlocking: $TARGET"

    if [ -f "$TARGET" ]; then

        if command -v chattr >/dev/null 2>&1; then
            sudo chattr -i "$TARGET" 2>/dev/null || true
        fi

        chmod 644 "$TARGET" 2>/dev/null || true

        echo "✔ file unlocked"
        return
    fi

    if [ -d "$TARGET" ]; then

        FIND_CMD="find \"$TARGET\" \
            -path \"*/.git\" -prune -o \
            -path \"*/__pycache__\" -prune -o \
            -print"

        if command -v chattr >/dev/null 2>&1; then
            eval "$FIND_CMD" | while read -r item; do
                sudo chattr -i "$item" 2>/dev/null || true
            done
        fi

        eval "$FIND_CMD" | while read -r item; do
            if [ -d "$item" ]; then
                chmod 755 "$item" 2>/dev/null || true
            else
                chmod 644 "$item" 2>/dev/null || true
            fi
        done

        echo "✔ folder unlocked"
        return
    fi

    echo "❌ Invalid target"
    exit 1
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------

case "$MODE" in
    lock)
        lock_target
        ;;
    unlock)
        unlock_target
        ;;
    status)
        status
        ;;
    help|-h|--help|"")
        show_help
        ;;
    *)
        echo "❌ Unknown command: $MODE"
        echo "Try: $0 help"
        exit 1
        ;;
esac
