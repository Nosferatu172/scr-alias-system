#!/usr/bin/env bash
# Script Name: cb_freeze.sh
# ID: SCR-ID-20260412153719-H3Y8PV63Y1
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cb_freeze
set -e

ROOT="$(pwd)"
MODE="${1:-help}"
TARGET="${2:-.}"

FREEZE_DIR="$ROOT/.cb_freeze"
MANIFEST="$FREEZE_DIR/manifest.txt"
LOG="$FREEZE_DIR/freeze.log"

mkdir -p "$FREEZE_DIR"

# --------------------------------------------------
# FREEZE MODES (POLICY LAYER)
# --------------------------------------------------

FREEZE_MODE="${FREEZE_MODE:-safe}"

# safe = default dev-friendly
# strict = locks everything except critical system dirs
# paranoid = includes deeper immutability (chattr)

# --------------------------------------------------
# EXCLUSION RULES
# --------------------------------------------------

EXCLUDES=(
    ".git"
    "__pycache__"
    ".venv"
    "node_modules"
    ".idea"
)

build_find() {
    local dir="$1"

    local expr=""

    for e in "${EXCLUDES[@]}"; do
        expr="$expr -path \"*/$e\" -o"
    done

    # remove trailing -o
    expr="${expr::-3}"

    eval "find \"$dir\" \\( $expr \\) -prune -o -print"
}

# --------------------------------------------------
# HELP
# --------------------------------------------------

help() {
    cat << 'EOF'

🧠======================================
        CODEBRAIN FREEZE SYSTEM
======================================

NAME:
    cb_freeze.sh — filesystem state freezer

SYNOPSIS:
    cb_freeze.sh <command> [target]

COMMANDS:
    freeze   Freeze directory or file tree
    thaw     Restore permissions + unlock system
    verify   Check integrity against snapshot
    help     Show this help page

TARGET:
    Optional. Defaults to current directory (.)

MODES (ENV VARIABLE):
    FREEZE_MODE=safe      Default, safe dev mode
    FREEZE_MODE=strict    Strong locking (more aggressive)
    FREEZE_MODE=paranoid  Immutable filesystem lock (chattr)

EXAMPLES:

    # Freeze current directory
    cb_freeze.sh freeze

    # Freeze specific project
    cb_freeze.sh freeze codebrain/

    # Strong freeze mode
    FREEZE_MODE=strict cb_freeze.sh freeze

    # Paranoid immutable lock
    FREEZE_MODE=paranoid cb_freeze.sh freeze codebrain/

    # Unlock everything
    cb_freeze.sh thaw codebrain/

    # Verify integrity
    cb_freeze.sh verify

SAFETY RULES:

    ✔ NEVER locks:
        .git
        __pycache__
        .venv
        node_modules

    ✔ ALWAYS restores safe permissions on thaw

    ✔ Designed for development + experimental systems

OUTPUT FILES:

    .cb_freeze/
        manifest.txt   → snapshot hash registry
        freeze.log     → lock operations log

WARNINGS:

    ⚠ Paranoid mode uses chattr +i (requires sudo)
    ⚠ Improper thaw may require sudo permissions
    ⚠ Do not freeze system directories

======================================

EOF
}

# --------------------------------------------------
# MANIFEST
# --------------------------------------------------

snapshot() {
    local dir="$1"

    echo "🧾 Creating snapshot..."

    > "$MANIFEST"

    build_find "$dir" | while read -r f; do
        [ -f "$f" ] || continue
        hash=$(sha256sum "$f" | awk '{print $1}')
        echo "$hash|$f" >> "$MANIFEST"
    done

    echo "✔ snapshot saved"
}

# --------------------------------------------------
# FREEZE CORE
# --------------------------------------------------

freeze() {
    echo "❄ FREEZE MODE: $FREEZE_MODE"
    echo "📍 Target: $TARGET"

    snapshot "$TARGET"

    build_find "$TARGET" | while read -r item; do

        if [ -d "$item" ]; then
            chmod 555 "$item" 2>/dev/null || true
        else
            chmod 444 "$item" 2>/dev/null || true
        fi

        if [ "$FREEZE_MODE" = "paranoid" ] && command -v chattr >/dev/null 2>&1; then
            sudo chattr +i "$item" 2>/dev/null || true
        fi

        echo "LOCKED: $item" >> "$LOG"
    done

    echo "✔ SYSTEM FROZEN"
}

# --------------------------------------------------
# THAW CORE
# --------------------------------------------------

thaw() {
    echo "🔓 THAW MODE"
    echo "📍 Target: $TARGET"

    build_find "$TARGET" | while read -r item; do

        if command -v chattr >/dev/null 2>&1; then
            sudo chattr -i "$item" 2>/dev/null || true
        fi

        if [ -d "$item" ]; then
            chmod 755 "$item" 2>/dev/null || true
        else
            chmod 644 "$item" 2>/dev/null || true
        fi
    done

    echo "✔ SYSTEM THAWED"
}

# --------------------------------------------------
# VERIFY INTEGRITY
# --------------------------------------------------

verify() {
    echo "🛡 VERIFYING INTEGRITY..."

    if [ ! -f "$MANIFEST" ]; then
        echo "❌ No snapshot found"
        exit 1
    fi

    while IFS="|" read -r hash file; do

        [ -f "$file" ] || {
            echo "❌ MISSING: $file"
            continue
        }

        current=$(sha256sum "$file" | awk '{print $1}')

        if [ "$hash" != "$current" ]; then
            echo "⚠ MODIFIED: $file"
        fi

    done < "$MANIFEST"

    echo "✔ verification complete"
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------

case "$MODE" in
    freeze) freeze ;;
    thaw) thaw ;;
    verify) verify ;;
    help|-h|--help|"") help ;;
    *) echo "❌ Unknown command: $MODE"; help ;;
esac
