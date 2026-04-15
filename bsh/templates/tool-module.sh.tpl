#!/usr/bin/env bash

# ============================================
# Tool Name: __SCRIPT_NAME__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
# ============================================

# ==================================================
# LOAD GUARD (like your vpy pattern)
# ==================================================

if [[ -n "${__SCRIPT_NAME_UPPER___LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
__SCRIPT_NAME_UPPER___LOADED=1


# ==================================================
# STATE
# ==================================================

__SCRIPT_NAME_UPPER___STATE=""
__SCRIPT_NAME_UPPER___ACTIVE_PATH=""

# ==================================================
# UTILS
# ==================================================

log()  { printf '%s\n' "$*"; }
ok()   { printf '✅ %s\n' "$*"; }
err()  { printf '❌ %s\n' "$*" >&2; }
warn() { printf '⚠️ %s\n' "$*"; }

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

realpath_fallback() {
  if cmd_exists realpath; then
    realpath "$1"
  else
    python3 - <<'PY' "$1"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
  fi
}

cwd() {
  pwd
}

# ==================================================
# CORE FUNCTIONS (REPLACE THIS SECTION PER TOOL)
# ==================================================

__SCRIPT_NAME__:_do_action() {
  local input="$1"

  # -------------------------
  # YOUR LOGIC HERE
  # -------------------------

  ok "Processed: $input"
}

__SCRIPT_NAME__:_status() {
  echo "state: $__SCRIPT_NAME_UPPER___STATE"
  echo "active: $__SCRIPT_NAME_UPPER___ACTIVE_PATH"
}

__SCRIPT_NAME__:_init() {
  __SCRIPT_NAME_UPPER___STATE="running"
  ok "Initialized __SCRIPT_NAME__"
}

__SCRIPT_NAME__:_reset() {
  __SCRIPT_NAME_UPPER___STATE="idle"
  __SCRIPT_NAME_UPPER___ACTIVE_PATH=""
  ok "Reset __SCRIPT_NAME__"
}

# ==================================================
# HELP
# ==================================================

__SCRIPT_NAME__:_help() {
cat <<EOF

__SCRIPT_NAME__

Usage:
  __SCRIPT_NAME__ <command> [args]

Commands:
  init        initialize tool
  run         run main logic
  status      show state
  reset       reset state
  help        show help

EOF
}

# ==================================================
# DISPATCHER (IMPORTANT PART)
# ==================================================

__SCRIPT_NAME__() {
  case "${1:-help}" in
    init)
      __SCRIPT_NAME__:_init
      ;;
    run)
      shift
      __SCRIPT_NAME__:_do_action "$@"
      ;;
    status)
      __SCRIPT_NAME__:_status
      ;;
    reset)
      __SCRIPT_NAME__:_reset
      ;;
    help|-h|--help)
      __SCRIPT_NAME__:_help
      ;;
    *)
      err "Unknown command: $1"
      __SCRIPT_NAME__:_help
      return 1 2>/dev/null || exit 1
      ;;
  esac
}
