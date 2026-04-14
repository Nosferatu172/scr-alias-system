#!/usr/bin/env bash
# Script Name: cd_picker.sh
# ID: SCR-ID-20260329043006-F4RD2JV86Y
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cd_picker

cdf() {
  local cwd choice
  cwd="$(pwd)"

  echo ""
  echo "📂 Current directory:"
  echo "$cwd"
  echo ""

  # Use ls to list only directories (portable, fast)
  # -p appends / to directories; we filter those and strip the /
  local i=0
  local -a dirs=()

  while IFS= read -r line; do
    # line ends with /
    line="${line%/}"
    dirs+=("$line")
    printf "%2d: %s\n" "$i" "$line"
    i=$((i+1))
  done < <(LC_ALL=C ls -1p 2>/dev/null | grep '/$' || true)

  if ((${#dirs[@]} == 0)); then
    echo "❌ No subdirectories here."
    return 0
  fi

  echo ""
  echo "Select a directory number (Enter to cancel, .. to go up):"
  printf "> "
  IFS= read -r choice || return 0
  [[ -z "$choice" ]] && return 0

  if [[ "$choice" == ".." ]]; then
    cd .. || return 1
    return 0
  fi

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < ${#dirs[@]} )); then
    cd "${dirs[$choice]}" || return 1
    return 0
  fi

  echo "❌ Invalid selection."
  return 1
}
