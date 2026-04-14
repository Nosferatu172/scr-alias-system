#!/usr/bin/env bash
# Script Name: link_codebrain.sh
# ID: SCR-ID-20260412153235-MN1AJYXXRV
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: link_codebrain

set -e

echo "🧠 CODEBRAIN SYSTEM LINKER INSTALLER"
echo "===================================="

# --------------------------------------------------
# CONFIG
# --------------------------------------------------

REPO_PATH="/mnt/c/scr/zpy/dupdetector"
VENV_PATH="$HOME/.codebrain_venv"

# --------------------------------------------------
# SAFETY CHECKS
# --------------------------------------------------

if [ ! -d "$REPO_PATH/codebrain" ]; then
    echo "❌ CodeBrain not found at:"
    echo "   $REPO_PATH/codebrain"
    exit 1
fi

# --------------------------------------------------
# ENSURE VENV EXISTS
# --------------------------------------------------

echo "🐍 Ensuring environment..."

if [ ! -d "$VENV_PATH" ]; then
    python3 -m venv "$VENV_PATH"
fi

source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

# --------------------------------------------------
# FIX BROKEN INSTALL STATE
# --------------------------------------------------

echo "🧹 Cleaning previous installs (safe mode)..."

pip uninstall -y codebrain >/dev/null 2>&1 || true

# --------------------------------------------------
# INSTALL IN EDITABLE MODE
# --------------------------------------------------

echo "📦 Installing CodeBrain in editable mode..."

cd "$REPO_PATH"

pip install -e .

# --------------------------------------------------
# VERIFY IMPORT STRUCTURE
# --------------------------------------------------

echo "🔍 Verifying import integrity..."

python - << 'EOF'
import codebrain
from codebrain.main import main
print("✅ CodeBrain import OK")
EOF

if [ $? -ne 0 ]; then
    echo "❌ Import failed — fixing sys.path issues likely required"
    exit 1
fi

# --------------------------------------------------
# CREATE GLOBAL COMMAND LINK
# --------------------------------------------------

echo "⚙️ Creating global CLI command..."

sudo bash -c 'cat > /usr/local/bin/codebrain << EOF
#!/usr/bin/env bash
source "$HOME/.codebrain_venv/bin/activate"
python3 /mnt/c/scr/zpy/dupdetector/codebrain/main.py "$@"
EOF'

sudo chmod +x /usr/local/bin/codebrain

# --------------------------------------------------
# OPTIONAL: FIX PYTHON PATH CLEANLY
# --------------------------------------------------

echo "🧠 Creating Python path safety shim..."

mkdir -p "$REPO_PATH/codebrain/_bootstrap"

cat > "$REPO_PATH/codebrain/_bootstrap/path_fix.py" << 'EOF'
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
EOF

# --------------------------------------------------
# FINAL TEST
# --------------------------------------------------

echo "🧪 Testing CLI..."

codebrain --help || python3 "$REPO_PATH/codebrain/main.py" --help

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo ""
echo "===================================="
echo "✅ CODEBRAIN LINKER INSTALLED"
echo "===================================="
echo ""
echo "👉 Now you can run:"
echo "   codebrain <path>"
echo ""
echo "👉 Or via SCR:"
echo "   scr codebrain <path>"
echo ""
echo "===================================="
