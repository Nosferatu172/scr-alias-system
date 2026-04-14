#!/usr/bin/env bash
# Script Name: tools-menu.sh
# ID: SCR-ID-20260329042856-9U2O0BZWQ8
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: tools-menu

# === Title ===
SCRIPT_TITLE="=== WSL Preferred Tools Menu ==="

# === Menu Items (Label: Command to Run) ===
declare -A MENU_ITEMS=(
  ["Install All Preferred Tools"]="for f in /d/scr-pac/aliases/pre/tools/*.sh; do bash \"\$f\"; done"
  ["Install Keyboard Tools"]="for f in /d/scr-pac/aliases/pre/tools/keyboard/*.sh; do bash \"\$f\"; done"
  ["Install ZSH Tools"]="for f in /d/scr-pac/aliases/pre/tools/zsh/*.sh; do bash \"\$f\"; done"
  ["Install yt-dlp"]="for f in /d/scr-pac/aliases/pre/tools/install-ytdlp/*.sh; do bash \"\$f\"; done"
  ["Install Ollama"]="for f in /d/scr-pac/aliases/pre/tools/ollama/*.sh; do bash \"\$f\"; done"
  ["Install PhantomJS"]="for f in /d/scr-pac/aliases/pre/tools/phantom/*.sh; do bash \"\$f\"; done"
  ["Install Ruby"]="for f in /d/scr-pac/aliases/pre/tools/ruby/*.sh; do bash \"\$f\"; done"
  ["Install Ruby Gems"]="for f in /d/scr-pac/aliases/pre/tools/ruby/tools/*.sh; do bash \"\$f\"; done"
  ["Install Sample Tools"]="for f in /d/scr-pac/aliases/pre/tools/sample/*.sh; do bash \"\$f\"; done"
  ["Install Substitutes"]="for f in /d/scr-pac/aliases/pre/tools/substitutes/*.sh; do bash \"\$f\"; done"
  ["Install Mine (Personal)"]="for f in /d/scr-pac/aliases/pre/tools/install-mine/*.sh; do bash \"\$f\"; done"
  ["Install Kali Specific"]="for f in /d/scr-pac/aliases/pre/tools/kali/common/lib/*.sh; do bash \"\$f\"; done"
)

# === Menu Loop ===
while true; do
  clear
  echo "$SCRIPT_TITLE"
  echo "Select a tool group to install:"
  echo

  i=1
  MENU_KEYS=()
  for key in "${!MENU_ITEMS[@]}"; do
    echo "$i) $key"
    MENU_KEYS+=("$key")
    ((i++))
  done

  echo "$i) Exit"
  echo
  read -p "Choice [1-$i]: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
    key="${MENU_KEYS[$((choice - 1))]}"
    echo -e "\n▶ Running: $key\n"
    bash -c "${MENU_ITEMS[$key]}"
    echo -e "\n✅ Done. Press Enter to return to menu."
    read
  elif [ "$choice" -eq "$i" ]; then
    echo "👋 Exiting..."
    break
  else
    echo "❌ Invalid selection."
    sleep 1
  fi
done
