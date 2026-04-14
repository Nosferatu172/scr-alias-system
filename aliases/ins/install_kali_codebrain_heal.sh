#!/usr/bin/env bash
# Script Name: install_kali_codebrain_heal.sh
# ID: SCR-ID-20260412153223-SFF31Z490R
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: install_kali_codebrain_heal

set -e

echo "🧠 CODEBRAIN SELF-HEALING INSTALLER (KALI)"
echo "========================================="

# --------------------------------------------------
# CONFIG
# --------------------------------------------------

VENV_PATH="$HOME/.codebrain_venv"
REPO_PATH="/mnt/c/scr/zpy/dupdetector"

REPAIR_MODE=false

if [ "$1" == "--repair" ]; then
    REPAIR_MODE=true
    echo "🔧 Repair mode enabled"
fi

# --------------------------------------------------
# SYSTEM CHECK + REPAIR
# --------------------------------------------------

echo "📦 Checking system dependencies..."

missing_sys=()

for pkg in git curl wget python3 python3-pip python3-venv; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing_sys+=("$pkg")
done

if [ ${#missing_sys[@]} -gt 0 ]; then
    echo "⚠️ Missing system packages: ${missing_sys[*]}"
    sudo apt update
    sudo apt install -y \
        git curl wget python3 python3-pip python3-venv \
        build-essential cmake ninja-build rustc cargo \
        libatlas-base-dev libopenblas-dev liblapack-dev
else
    echo "✅ System dependencies OK"
fi

# --------------------------------------------------
# VENV HEALTH CHECK
# --------------------------------------------------

echo "🐍 Checking Python environment..."

if [ ! -d "$VENV_PATH" ]; then
    echo "❌ venv missing → creating new one"
    python3 -m venv "$VENV_PATH"
fi

source "$VENV_PATH/bin/activate"

# check python integrity
if ! python -c "import sys" >/dev/null 2>&1; then
    echo "❌ Python venv broken → rebuilding"
    rm -rf "$VENV_PATH"
    python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
fi

# --------------------------------------------------
# PIP SELF-HEAL
# --------------------------------------------------

echo "📚 Upgrading pip + core tooling..."

pip install --upgrade pip setuptools wheel

# detect broken imports
python - << 'EOF'
broken = []
for m in ["numpy", "sentence_transformers", "openai", "pytest"]:
    try:
        __import__(m)
    except:
        broken.append(m)

if broken:
    print("BROKEN:", broken)
    exit(1)
EOF

if [ $? -ne 0 ] || [ "$REPAIR_MODE" = true ]; then
    echo "🔧 Repairing Python dependencies..."
    pip install \
        numpy \
        pytest \
        requests \
        sentence-transformers \
        openai \
        tqdm \
        networkx \
        gitpython
else
    echo "✅ Python deps healthy"
fi

# --------------------------------------------------
# CODEBRAIN INSTALL / REPAIR
# --------------------------------------------------

echo "🧠 Checking CodeBrain installation..."

if [ -d "$REPO_PATH" ]; then
    pip install -e "$REPO_PATH"
else
    echo "⚠️ CodeBrain repo missing at $REPO_PATH"
fi

# --------------------------------------------------
# MODEL HEALTH CHECK (EMBEDDINGS)
# --------------------------------------------------

echo "🤖 Checking embedding model..."

python - << 'EOF'
try:
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    print("✅ Embedding model OK")
except Exception as e:
    print("❌ Embedding model failed:", e)
    exit(1)
EOF

if [ $? -ne 0 ] || [ "$REPAIR_MODE" = true ]; then
    echo "🔧 Re-downloading embedding model..."
    python - << 'EOF'
from sentence_transformers import SentenceTransformer
SentenceTransformer("all-MiniLM-L6-v2")
EOF
fi

# --------------------------------------------------
# SCR CHECK
# --------------------------------------------------

echo "⚙️ Checking SCR launcher..."

if command -v scr >/dev/null 2>&1; then
    echo "✅ SCR available"
else
    echo "⚠️ SCR missing (install launcher separately)"
fi

# --------------------------------------------------
# FINAL SELF-TEST
# --------------------------------------------------

echo "🧪 Running system self-test..."

python - << 'EOF'
tests = []

try:
    import numpy
    tests.append("numpy OK")
except:
    tests.append("numpy FAIL")

try:
    import sentence_transformers
    tests.append("embeddings OK")
except:
    tests.append("embeddings FAIL")

print("\n".join(tests))

if any("FAIL" in t for t in tests):
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo "❌ Self-test failed → run with --repair"
    exit 1
fi

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo ""
echo "========================================="
echo "✅ CODEBRAIN SYSTEM HEALTHY"
echo "========================================="
echo ""
echo "👉 Activate:"
echo "   source $VENV_PATH/bin/activate"
echo ""
echo "👉 Repair mode:"
echo "   ./install_kali_codebrain_heal.sh --repair"
echo ""
echo "👉 Run CodeBrain:"
echo "   scr codebrain /mnt/c/scr/zpy/dupdetector/codebrain"
echo ""
