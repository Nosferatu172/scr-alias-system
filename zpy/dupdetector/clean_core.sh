#!/usr/bin/env bash
# Script Name: clean_core.sh
# ID: SCR-ID-20260412154211-JHOJ9K834Z
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: clean_core
set -e

echo "🧠======================================"
echo "   CODEBRAIN CLEAN CORE RESET"
echo "======================================"

ROOT="$(pwd)"
BACKUP="$ROOT/.clean_backup_$(date +%s)"

mkdir -p "$BACKUP"

echo "📦 Backup dir: $BACKUP"

# --------------------------------------------------
# STEP 1 — BACKUP IMPORTANT FILES
# --------------------------------------------------

echo ""
echo "📦 Backing up important scripts..."

FILES=(
    "requirements.txt"
    "install.sh"
    "codebrain_sync.sh"
    "verify_core_integrity.sh"
    "codebrain_test_harness.sh"
)

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        cp "$f" "$BACKUP/"
        echo "✔ $f"
    fi
done

# --------------------------------------------------
# STEP 2 — REMOVE BACKUPS / TEMP FILES
# --------------------------------------------------

echo ""
echo "🧹 Removing old backups and temp files..."

rm -f codebrain_backup_*.zip || true
rm -f .cb_backup_* || true
rm -f .codebrain_last_backup || true

# --------------------------------------------------
# STEP 3 — REMOVE CACHE
# --------------------------------------------------

echo ""
echo "🧹 Clearing Python cache..."

find codebrain -name "__pycache__" -type d -exec rm -rf {} + || true
find codebrain -name "*.pyc" -delete || true

# --------------------------------------------------
# STEP 4 — REMOVE OPTIONAL / UNUSED FILES
# --------------------------------------------------

echo ""
echo "🧹 Removing optional / legacy artifacts..."

rm -rf codebrain/evolve || true
rm -f codebrain/ai_semantic_cluster.zip || true

# --------------------------------------------------
# STEP 5 — ENSURE CORE STRUCTURE EXISTS
# --------------------------------------------------

echo ""
echo "🔍 Verifying core structure..."

REQUIRED=(
    "codebrain/engine"
    "codebrain/execution"
    "codebrain/core"
)

for d in "${REQUIRED[@]}"; do
    if [ ! -d "$d" ]; then
        echo "❌ Missing required directory: $d"
        exit 1
    fi
done

echo "✔ Core structure intact"

# --------------------------------------------------
# STEP 6 — VERIFY SYSTEM
# --------------------------------------------------

echo ""
echo "🧪 Running integrity check..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
print("✔ System ready")
EOF

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo ""
echo "🧠======================================"
echo "✔ CLEAN CORE READY"
echo "======================================"

echo ""
echo "NEXT:"
echo "1. (optional) reinstall deps:"
echo "   bash install.sh"
echo ""
echo "2. run test harness:"
echo "   bash codebrain_test_harness.sh"
echo ""
echo "3. run on real project:"
echo "   python3 -m codebrain.main ./your_project"

echo ""
echo "======================================"
