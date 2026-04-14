#!/usr/bin/env bash
set -e

echo "🧠======================================"
echo "   CODEBRAIN BACKUP MANAGER"
echo "======================================"

ROOT="$(pwd)"
TIMESTAMP=$(date +%s)
BACKUP_FILE="codebrain_backup_${TIMESTAMP}.zip"
LATEST_POINTER="$ROOT/.codebrain_last_backup"

# --------------------------------------------------
# HELP
# --------------------------------------------------

if [ "$1" == "--help" ]; then
    echo ""
    echo "Usage:"
    echo "  backup:  bash codebrain_backup_manager.sh backup"
    echo "  restore: bash codebrain_backup_manager.sh restore [file]"
    exit 0
fi

# --------------------------------------------------
# BACKUP
# --------------------------------------------------

if [ "$1" == "backup" ]; then

    echo ""
    echo "📦 Creating backup..."

    zip -r "$BACKUP_FILE" \
        codebrain \
        install.sh \
        verify_core_integrity.sh \
        codebrain_sync.sh \
        requirements.txt \
        2>/dev/null || true

    echo "$BACKUP_FILE" > "$LATEST_POINTER"

    echo "✔ Backup created:"
    echo "   $BACKUP_FILE"

    exit 0
fi

# --------------------------------------------------
# RESTORE
# --------------------------------------------------

if [ "$1" == "restore" ]; then

    if [ -n "$2" ]; then
        FILE="$2"
    else
        if [ ! -f "$LATEST_POINTER" ]; then
            echo "❌ No restore pointer found"
            exit 1
        fi
        FILE=$(cat "$LATEST_POINTER")
    fi

    if [ ! -f "$FILE" ]; then
        echo "❌ Backup file not found"
        exit 1
    fi

    echo ""
    echo "⚠ Restoring from: $FILE"
    echo "Press ENTER to continue..."
    read

    TMP=".restore_tmp"

    rm -rf "$TMP"
    mkdir "$TMP"

    unzip -q "$FILE" -d "$TMP"

    if [ ! -d "$TMP/codebrain" ]; then
        echo "❌ Invalid backup"
        exit 1
    fi

    rm -rf codebrain
    mv "$TMP/codebrain" .

    rm -rf "$TMP"

    echo "✔ Restore complete"
    exit 0
fi

echo "❌ Invalid command"