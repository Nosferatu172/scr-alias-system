#!/usr/bin/env bash
# Script Name: ikali-kex.sh
# ID: SCR-ID-20260317130013-XOVC58R1U5
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ikali-kex

set -uo pipefail

export DEBIAN_FRONTEND=noninteractive

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

PACKAGES=(
  kali-win-kex
)

FAILED=()
TOTAL=${#PACKAGES[@]}
COUNT=0

sudo apt-get update -y
sudo apt-get full-upgrade -y

for pkg in "${PACKAGES[@]}"; do
  ((COUNT++))
  echo -e "${CYAN}[${COUNT}/${TOTAL}] Processing: ${pkg}${RESET}"

  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo -e "${YELLOW}↷ Already installed: ${pkg}${RESET}"
  elif sudo apt-get install -y "$pkg"; then
    echo -e "${GREEN}✔ Installed: ${pkg}${RESET}"
  else
    echo -e "${RED}✘ Failed: ${pkg}${RESET}"
    FAILED+=("$pkg")
  fi

  echo
done

if ((${#FAILED[@]})); then
  printf '%s\n' "${FAILED[@]}" > failed-apt-packages.txt
  echo -e "${YELLOW}Failed list saved to: failed-apt-packages.txt${RESET}"
fi
