#!/usr/bin/env bash
# Script Name: iyt.sh
# ID: SCR-ID-20260317130218-MNC7NHQ74G
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: iyt

set -euo pipefail

# --------------------------------------------
# Colors
# --------------------------------------------
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

# --------------------------------------------
# Steps (unchanged behavior)
# --------------------------------------------

step "Change to home directory" \
  cd ~

step "Download latest yt-dlp binary" \
  wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp

step "Make yt-dlp executable" \
  chmod +x yt-dlp

step "Move yt-dlp to /usr/local/bin" \
  sudo mv yt-dlp /usr/local/bin/

step "yt-dlp self-update" \
  yt-dlp -U

step "Update yt-dlp to master version" \
  yt-dlp --update-to master

printf "${CYAN}✅ Completed yt-dlp installation successfully.${RESET}\n"
