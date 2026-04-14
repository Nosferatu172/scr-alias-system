#!/bin/bash
# Script Name: acc-build-and-register.sh
# FINAL CORRECT VERSION (MATCHES YOUR TREE)

# ----------------------------
# LOAD ENV
# ----------------------------
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

ALIAS_ROOT="$SCR_ROOT/aliases"
BSH_ROOT="$SCR_ROOT/bsh"
OUT_DIR="$GEN_DIR"
MAP="$INDEX_DIR/commands.map"
CORE_FILE="$OUT_DIR/core.sh"

mkdir -p "$OUT_DIR/bash" "$OUT_DIR/bsh" "$OUT_DIR/python" "$OUT_DIR/ruby" "$OUT_DIR/zsh"
mkdir -p "$(dirname "$MAP")"

echo "[*] Building SCR system..."

# ----------------------------
# HELPERS
# ----------------------------
safe_name() {
    echo "scr_${1//[^a-zA-Z0-9_]/_}"
}

is_reserved() {
    case "$1" in
        time|cd|pwd|eval|exec|echo|read|kill|test|set|unset|export)
            return 0 ;;
    esac
    return 1
}

register() {
    local file="$1"
    local ext="$2"
    local out="$3"

    base=$(basename "$file" ."$ext")

    if is_reserved "$base"; then
        echo "[SKIP reserved] $base"
        return
    fi

    func=$(safe_name "$base")

    case "$ext" in
        sh)  echo "$func() { bash \"$file\" \"\$@\"; }" >> "$out" ;;
        py)  echo "$func() { python3 \"$file\" \"\$@\"; }" >> "$out" ;;
        rb)  echo "$func() { ruby \"$file\" \"\$@\"; }" >> "$out" ;;
        zsh) echo "$func() { zsh \"$file\" \"\$@\"; }" >> "$out" ;;
    esac
}

# ----------------------------
# RESET OUTPUTS
# ----------------------------
: > "$OUT_DIR/bash/aliases.sh"
: > "$OUT_DIR/bsh/bsh.sh"
: > "$OUT_DIR/python/tools.sh"
: > "$OUT_DIR/ruby/tools.sh"
: > "$OUT_DIR/zsh/tools.sh"
: > "$CORE_FILE"
: > "$MAP"

# ============================
# 🔵 BUILD MAIN BASH LAYER
# ============================
echo "[*] Building bash layer from /aliases/**"

find "$ALIAS_ROOT" -type f -name "*.sh" | while read -r f; do
    register "$f" "sh" "$OUT_DIR/bash/aliases.sh"
done

# ============================
# 🟣 BUILD NEW BSH LAYER
# ============================
echo "[*] Building bsh layer from /bsh/**"

find "$BSH_ROOT" -type f -name "*.sh" | while read -r f; do
    register "$f" "sh" "$OUT_DIR/bsh/bsh.sh"
done

# ============================
# 🟡 OTHER LANGUAGES
# ============================
find "$SCR_ROOT/zpy" -type f -name "*.py" | while read -r f; do
    register "$f" "py" "$OUT_DIR/python/tools.sh"
done

find "$SCR_ROOT/zru" -type f -name "*.rb" | while read -r f; do
    register "$f" "rb" "$OUT_DIR/ruby/tools.sh"
done

find "$ALIAS_ROOT/zsh" -type f -name "*.zsh" | while read -r f; do
    register "$f" "zsh" "$OUT_DIR/zsh/tools.sh"
done

# ============================
# 🟢 REGISTER EVERYTHING
# ============================
echo "[*] Building core.sh + commands.map"

for f in "$OUT_DIR"/*/*.sh; do
    [[ -f "$f" ]] || continue

    echo "source \"$f\"" >> "$CORE_FILE"

    name="$(basename "$f" .sh)"
    if [[ "$name" != *"generated"* ]]; then
        echo "$name=$f" >> "$MAP"
    fi
done

echo "[✔] SCR SYSTEM BUILT CORRECTLY"
