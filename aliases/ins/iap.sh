#!/usr/bin/env bash
# Script Name: iap.sh
# ID: SCR-ID-20260317125850-UM9XW9TSAQ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: iap

# ============================================
# APT INSTALL TEMPLATE
# - auto-loads all .lst .txt .csv files
#   from the same folder as this script
# - non-interactive
# - color output
# - progress counter
# - continue on failure
# - skip already installed packages
# - retry failures once
# - save failed packages to a file
# ============================================

set -uo pipefail

# ---------- Non-interactive mode ----------
export DEBIAN_FRONTEND=noninteractive

# ---------- Colors ----------
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# ---------- Ctrl+C handler ----------
trap 'printf "\n${RED}⛔ Cancelled (Ctrl+C). Exiting cleanly.${RESET}\n"; exit 130' INT

# ---------- Script/file paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
BASE_NAME="${SCRIPT_NAME%.*}"
FAILED_LOG="$SCRIPT_DIR/${BASE_NAME}-failed.txt"

# ---------- Packages that may need dpkg-reconfigure after install ----------
RECONFIGURE_PACKAGES=(
  # libdvd-pkg
)

# ---------- Arrays ----------
PACKAGE_FILES=()
PACKAGES=()
INSTALLED=()
SKIPPED=()
FAILED=()

TOTAL=0
COUNT=0

# ---------- Helper functions ----------
log() {
  printf "%b%s%b\n" "$1" "$2" "$RESET"
}

progress() {
  local current="$1"
  local total="$2"
  local label="$3"
  printf "%b[%s/%s] %s%b\n" "$CYAN" "$current" "$total" "$label" "$RESET"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

wait_for_apt_lock() {
  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
     || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    log "$YELLOW" "Waiting for apt/dpkg lock..."
    sleep 2
  done
}

repair_apt() {
  wait_for_apt_lock
  log "$CYAN" "▶ Repairing partially configured packages..."
  sudo dpkg --configure -a || true

  wait_for_apt_lock
  log "$CYAN" "▶ Fixing broken dependencies..."
  sudo apt-get --fix-broken install -y || true
}

find_package_files() {
  local f

  for f in "$SCRIPT_DIR"/*.lst "$SCRIPT_DIR"/*.txt "$SCRIPT_DIR"/*.csv; do
    [[ -f "$f" ]] && PACKAGE_FILES+=("$f")
  done

  if (( ${#PACKAGE_FILES[@]} == 0 )); then
    log "$RED" "No package files found next to the script."
    log "$YELLOW" "Add one or more .lst, .txt, or .csv files in:"
    printf '  %s\n' "$SCRIPT_DIR"
    exit 1
  fi
}

load_packages() {
  local file ext line part
  local -a parts

  for file in "${PACKAGE_FILES[@]}"; do
    log "$CYAN" "▶ Loading package file: $(basename "$file")"
    ext="${file##*.}"

    case "$ext" in
      txt|lst)
        while IFS= read -r line || [[ -n "$line" ]]; do
          line="${line%%#*}"
          line="$(trim "$line")"
          [[ -z "$line" ]] && continue
          PACKAGES+=("$line")
        done < "$file"
        ;;
      csv)
        while IFS= read -r line || [[ -n "$line" ]]; do
          line="${line%%#*}"
          line="$(trim "$line")"
          [[ -z "$line" ]] && continue

          IFS=',' read -ra parts <<< "$line"
          for part in "${parts[@]}"; do
            part="$(trim "$part")"
            [[ -z "$part" ]] && continue
            PACKAGES+=("$part")
          done
        done < "$file"
        ;;
      *)
        log "$YELLOW" "Skipping unsupported file: $file"
        ;;
    esac
  done
}

dedupe_packages() {
  mapfile -t PACKAGES < <(printf '%s\n' "${PACKAGES[@]}" | awk 'NF && !seen[$0]++')
}

apt_install_one() {
  local pkg="$1"

  if is_installed "$pkg"; then
    log "$YELLOW" "↷ Already installed: $pkg"
    SKIPPED+=("$pkg")
    return 0
  fi

  wait_for_apt_lock
  if sudo apt-get install -y "$pkg"; then
    log "$GREEN" "✔ Installed: $pkg"
    INSTALLED+=("$pkg")
  else
    log "$RED" "✘ Failed: $pkg"
    FAILED+=("$pkg")
  fi
}

retry_failed_once() {
  if ((${#FAILED[@]} == 0)); then
    return 0
  fi

  log "$CYAN" "▶ Retrying failed packages once..."
  local retry_list=("${FAILED[@]}")
  local still_failed=()
  FAILED=()

  for pkg in "${retry_list[@]}"; do
    wait_for_apt_lock
    if sudo apt-get install -y "$pkg"; then
      log "$GREEN" "✔ Installed on retry: $pkg"
      INSTALLED+=("$pkg")
    else
      log "$RED" "✘ Still failed: $pkg"
      still_failed+=("$pkg")
    fi
  done

  FAILED=("${still_failed[@]}")
}

reconfigure_special_packages() {
  local pkg
  for pkg in "${RECONFIGURE_PACKAGES[@]}"; do
    if is_installed "$pkg"; then
      log "$CYAN" "▶ Reconfiguring: $pkg"
      sudo dpkg-reconfigure -f noninteractive "$pkg" || true
    fi
  done
}

# ---------- Start ----------
find_package_files
load_packages
dedupe_packages
TOTAL=${#PACKAGES[@]}

if (( TOTAL == 0 )); then
  log "$RED" "No packages were loaded from the package files."
  exit 1
fi

log "$CYAN" "▶ Script: $SCRIPT_NAME"
log "$CYAN" "▶ Found ${#PACKAGE_FILES[@]} package file(s)"
log "$CYAN" "▶ Loaded $TOTAL unique package(s)"

echo
log "$CYAN" "▶ Updating package lists..."
wait_for_apt_lock
sudo apt-get update -y

repair_apt

log "$CYAN" "▶ Upgrading installed packages..."
wait_for_apt_lock
sudo apt-get full-upgrade -y || true

echo

for pkg in "${PACKAGES[@]}"; do
  ((COUNT++))
  progress "$COUNT" "$TOTAL" "Processing: $pkg"
  apt_install_one "$pkg"
  echo
done

retry_failed_once
reconfigure_special_packages

# ---------- Summary ----------
echo "========== SUMMARY =========="

log "$GREEN" "Installed: ${#INSTALLED[@]}"
if ((${#INSTALLED[@]})); then
  printf '  %s\n' "${INSTALLED[@]}"
fi

echo
log "$YELLOW" "Skipped: ${#SKIPPED[@]}"
if ((${#SKIPPED[@]})); then
  printf '  %s\n' "${SKIPPED[@]}"
fi

echo
log "$RED" "Failed: ${#FAILED[@]}"
if ((${#FAILED[@]})); then
  printf '  %s\n' "${FAILED[@]}"
  printf '%s\n' "${FAILED[@]}" > "$FAILED_LOG"
  echo
  log "$YELLOW" "Failed package list saved to: $FAILED_LOG"
else
  log "$GREEN" "All requested packages processed successfully."
fi
