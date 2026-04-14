#!/usr/bin/env bash
# Script Name: bash.sh
# ID: SCR-ID-20260412153804-MZWKR8JF78
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: bash

# ----------------------------
# CORE ENVIRONMENT
# ----------------------------
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCR_ROOT="$(cd "$CORE_DIR/.." && pwd)"

# ----------------------------
# RUNTIME EXECUTOR
# ----------------------------
SCRIPT_PATH="$1"
shift || true

if [ -z "$SCRIPT_PATH" ]; then
  echo "[bash-runtime] No script provided"
  exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "[bash-runtime] Script not found: $SCRIPT_PATH"
  exit 1
fi

# ----------------------------
# EXECUTE SCRIPT
# ----------------------------
exec bash "$SCRIPT_PATH" "$@"
