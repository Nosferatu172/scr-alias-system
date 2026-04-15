#!/usr/bin/env bash
# Script Name: zshsetup.sh
# ID: SCR-ID-20260412154049-73YV1UJ76R
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: zshsetup
set -e

echo "======================================"
echo " WSL ZSH / P10K STARTUP CLEANER"
echo "======================================"

BACKUP="$HOME/zsh_backup_$(date +%s)"
mkdir -p "$BACKUP"

echo "[1/6] Backing up configs to: $BACKUP"

cp -f ~/.zshrc "$BACKUP/.zshrc" 2>/dev/null || true
cp -f ~/.bashrc "$BACKUP/.bashrc" 2>/dev/null || true

echo "[2/6] Fixing Powerlevel10k wizard spam..."

# Prevent config wizard from ever triggering
if ! grep -q "POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD" ~/.zshrc 2>/dev/null; then
  echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc
fi

echo "[3/6] Disabling Oh My Zsh auto-update prompts..."

if ! grep -q "zstyle ':omz:update' mode disabled" ~/.zshrc 2>/dev/null; then
  echo "zstyle ':omz:update' mode disabled" >> ~/.zshrc
fi

echo "[4/6] Preventing bash -> zsh recursion issues..."

if grep -q "exec zsh" ~/.bashrc 2>/dev/null; then
  sed -i '/exec zsh/d' ~/.bashrc
fi

cat << 'EOF' >> ~/.bashrc

# WSL-safe zsh launch (prevents recursion + login spam)
if [ -t 1 ] && [ -z "$ZSH_VERSION" ]; then
  exec zsh
fi
EOF

echo "[5/6] Cleaning broken or repeated installer lines..."

# Remove accidental repeated Oh My Zsh installer lines
sed -i '/oh-my-zsh install/d' ~/.zshrc 2>/dev/null || true
sed -i '/curl.*ohmyzsh/d' ~/.zshrc 2>/dev/null || true

echo "[6/6] Ensuring safe Zsh + p10k load order..."

# Make sure p10k loads cleanly once
if ! grep -q "p10k.zsh" ~/.zshrc 2>/dev/null; then
  cat << 'EOF' >> ~/.zshrc

# =========================
# CLEAN POWERLEVEL10K LOAD
# =========================
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF
fi

echo ""
echo "======================================"
echo " DONE"
echo "======================================"
echo ""
echo "NEXT STEPS:"
echo "1. Restart WSL terminal"
echo "2. Run: p10k configure (only once if needed)"
echo ""
echo "Backup saved at:"
echo "$BACKUP"
