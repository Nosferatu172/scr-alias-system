#!/usr/bin/env bash

# ----------------------------
# CORE ENVIRONMENT
# ----------------------------
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCR_ROOT="$(cd "$CORE_DIR/.." && pwd)"

INDEX_DIR="$CORE_DIR/index"
GEN_DIR="$INDEX_DIR/generated"

# Debug
# echo "[env] CORE_DIR=$CORE_DIR"
# echo "[env] SCR_ROOT=$SCR_ROOT"