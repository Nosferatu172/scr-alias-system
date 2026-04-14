#!/usr/bin/env bash
set -e

echo "🧠======================================"
echo "   CODEBRAIN PRODUCTION CHECK"
echo "======================================"

FAIL=0

# --------------------------------------------------
# STEP 1 — PYTHON
# --------------------------------------------------

python3 --version >/dev/null 2>&1 || {
    echo "❌ Python missing"
    FAIL=1
}

# --------------------------------------------------
# STEP 2 — IMPORT
# --------------------------------------------------

python3 - << 'EOF' || FAIL=1
import codebrain.main
print("✔ Import OK")
EOF

# --------------------------------------------------
# STEP 3 — ENTRYPOINT
# --------------------------------------------------

COUNT=$(grep -R "def run_pipeline" codebrain | wc -l)

if [ "$COUNT" -eq 1 ]; then
    echo "✔ Single pipeline entry"
else
    echo "❌ Pipeline conflict"
    FAIL=1
fi

# --------------------------------------------------
# STEP 4 — PIPELINE TEST
# --------------------------------------------------

if [ -d "codebrain_test_sandbox" ]; then
    python3 -m codebrain.main codebrain_test_sandbox || FAIL=1
    echo "✔ Pipeline ran"
fi

# --------------------------------------------------
# FINAL
# --------------------------------------------------

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✅ SYSTEM READY"
else
    echo "❌ SYSTEM NOT READY"
fi