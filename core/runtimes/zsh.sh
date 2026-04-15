#!/usr/bin/env zsh
# Script Name: zsh.sh
# ID: SCR-ID-20260412153817-710A6YF0AB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: zsh
# SCR Runtime: Zsh Executor
# Fully portable, resolves paths relative to itself

# ----------------------------
# CORE ENVIRONMENT
# ----------------------------
CORE_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
SCR_ROOT="$(cd "$CORE_DIR/.." && pwd)"

# ----------------------------
# RUNTIME EXECUTOR
# ----------------------------
SCRIPT_PATH="$1"
shift || true

if [[ -z "$SCRIPT_PATH" ]]; then
  echo "[zsh-runtime] No script provided"
  exit 1
fi

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "[zsh-runtime] Script not found: $SCRIPT_PATH"
  exit 1
fi

# ----------------------------
# EXECUTE SCRIPT
# ----------------------------
exec zsh "$SCRIPT_PATH" "$@"
