#!/usr/bin/env bash
# Script Name: set-us-english.sh
# ID: SCR-ID-20260317130607-QR3M0HSGBX
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: set-us-english

set -euo pipefail

# =========================================================
# set-us-english.sh
# Force Kali Linux system locale to US English
# =========================================================

TARGET_LOCALE="en_US.UTF-8"
LOCALE_GEN_FILE="/etc/locale.gen"
DEFAULT_LOCALE_FILE="/etc/default/locale"

if [[ "${EUID}" -ne 0 ]]; then
  echo "❌ Please run this script as root:"
  echo "   sudo bash $0"
  exit 1
fi

echo "▶ Updating package lists..."
apt update

echo "▶ Ensuring locale support packages are installed..."
apt install -y locales

echo "▶ Enabling ${TARGET_LOCALE} in ${LOCALE_GEN_FILE} ..."
if grep -Eq '^[#[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8' "${LOCALE_GEN_FILE}"; then
  sed -i 's/^[#[:space:]]*\(en_US\.UTF-8[[:space:]]\+UTF-8\)/\1/' "${LOCALE_GEN_FILE}"
else
  echo "${TARGET_LOCALE} UTF-8" >> "${LOCALE_GEN_FILE}"
fi

echo "▶ Generating locales..."
locale-gen "${TARGET_LOCALE}"

echo "▶ Setting system default locale..."
update-locale LANG="${TARGET_LOCALE}" LC_ALL="${TARGET_LOCALE}" LANGUAGE="en_US:en"

echo "▶ Writing ${DEFAULT_LOCALE_FILE} ..."
cat > "${DEFAULT_LOCALE_FILE}" <<EOF
LANG=${TARGET_LOCALE}
LC_ALL=${TARGET_LOCALE}
LANGUAGE=en_US:en
EOF

echo "▶ Applying locale for current session where possible..."
export LANG="${TARGET_LOCALE}"
export LC_ALL="${TARGET_LOCALE}"
export LANGUAGE="en_US:en"

echo
echo "✅ Locale has been set to US English."
echo
echo "Current locale output:"
locale || true

echo
echo "⚠️ You should now log out and back in, or reboot, for all apps and the desktop to fully switch."
