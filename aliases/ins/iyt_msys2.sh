#!/usr/bin/env bash
# Script Name: iyt_msys2.sh
# ID: SCR-ID-20260412153229-22UCLX31UU
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: iyt_msys2

pacman -S mingw-w64-x86_64-ffmpeg
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

# Ensure wget exists
step "Install wget if missing" \
  bash -c "command -v wget >/dev/null || pacman -Sy --noconfirm wget"

step "Change to home directory" \
  cd ~

step "Download latest yt-dlp binary (.exe for Windows)" \
  wget -O yt-dlp.exe https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe

step "Move yt-dlp to MSYS2 bin directory" \
  mv yt-dlp.exe /usr/bin/

step "Verify installation" \
  yt-dlp --version

step "Update yt-dlp to master version (optional)" \
  yt-dlp --update-to master

printf "${CYAN}✅ Completed yt-dlp installation successfully.${RESET}\n"
