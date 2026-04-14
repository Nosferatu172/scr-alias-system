#!/usr/bin/env bash
# Script Name: fixzshpath.sh
# ID: SCR-ID-20260412153132-L6E09PHGUO
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: fixzshpath

set -euo pipefail

ZSHRC="$HOME/.zshrc"
BACKUP="$HOME/.zshrc.bak.$(date +%s)"

echo "🧠 ZSH PATH SELF-HEALER"
echo "======================="

# Backup first (always)
cp "$ZSHRC" "$BACKUP"
echo "📦 Backup saved to: $BACKUP"

# Temp file
TMP="$(mktemp)"

echo "🔍 Scanning and repairing PATH lines..."

while IFS= read -r line; do
  # Only target export PATH lines
  if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+PATH= ]]; then

    # Extract right side of PATH=
    rhs="${line#*PATH=}"

    # Remove surrounding quotes if present
    rhs="${rhs%\"}"
    rhs="${rhs#\"}"

    # Split on colon
    IFS=':' read -ra PARTS <<< "$rhs"

    CLEANED=()

    for part in "${PARTS[@]}"; do
      # Trim whitespace
      part="$(echo "$part" | xargs)"

      # Skip empty
      [[ -z "$part" ]] && continue

      # Fix Windows paths with spaces → escape them
      part="${part// /\\ }"

      CLEANED+=("$part")
    done

    # Remove duplicates
    UNIQUE=()
    for p in "${CLEANED[@]}"; do
      [[ " ${UNIQUE[*]} " =~ " $p " ]] || UNIQUE+=("$p")
    done

    # Rebuild line safely
    echo "export PATH=\"$(IFS=:; echo "${UNIQUE[*]}"):\$PATH\"" >> "$TMP"

  else
    echo "$line" >> "$TMP"
  fi
done < "$ZSHRC"

# Replace original
mv "$TMP" "$ZSHRC"

echo "✅ PATH repaired."

# Ensure Deno path exists (your original goal)
if ! grep -q '\.deno/bin' "$ZSHRC"; then
  echo 'export PATH="$HOME/.deno/bin:$PATH"' >> "$ZSHRC"
  echo "➕ Added Deno to PATH"
fi

echo ""
echo "🚀 Reloading config..."
source "$ZSHRC"

echo "🎉 Done. Your shell should be clean now."
echo "👉 Run: echo \$PATH"
