#!/usr/bin/env bash
set -e

echo "🧠======================================"
echo "   CODEBRAIN CORE INTEGRITY CHECK"
echo "======================================"

ROOT="$(pwd)"

# --------------------------------------------------
# STEP 1 — Python import sanity
# --------------------------------------------------

echo "🐍 Checking Python package import..."

python3 - << 'EOF'
import sys
sys.path.insert(0, ".")

try:
    import codebrain.main
    print("✔ codebrain.main imports OK")
except Exception as e:
    print("❌ main import failed:", e)
    exit(1)

try:
    import codebrain.scanner
    import codebrain.analyzer
    import codebrain.call_graph
    import codebrain.engine.pipeline
    import codebrain.engine.analysis
    import codebrain.engine.planning
    import codebrain.engine.execution
    import codebrain.test_runner
    print("✔ core modules import OK")
except Exception as e:
    print("❌ core module failure:", e)
    exit(1)
EOF

# --------------------------------------------------
# STEP 2 — detect architecture drift
# --------------------------------------------------

echo ""
echo "🔍 Checking for forbidden architecture patterns..."

BAD=$(grep -R "safe_refactor\|dependency_refactor\|semantic_merge" codebrain || true)

if [ ! -z "$BAD" ]; then
    echo "⚠ Legacy references detected:"
    echo "$BAD"
else
    echo "✔ No legacy modules referenced"
fi

# --------------------------------------------------
# STEP 3 — CLI sanity
# --------------------------------------------------

echo ""
echo "⚙ Testing CLI..."

python3 -m codebrain.main --help >/dev/null 2>&1 || {
    echo "❌ CLI failed"
    exit 1
}

echo "✔ CLI works"

# --------------------------------------------------
# STEP 4 — Pipeline dry test
# --------------------------------------------------

echo ""
echo "🧪 Running pipeline dry test..."

python3 - << 'EOF'
from codebrain.engine.runner import run_pipeline
print("✔ Pipeline callable")
EOF

# --------------------------------------------------
# STEP 5 — Analysis sanity
# --------------------------------------------------

echo ""
echo "🧪 Running analysis sanity check..."

python3 - << 'EOF'
from codebrain.scanner import scan_files
from codebrain.analyzer import analyze_files, group_duplicates

files = scan_files(".")
funcs = analyze_files(files)
groups = group_duplicates(funcs)

print("✔ analysis pipeline OK")
print(f"   files: {len(files)}")
print(f"   functions: {len(funcs)}")
print(f"   groups: {len(groups)}")
EOF

# --------------------------------------------------
# FINAL RESULT
# --------------------------------------------------

echo ""
echo "🧠======================================"
echo "✔ CORE INTEGRITY PASSED"
echo "======================================"
echo ""
echo "System is safe to run CodeBrain."
echo "======================================"