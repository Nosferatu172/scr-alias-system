#!/usr/bin/env bash
# Script Name: ideno.sh
# ID: SCR-ID-20260317125952-HGAHIND95V
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ideno

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

trap 'printf "\n${RED}⛔ Cancelled (Ctrl+C). Exiting cleanly.${RESET}\n"; exit 130' INT

step() {
  local label="$1"
  shift
  printf "${CYAN}▶ Starting: %s${RESET}\n" "$label"
  "$@"
  printf "${GREEN}✔ Completed: %s${RESET}\n\n" "$label"
}

# ----------------------------
# System update
# ----------------------------
#step "apt-get update"   sudo apt-get -y update
#step "apt-get upgrade"  sudo apt-get -y upgrade

# ----------------------------
# Deno install + upgrade
# ----------------------------
step "Install Deno (install.sh)" bash -c 'curl -fsSL https://deno.land/install.sh | sh'

# Make deno available immediately
export PATH="$HOME/.deno/bin:$PATH"

# Persist PATH for future zsh sessions
ZSHRC="$HOME/.zshrc"
DENO_PATH_LINE='export PATH="$HOME/.deno/bin:$PATH"'
step "Ensure Deno PATH in ~/.zshrc" bash -c '
  set -e
  ZSHRC="'"$ZSHRC"'"
  LINE="'"$DENO_PATH_LINE"'"
  touch "$ZSHRC"
  grep -qxF "$LINE" "$ZSHRC" 2>/dev/null || echo "$LINE" >> "$ZSHRC"
'

step "Deno version check" deno --version
step "deno upgrade" deno upgrade

printf "${CYAN}✅ Completed system update + Deno setup.${RESET}\n"
printf "${CYAN}Tip:${RESET} To load PATH changes now: source ~/.zshrc\n"
