#!/usr/bin/env python3
# Script Name: setxt4_auto.py
# Adaptive URL TXT Processor (Brave Pipeline)

import os
import re
import sys
import shutil
import signal
from pathlib import Path
from datetime import datetime

# -----------------------
# CONFIG
# -----------------------
URL_RE = re.compile(r"https?://\S+", re.IGNORECASE)

# -----------------------
# CTRL+C HANDLER
# -----------------------
def handle_sigint(sig, frame):
    print("\n⛔ Interrupted. Exiting cleanly.")
    sys.exit(130)

signal.signal(signal.SIGINT, handle_sigint)

# -----------------------
# ENV DETECTION
# -----------------------
def detect_env():
    if "WSL_DISTRO_NAME" in os.environ:
        return "wsl"
    if os.name == "nt":
        if "MSYSTEM" in os.environ:
            return "msys2"
        return "windows"
    return "linux"

# -----------------------
# ROOT PATHS
# -----------------------
def get_candidate_roots(env):
    return [
        Path("/mnt/c/scr/keys/tabs/"),
        Path("/c/scr/keys/tabs/"),
        Path.home() / "shadowwalker" / "Documents",
        Path.cwd(),
    ]

# -----------------------
# HELPERS
# -----------------------
def contains_url(file: Path) -> bool:
    try:
        text = file.read_text(encoding="utf-8", errors="ignore")
        return bool(URL_RE.search(text))
    except:
        return False


def unique_file(path: Path) -> Path:
    if not path.exists():
        return path

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = path.stem
    ext = path.suffix

    candidate = path.with_name(f"{base}_{ts}{ext}")
    if not candidate.exists():
        return candidate

    i = 1
    while True:
        candidate = path.with_name(f"{base}_{ts}_{i}{ext}")
        if not candidate.exists():
            return candidate
        i += 1


# -----------------------
# FIND ACTIVE ROOT
# -----------------------
def find_active_root(roots):
    valid = []

    for root in roots:
        brave_dir = root / "brave"

        if not brave_dir.exists():
            continue

        txt_files = list(brave_dir.glob("*.txt"))
        if not txt_files:
            continue

        valid_files = [f for f in txt_files if contains_url(f)]

        if valid_files:
            valid.append((root, brave_dir, valid_files))

    if not valid:
        return None, None, []

    # pick root with most valid files
    valid.sort(key=lambda x: len(x[2]), reverse=True)
    return valid[0]


# -----------------------
# PROCESS FILES
# -----------------------
def process_files(files, completed_dir: Path):
    urls = set()

    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
            found = URL_RE.findall(text)
            urls.update(found)
        except:
            continue

    if not urls:
        print("❌ No valid URLs found.")
        return None

    sorted_urls = sorted(urls)

    completed_dir.mkdir(parents=True, exist_ok=True)

    out_file = unique_file(completed_dir / "exported-tabs.txt")

    out_file.write_text("\n".join(sorted_urls) + "\n", encoding="utf-8")

    print(f"\n✅ Exported {len(sorted_urls)} URLs")
    print(f"📁 Output: {out_file}")

    return out_file


# -----------------------
# ARCHIVE
# -----------------------
def archive_source(src_dir: Path, archive_dir: Path):
    archive_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_base = archive_dir / f"tabs_backup_{ts}"

    shutil.make_archive(str(archive_base), "zip", src_dir)

    print(f"🗄️ Archive created: {archive_base}.zip")


# -----------------------
# MOVE PROCESSED FILES
# -----------------------
def move_processed(files, completed_dir: Path):
    raw_dir = completed_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    moved = 0

    for f in files:
        try:
            dest = raw_dir / f.name

            if dest.exists():
                dest = unique_file(dest)

            f.rename(dest)
            moved += 1
        except Exception as e:
            print(f"⚠️ Failed to move {f}: {e}")

    print(f"📦 Moved {moved} file(s) → {raw_dir}")


# -----------------------
# MAIN
# -----------------------
def main():
    env = detect_env()
    print(f"🧠 Environment: {env}")

    roots = get_candidate_roots(env)

    print("\n🔍 Scanning roots:")
    for r in roots:
        print(f"  - {r}")

    root, brave_dir, files = find_active_root(roots)

    if not root:
        print("\n❌ No valid /brave/ directory with URL files found.")
        sys.exit(1)

    print(f"\n✅ Active root: {root}")
    print(f"📂 Using: {brave_dir}")
    print(f"📄 Files detected: {len(files)}")

    completed_dir = root / "completed"
    archive_dir = root / "archive"

    # PROCESS
    output = process_files(files, completed_dir)

    if not output:
        sys.exit(1)

    # ARCHIVE
    archive_source(brave_dir, archive_dir)

    # MOVE ORIGINALS
    move_processed(files, completed_dir)

    print("\n🎉 Done.")


if __name__ == "__main__":
    main()
