#!/usr/bin/env bash
# Script Name: st-kex.sh
# ID: SCR-ID-20260328145523-1G3OLEDCVM
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: st-kex

set -Eeuo pipefail

# =========================================================
# Script Name: set-kex-zsh-default.sh
# Purpose:
#   Make zsh the preferred shell in Kali / WSL / Win-KeX
#
# What it does:
#   1) Ensures zsh is installed
#   2) Sets login shell to zsh for target user
#   3) Adds bashrc fallback to exec zsh when bash starts
#   4) Ensures ~/.zshrc exists
#   5) Optionally configures XFCE Terminal to launch zsh
#
# Notes:
#   - Safe for Kali in WSL / Win-KeX
#   - Does not modify your resolver scripts
#   - Best run as your normal user, not root
#
# Usage:
#   bash set-kex-zsh-default.sh
#   bash set-kex-zsh-default.sh --user shadowwalker
#   bash set-kex-zsh-default.sh --no-xfce
# =========================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

TARGET_USER=""
CONFIGURE_XFCE=1

log()  { printf '%b\n' "${CYAN}▶ $*${RESET}"; }
ok()   { printf '%b\n' "${GREEN}✔ $*${RESET}"; }
warn() { printf '%b\n' "${YELLOW}⚠ $*${RESET}"; }
err()  { printf '%b\n' "${RED}✘ $*${RESET}" >&2; }

usage() {
  cat <<'EOF'
Usage:
  bash set-kex-zsh-default.sh [options]

Options:
  --user NAME     Target username to configure
  --no-xfce       Do not configure XFCE Terminal custom command
  -h, --help      Show this help

Examples:
  bash set-kex-zsh-default.sh
  bash set-kex-zsh-default.sh --user shadowwalker
  bash set-kex-zsh-default.sh --no-xfce
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || { err "Missing value for --user"; exit 1; }
      TARGET_USER="$2"
      shift 2
      ;;
    --no-xfce)
      CONFIGURE_XFCE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

resolve_target_user() {
  if [[ -n "$TARGET_USER" ]]; then
    return 0
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  else
    TARGET_USER="${USER:-}"
  fi

  [[ -n "$TARGET_USER" ]] || {
    err "Could not determine target user."
    exit 1
  }
}

resolve_home_dir() {
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  [[ -n "${TARGET_HOME:-}" && -d "${TARGET_HOME:-}" ]] || {
    err "Could not resolve home directory for user: $TARGET_USER"
    exit 1
  }
}

run_as_target() {
  if [[ "$(id -un)" == "$TARGET_USER" ]]; then
    "$@"
  else
    sudo -u "$TARGET_USER" "$@"
  fi
}

ensure_zsh_installed() {
  if have_cmd zsh; then
    ok "zsh is already installed."
    return 0
  fi

  log "zsh not found. Installing..."
  sudo apt update
  sudo apt install -y zsh
  have_cmd zsh || {
    err "zsh install appears to have failed."
    exit 1
  }
  ok "Installed zsh."
}

resolve_zsh_path() {
  ZSH_PATH="$(command -v zsh || true)"
  [[ -n "$ZSH_PATH" ]] || {
    err "Unable to locate zsh after install."
    exit 1
  }

  if ! grep -qxF "$ZSH_PATH" /etc/shells; then
    log "Adding $ZSH_PATH to /etc/shells"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi

  ok "Using zsh at: $ZSH_PATH"
}

set_login_shell() {
  local current_shell
  current_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"

  if [[ "$current_shell" == "$ZSH_PATH" ]]; then
    ok "Login shell already set to zsh for user: $TARGET_USER"
    return 0
  fi

  log "Changing login shell for $TARGET_USER -> $ZSH_PATH"
  sudo chsh -s "$ZSH_PATH" "$TARGET_USER" || {
    err "Failed to change login shell for $TARGET_USER"
    exit 1
  }

  ok "Login shell updated for $TARGET_USER"
}

ensure_zshrc() {
  local zshrc="$TARGET_HOME/.zshrc"

  if [[ -f "$zshrc" ]]; then
    ok ".zshrc already exists: $zshrc"
    return 0
  fi

  if [[ -f /etc/skel/.zshrc ]]; then
    log "Creating .zshrc from /etc/skel/.zshrc"
    sudo cp /etc/skel/.zshrc "$zshrc"
    sudo chown "$TARGET_USER:$TARGET_USER" "$zshrc"
    ok "Created $zshrc"
  else
    log "Creating minimal .zshrc"
    cat <<'EOF' | sudo tee "$zshrc" >/dev/null
# ~/.zshrc
autoload -Uz compinit
compinit
EOF
    sudo chown "$TARGET_USER:$TARGET_USER" "$zshrc"
    ok "Created minimal $zshrc"
  fi
}

