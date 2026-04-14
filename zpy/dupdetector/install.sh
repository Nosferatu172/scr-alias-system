#!/usr/bin/env bash
set -e

echo "🧠===================================="
echo "   CODEBRAIN INSTALL (FINAL)"
echo "===================================="

ROOT="$(pwd)"
VENV="$ROOT/.venv"
BIN="$ROOT/.bin"

# --------------------------------------------------
# SYSTEM DEPS
# --------------------------------------------------

if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip git
fi

# --------------------------------------------------
# VENV SETUP
# --------------------------------------------------

echo "🐍 Setting up virtual environment..."

if [ ! -d "$VENV" ]; then
    python3 -m venv "$VENV"
fi

source "$VENV/bin/activate"

pip install --upgrade pip setuptools wheel

# --------------------------------------------------
# DEPENDENCIES
# --------------------------------------------------

echo "📚 Installing dependencies..."

pip install numpy gitpython pytest tqdm

# optional AI layer
if [ "$CB_FULL_AI" = "1" ]; then
    pip install sentence-transformers
fi

# --------------------------------------------------
# CLI TOOL
# --------------------------------------------------

echo "⚙ Creating CLI..."

mkdir -p "$BIN"

cat > "$BIN/cb" << 'EOF'
#!/usr/bin/env bash

ROOT="$(pwd)"
source "$ROOT/.venv/bin/activate"

export PYTHONPATH="$ROOT"

case "$1" in
    run)
        shift
        python3 -m codebrain.main "$@"
        ;;
    verify)
        bash verify_core_integrity.sh
        ;;
    *)
        echo "cb commands:"
        echo "  cb run <path>"
        echo "  cb verify"
        ;;
esac
EOF

chmod +x "$BIN/cb"

# --------------------------------------------------
# GLOBAL LINK (optional)
# --------------------------------------------------

if [ -d "/usr/local/bin" ]; then
    sudo ln -sf "$BIN/cb" /usr/local/bin/cb
fi

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo ""
echo "🧠 INSTALL COMPLETE"
echo "===================================="
echo "Run:"
echo "  cb run ./project"
echo "===================================="