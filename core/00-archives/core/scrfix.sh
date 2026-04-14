#!/bin/bash
# scrfix.sh — Reset SCR environment cleanly

echo "[SCRFIX] Resetting environment..."

# -------------------------
# UNSET VARIABLES
# -------------------------
unset CORE_DIR
unset SCR_ROOT

# -------------------------
# REMOVE FUNCTIONS
# -------------------------
unset -f scr 2>/dev/null
unset -f scr0 2>/dev/null

# -------------------------
# CLEAR HASH CACHE
# -------------------------
hash -r

# -------------------------
# FIND RCN FILE
# -------------------------
RCN="/mnt/c/scr/core/rcn.txt"

if [[ ! -f "$RCN" ]]; then
    echo "[SCRFIX] ERROR: rcn.txt not found at $RCN"
    return 1 2>/dev/null || exit 1
fi

# -------------------------
# SOURCE CLEANLY
# -------------------------
echo "[SCRFIX] Reloading SCR..."

source "$RCN"

# -------------------------
# VERIFY
# -------------------------
echo "[SCRFIX] Verifying..."

echo -n "CORE_DIR = "
echo "$CORE_DIR"

echo ""
type scr 2>/dev/null || echo "[SCRFIX] scr not loaded"
type scr0 2>/dev/null || echo "[SCRFIX] scr0 not loaded"

# -------------------------
# TEST PATHS
# -------------------------
if [[ -f "$CORE_DIR/dispatcher.sh" ]]; then
    echo "[SCRFIX] dispatcher OK"
else
    echo "[SCRFIX] dispatcher MISSING"
fi

if [[ -f "$CORE_DIR/editor.sh" ]]; then
    echo "[SCRFIX] editor OK"
else
    echo "[SCRFIX] editor MISSING"
fi

echo ""
echo "[SCRFIX] Done."
