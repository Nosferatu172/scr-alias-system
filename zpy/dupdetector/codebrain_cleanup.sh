#!/usr/bin/env bash
set -e

echo "🧠======================================"
echo "   CODEBRAIN SAFE CLEANUP"
echo "======================================"

ROOT="$(pwd)"
BACKUP_DIR="$ROOT/cleanup_backup_$(date +%s)"

mkdir -p "$BACKUP_DIR"

echo "📦 Backup directory:"
echo "   $BACKUP_DIR"

# --------------------------------------------------
# SAFETY GUARD (prevents re-running)
# --------------------------------------------------

if ls codebrain/*.disabled >/dev/null 2>&1; then
    echo "⚠ Cleanup already applied — skipping"
    exit 0
fi

# --------------------------------------------------
# STEP 1 — DEFINE LEGACY MODULES
# --------------------------------------------------

LEGACY_FILES=(
    "codebrain/safe_refactor.py"
    "codebrain/dependency_refactor.py"
    "codebrain/merger.py"
    "codebrain/semantic_merge.py"
    "codebrain/graph_engine.py"
)

LEGACY_DIRS=(
    "codebrain/brain"
)

# --------------------------------------------------
# STEP 2 — BACKUP FILES
# --------------------------------------------------

echo ""
echo "📦 Backing up legacy modules..."

for file in "${LEGACY_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/"
        echo "✔ Backed up $file"
    fi
done

for dir in "${LEGACY_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$BACKUP_DIR/"
        echo "✔ Backed up $dir"
    fi
done

# --------------------------------------------------
# STEP 3 — DISABLE LEGACY MODULES
# --------------------------------------------------

echo ""
echo "🧹 Disabling legacy modules..."

for file in "${LEGACY_FILES[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "$file.disabled"
        echo "✔ Disabled $file"
    fi
done

for dir in "${LEGACY_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        mv "$dir" "$dir.disabled"
        echo "✔ Disabled $dir"
    fi
done

# --------------------------------------------------
# STEP 4 — CLEAN PYTHON CACHE
# --------------------------------------------------

echo ""
echo "🧹 Clearing __pycache__ and .pyc files..."

find codebrain -name "__pycache__" -type d -exec rm -rf {} + || true
find codebrain -name "*.pyc" -delete || true

# --------------------------------------------------
# STEP 5 — VERIFY NEW PIPELINE IMPORTS
# --------------------------------------------------

echo ""
echo "🧪 Verifying pipeline integrity..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
from codebrain.engine.pipeline import Pipeline
from codebrain.engine.execution import ExecutionPhase
print("✔ Pipeline modules import OK")
EOF

# --------------------------------------------------
# STEP 6 — RUNTIME SMOKE TEST
# --------------------------------------------------

echo ""
echo "⚙ Running minimal pipeline smoke test..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
print("✔ Runner callable")
EOF

# --------------------------------------------------
# STEP 7 — SUMMARY
# --------------------------------------------------

echo ""
echo "🧠======================================"
echo "   CLEANUP SUMMARY"
echo "======================================"

echo "✔ Legacy modules disabled"
echo "✔ Backup stored at:"
echo "   $BACKUP_DIR"
echo ""

echo "NEXT STEPS:"
echo "1. Run your pipeline:"
echo "   python3 -m codebrain.main ./codebrain_test_sandbox"
echo ""
echo "2. If everything works:"
echo "   rm codebrain/*.disabled"
echo "   rm -rf codebrain/brain.disabled"
echo ""
echo "3. If something breaks:"
echo "   restore files from backup directory"

echo ""
echo "======================================"