ensure_bashrc_fallback() {
  local bashrc="$TARGET_HOME/.bashrc"
  local marker_start="# >>> force-zsh-in-wsl-kex >>>"
  local marker_end="# <<< force-zsh-in-wsl-kex <<<"

  [[ -f "$bashrc" ]] || {
    log "No .bashrc found. Creating one."
    sudo touch "$bashrc"
    sudo chown "$TARGET_USER:$TARGET_USER" "$bashrc"
  }

  if grep -qF "$marker_start" "$bashrc"; then
    ok ".bashrc fallback block already present."
    return 0
  fi

  log "Adding bash -> zsh fallback block to $bashrc"
  cat <<EOF | sudo tee -a "$bashrc" >/dev/null

$marker_start
# Auto-switch interactive bash shells into zsh.
# Keeps WSL / Win-KeX terminal sessions consistent.
if [[ -n "\${PS1:-}" ]] && command -v zsh >/dev/null 2>&1; then
  if [[ -z "\${ZSH_VERSION:-}" ]]; then
    exec zsh
  fi
fi
$marker_end
EOF

  sudo chown "$TARGET_USER:$TARGET_USER" "$bashrc"
  ok "Added bash fallback block."
}

configure_xfce_terminal() {
  [[ "$CONFIGURE_XFCE" -eq 1 ]] || {
    warn "Skipping XFCE Terminal config by request."
    return 0
  }

  local xfce_dir="$TARGET_HOME/.config/xfce4/terminal"
  local accels="$xfce_dir/terminalrc"

  mkdir -p "$xfce_dir"
  sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

  if [[ -f "$accels" ]]; then
    cp "$accels" "${accels}.bak.$(date +%Y%m%d%H%M%S)"
    chown "$TARGET_USER:$TARGET_USER" "${accels}".bak.*
  fi

  if [[ ! -f "$accels" ]]; then
    log "Creating XFCE Terminal config: $accels"
    cat <<EOF > "$accels"
[Configuration]
CommandLoginShell=FALSE
CommandUpdateRecords=FALSE
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=100x28
MiscInheritGeometry=FALSE
MiscMenubarDefault=TRUE
MiscMouseAutohide=FALSE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscHighlightUrls=TRUE
ScrollingLines=10000
ShortcutsNoMenukey=TRUE
FontName=Monospace 10
ColorCursorUseDefault=TRUE
ColorSelectionUseDefault=TRUE
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.950000
RunCustomCommand=TRUE
CustomCommand=${ZSH_PATH}
EOF
    chown "$TARGET_USER:$TARGET_USER" "$accels"
    ok "Created XFCE Terminal config to launch zsh."
    return 0
  fi

  log "Updating XFCE Terminal config to launch zsh"
  python3 - "$accels" "$ZSH_PATH" <<'PY'
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
zsh = sys.argv[2]

text = cfg.read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines()

if "[Configuration]" not in text:
    lines.insert(0, "[Configuration]")

def set_key(lines, key, value):
    prefix = key + "="
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            lines[i] = f"{key}={value}"
            return lines
    insert_at = 0
    for i, line in enumerate(lines):
        if line.strip() == "[Configuration]":
            insert_at = i + 1
            break
    lines.insert(insert_at, f"{key}={value}")
    return lines

lines = set_key(lines, "RunCustomCommand", "TRUE")
lines = set_key(lines, "CustomCommand", zsh)

cfg.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

  sudo chown "$TARGET_USER:$TARGET_USER" "$accels"
  ok "Updated XFCE Terminal config."
}

show_results() {
  local passwd_shell
  passwd_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"

  printf '\n'
  printf '%b\n' "${CYAN}========== RESULT ==========${RESET}"
  printf 'Target user   : %s\n' "$TARGET_USER"
  printf 'Home          : %s\n' "$TARGET_HOME"
  printf 'zsh path      : %s\n' "$ZSH_PATH"
  printf 'Login shell   : %s\n' "$passwd_shell"
  printf 'bash fallback : %s\n' "$TARGET_HOME/.bashrc"
  if [[ "$CONFIGURE_XFCE" -eq 1 ]]; then
    printf 'XFCE config   : %s\n' "$TARGET_HOME/.config/xfce4/terminal/terminalrc"
  fi
  printf '%b\n' "${CYAN}============================${RESET}"
  printf '\n'
  printf '%b\n' "${YELLOW}Restart recommendation:${RESET}"
  printf '  1) close Win-KeX sessions\n'
  printf '  2) run: kex stop\n'
  printf '  3) from Windows PowerShell/CMD run: wsl --shutdown\n'
  printf '  4) relaunch Kali / Win-KeX\n'
  printf '\n'
  printf '%b\n' "${YELLOW}Verify after restart:${RESET}"
  printf '  echo $SHELL\n'
  printf '  echo $0\n'
  printf '  ps -p $$\n'
}

main() {
  resolve_target_user
  resolve_home_dir

  log "Configuring preferred shell for user: $TARGET_USER"
  ensure_zsh_installed
  resolve_zsh_path
  set_login_shell
  ensure_zshrc
  ensure_bashrc_fallback
  configure_xfce_terminal
  show_results
}

main "$@"
