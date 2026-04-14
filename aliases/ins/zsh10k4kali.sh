#!/usr/bin/env bash
# Script Name: zsh10k4kali.sh
# ID: SCR-ID-20260412153406-YL2RKZLOD9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: zsh10k4kali

set -e

echo "=================================="
echo " Kali WSL + Powerlevel10k Setup"
echo "=================================="

echo "[1/6] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "[2/6] Installing Zsh + dependencies..."
sudo apt install -y zsh git curl wget

echo "[3/6] Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "Oh My Zsh already installed."
fi

echo "[4/6] Installing Powerlevel10k theme..."
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 \
  https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"
else
  echo "Powerlevel10k already installed."
fi

echo "[5/6] Configuring .zshrc..."

ZSHRC="$HOME/.zshrc"

# Set theme
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
fi

# Optional plugins (safe defaults)
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC" 2>/dev/null || \
echo 'plugins=(git)' >> "$ZSHRC"

echo "[6/6] Setting Zsh as default shell..."
chsh -s "$(which zsh)" || echo "chsh failed (common in WSL, using fallback)"

# WSL fallback: force zsh on startup if needed
if ! grep -q "exec zsh" "$HOME/.bashrc"; then
  echo 'exec zsh' >> "$HOME/.bashrc"
fi

echo ""
echo "=================================="
echo " Installation complete!"
echo "=================================="
echo ""
echo "NEXT STEPS (IMPORTANT):"
echo "1. Restart your WSL terminal"
echo "2. Install a Nerd Font on Windows:"
echo "   Recommended: MesloLGS NF"
echo ""
echo "3. In Windows Terminal:"
echo "   Settings → Kali → Font → MesloLGS NF"
echo ""
echo "4. Run configuration wizard:"
echo "   p10k configure"
echo ""
echo "Done."
