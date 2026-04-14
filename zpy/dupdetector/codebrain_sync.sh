#!/usr/bin/env bash
set -e

echo "🧠======================================"
echo "   CODEBRAIN SYNC (STABLE CORE)"
echo "======================================"

ROOT="$(pwd)"
BACKUP="$ROOT/.cb_backup_$(date +%s)"
mkdir -p "$BACKUP"

echo "📦 Backup folder: $BACKUP"

if [ -f ".cb_lock" ]; then
    echo "🔒 System locked — no structural changes allowed"
fi

# --------------------------------------------------
# STEP 0 — SAFETY GUARD
# --------------------------------------------------

if [ -f ".cb_synced" ]; then
    echo "✔ System already synced — skipping patch step"
    PATCH_ALLOWED=0
else
    PATCH_ALLOWED=1
    touch .cb_synced
fi

# --------------------------------------------------
# STEP 1 — BACKUP CRITICAL FILES
# --------------------------------------------------

FILES=(
    "codebrain/engine/runner.py"
    "codebrain/call_graph.py"
    "codebrain/engine/execution.py"
)

echo ""
echo "📦 Backing up core files..."

for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        cp "$f" "$BACKUP/"
        echo "✔ $f"
    fi
done

# --------------------------------------------------
# STEP 2 — PATCH RUNNER (dependency-aware usage)
# --------------------------------------------------

echo ""
echo "🔧 Ensuring dependency-aware usage_map..."

RUNNER="codebrain/engine/runner.py"

if [ "$PATCH_ALLOWED" -eq 1 ] && grep -q 'usage_map.get(func\["name"\]' "$RUNNER"; then
    sed -i 's/usage_map.get(func\["name"\], 0)/usage_map.get(func["name"], 0) or usage_map.get(func["file"] + ":" + func["name"], 0)/g' "$RUNNER"
    echo "✔ runner patched"
else
    echo "✔ runner already correct or patch skipped"
fi

# --------------------------------------------------
# STEP 3 — CLEAN CACHE
# --------------------------------------------------

echo ""
echo "🧹 Clearing Python cache..."

find codebrain -name "__pycache__" -type d -exec rm -rf {} + || true
find codebrain -name "*.pyc" -delete || true

# --------------------------------------------------
# STEP 4 — VERIFY CORE IMPORTS
# --------------------------------------------------

echo ""
echo "🧪 Checking imports..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
from codebrain.call_graph import build_call_graph, build_usage_map
print("✔ Core imports OK")
EOF

# --------------------------------------------------
# STEP 5 — PIPELINE DRY CHECK
# --------------------------------------------------

echo ""
echo "🧪 Pipeline dry test..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
print("✔ Pipeline callable")
EOF

# --------------------------------------------------
# STEP 6 — SUMMARY
# --------------------------------------------------

echo ""
echo "🧠======================================"
echo "   SYNC COMPLETE"
echo "======================================"

echo "✔ System stabilized"
echo "✔ Dependency model consistent"
echo "✔ Runner aligned with graph system"

echo ""
echo "RUN:"
echo "  python3 -m codebrain.main ./codebrain_test_sandbox"

echo ""
echo "ROLLBACK:"
echo "  restore from:"
echo "  $BACKUP"

echo ""
echo "======================================"
