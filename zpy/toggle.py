#!/usr/bin/env python3
"""
SCR Path Toggle v2 (Hardened)

Usage:
    toggle.py -wsl | -msys | -linux
    toggle.py -wsl --dry
    toggle.py -msys --diff
    toggle.py -linux --jobs 8

Features:
✔ Safe regex replacement
✔ CRLF normalization
✔ Dry run + diff preview
✔ Shell validation (auto-revert)
✔ Parallel processing
✔ Skips generated + dangerous files
"""

import sys
import re
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# ----------------------------
# CONFIG
# ----------------------------
PATH_WSL   = "/mnt/c/scr/"
PATH_MSYS  = "/c/scr/"
PATH_LINUX = "/scr/"

EXTENSIONS = (".sh", ".zsh", ".py", ".rb", ".txt")

EXCLUDE_DIRS = {
    ".git",
    "__pycache__",
    "index/generated",
}

EXCLUDE_FILES = {
    "rcn.txt",  # generated bootstrap — DO NOT TOUCH
}

SELF = Path(__file__).resolve()
ROOT = SELF.parent

# ----------------------------
# FLAGS
# ----------------------------
DRY_RUN = "--dry" in sys.argv
SHOW_DIFF = "--diff" in sys.argv

def get_jobs():
    if "--jobs" in sys.argv:
        i = sys.argv.index("--jobs")
        try:
            return int(sys.argv[i + 1])
        except:
            pass
    return 1

JOBS = get_jobs()

# ----------------------------
# REGEX SETUP
# ----------------------------
PATH_PATTERN = re.compile(
    rf"({re.escape(PATH_WSL)}|{re.escape(PATH_MSYS)}|{re.escape(PATH_LINUX)})"
)

# ----------------------------
# HELPERS
# ----------------------------
def is_text_file(file: Path):
    try:
        with file.open("r", encoding="utf-8") as f:
            f.read(512)
        return True
    except:
        return False

def is_excluded(file: Path):
    if file.name in EXCLUDE_FILES:
        return True
    return any(ex in str(file) for ex in EXCLUDE_DIRS)

def normalize(text: str):
    text = text.replace("\r\n", "\n")  # CRLF fix
    return text

def force_replace(text: str, target: str):
    return PATH_PATTERN.sub(target, text)

def validate_shell(file: Path):
    if file.suffix in (".sh", ".zsh"):
        result = subprocess.run(
            ["bash", "-n", str(file)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return result.returncode == 0
    return True

def show_diff(old, new, file):
    print(f"\n--- {file}")
    print("+++ modified")
    for line_old, line_new in zip(old.splitlines(), new.splitlines()):
        if line_old != line_new:
            print(f"- {line_old}")
            print(f"+ {line_new}")

# ----------------------------
# PROCESS FILE
# ----------------------------
def process_file(file: Path, target: str):
    if file.resolve() == SELF or is_excluded(file):
        return 0

    try:
        text = file.read_text(errors="ignore")
    except:
        return 0

    if not any(p in text for p in (PATH_WSL, PATH_MSYS, PATH_LINUX)):
        return 0

    original = text
    text = normalize(text)
    new_text = force_replace(text, target)

    if new_text == original:
        return 0

    if SHOW_DIFF:
        show_diff(original, new_text, file)

    if DRY_RUN:
        print(f"[DRY] {file}")
        return 1

    # write + validate
    file.write_text(new_text)

    if not validate_shell(file):
        print(f"[REVERT ❌] syntax error: {file}")
        file.write_text(original)
        return 0

    print(f"[✔] {file}")
    return 1

# ----------------------------
# ARG PARSE
# ----------------------------
def parse_args():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]

    if len(args) != 1:
        print("Usage: toggle.py -wsl | -msys | -linux [--dry] [--diff] [--jobs N]")
        sys.exit(1)

    arg = args[0].lower()

    if arg == "-wsl":
        return PATH_WSL
    elif arg == "-msys":
        return PATH_MSYS
    elif arg == "-linux":
        return PATH_LINUX
    else:
        print("Invalid flag.")
        sys.exit(1)

# ----------------------------
# MAIN
# ----------------------------
def main():
    target = parse_args()

    print(f"[*] Root: {ROOT}")
    print(f"[*] Mode → {target}")
    print(f"[*] Jobs → {JOBS}")
    if DRY_RUN:
        print("[*] DRY RUN enabled")
    if SHOW_DIFF:
        print("[*] DIFF mode enabled")

    files = [f for f in ROOT.rglob("*") if f.is_file()]

    total = 0

    if JOBS > 1:
        with ThreadPoolExecutor(max_workers=JOBS) as exe:
            results = exe.map(lambda f: process_file(f, target), files)
            total = sum(results)
    else:
        for f in files:
            total += process_file(f, target)

    print(f"\n[✔] Done. {total} files updated.")

# ----------------------------
if __name__ == "__main__":
    main()
