#!/usr/bin/env bash
# Script Name: ibun.sh
# ID: SCR-ID-20260317125942-4ENDW78LMY
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ibun

set -e

# ============================
# Bun Installer Script
# ============================

# Ctrl+C handler
trap 'echo -e "\n⛔ Cancelled. Exiting cleanly."; exit 130' INT

echo "🚀 Installing Bun..."

# ----------------------------
# Run official Bun installer
# ----------------------------
curl -fsSL https://bun.sh/install | bash

# ----------------------------
# Detect shell
# ----------------------------
SHELL_NAME="$(basename "$SHELL")"
BUN_DIR="$HOME/.bun"
BUN_BIN="$BUN_DIR/bin"
EXPORT_LINE='export PATH="$HOME/.bun/bin:$PATH"'

# ----------------------------
# Add to PATH safely
# ----------------------------
add_to_rc() {
    local rc_file="$1"

    if [[ -f "$rc_file" ]]; then
        if ! grep -q '\.bun/bin' "$rc_file"; then
            echo "" >> "$rc_file"
            echo "# Bun runtime" >> "$rc_file"
            echo "$EXPORT_LINE" >> "$rc_file"
            echo "✔ Added Bun to PATH in $rc_file"
        else
            echo "ℹ Bun already in PATH in $rc_file"
        fi
    fi
}

case "$SHELL_NAME" in
    bash)
        add_to_rc "$HOME/.bashrc"
        ;;
    zsh)
        add_to_rc "$HOME/.zshrc"
        ;;
    *)
        echo "⚠️ Unknown shell ($SHELL_NAME)."
        echo "   Manually add this to your shell config:"
        echo "   $EXPORT_LINE"
        ;;
esac

# ----------------------------
# Load PATH for current session
# ----------------------------
export PATH="$BUN_BIN:$PATH"

# ----------------------------
# Verify install
# ----------------------------
if command -v bun >/dev/null 2>&1; then
    echo ""
    echo "✅ Bun installed successfully!"
    bun --version
else
    echo ""
    echo "❌ Bun install failed or PATH not active yet."
    echo "   Restart your terminal or source your shell config."
    exit 1
fi

echo ""
echo "🔥 Ready to use Bun."
echo "   Try: bun init, bun install, bun run"
