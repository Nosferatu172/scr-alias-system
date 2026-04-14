#!/usr/bin/env python3
from pathlib import Path
import subprocess

CORE = Path(__file__).resolve().parent
SCR_ROOT = CORE.parent
RCN = CORE / "rcn.txt"
MARKER = "# >>> SCR BOOTSTRAP >>>"

def generate_rcn():
    # Find all generated language folders dynamically
    generated_dir = CORE / "index" / "generated"
    folders = [p for p in generated_dir.iterdir() if p.is_dir()]

    # Build the shell loop snippet
    sources = ""
    for folder in sorted(folders):
        for f in folder.glob("*.sh"):
            sources += f'    "{f}" \\\n'

    # Compose content
    content = f"""# =====================================
# SCR BOOTSTRAP (AUTO-GENERATED)
# =====================================

CORE_DIR="{CORE}"
SCR_ROOT="{SCR_ROOT}"

# --- shared libs ---
if [ -d "$SCR_ROOT/aliases/lib" ]; then
    for libfile in "$SCR_ROOT/aliases/lib/"*; do
        [ -f "$libfile" ] && source "$libfile"
    done
fi

# --- entrypoint ---
scr() {{
    "$CORE_DIR/dispatcher.sh" "$@"
}}

scr0() {{
    "$CORE_DIR/editor.sh" "$@"
}}

# --- generated commands ---
for f in \\
{sources}do
    [ -f "$f" ] && source "$f"
done
"""
    RCN.write_text(content)
    print(f"✔ Generated rcn.txt at {RCN}")

def inject_file(path: Path):
    path.touch(exist_ok=True)
    content = path.read_text()
    if MARKER in content:
        parts = content.split(MARKER)
        content = parts[0] + parts[-1]
    snippet = f"""

{MARKER}
source "{RCN}"
{MARKER}
"""
    path.write_text(content + snippet)
    print(f"✔ Injected into {path}")

def inject_root():
    root_files = ["/root/.bashrc", "/root/.zshrc"]
    for f in root_files:
        try:
            subprocess.run(
                ["sudo", "bash", "-c", f'''
FILE="{f}"
MARKER="{MARKER}"
RCN="{RCN}"

[ -f "$FILE" ] || touch "$FILE"
CONTENT=$(cat "$FILE")
if echo "$CONTENT" | grep -q "$MARKER"; then
    CONTENT=$(echo "$CONTENT" | awk -v m="$MARKER" '
        BEGIN {{found=0}}
        $0 ~ m {{found=!found; next}}
        !found {{print}}
    ')
fi
echo "$CONTENT" > "$FILE"
cat >> "$FILE" <<EOF

$MARKER
source "$RCN"
$MARKER
EOF
'''],
                check=True
            )
            print(f"✔ Injected into {f}")
        except Exception:
            print(f"[!] Could not modify {f} (permission issue?)")

def main():
    print("[*] SCR bootstrap installer starting...")
    generate_rcn()
    inject_file(Path.home() / ".bashrc")
    inject_file(Path.home() / ".zshrc")
    inject_root()
    print("✔ SCR bootstrap installation complete")

if __name__ == "__main__":
    main()
