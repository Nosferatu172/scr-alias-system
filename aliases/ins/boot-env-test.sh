#!/usr/bin/env bash
# Script Name: boot-env-test.sh
# ID: SCR-ID-20260412153114-29RQVZFBCZ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: boot-env-test

set -e

echo "🚀 CodeBrain bootstrap starting..."

# 1. Create venv
if [ ! -d ".venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
fi

# 2. Activate venv
echo "⚡ Activating virtual environment..."
source .venv/bin/activate

# 3. Upgrade pip
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# 4. Install dependencies
echo "📚 Installing dependencies..."
pip install pytest requests openai sentence-transformers numpy

# 5. Install CodeBrain (editable)
echo "🧠 Installing CodeBrain..."
pip install -e /mnt/c/scr/zpy/dupdetector

# 6. Run tests
echo "🧪 Running pytest..."
pytest || true

echo "✅ Bootstrap complete!"
echo "👉 To activate later: source .venv/bin/activate"
