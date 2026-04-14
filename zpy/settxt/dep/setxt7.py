#!/usr/bin/env python3
# Script Name: setxt4_auto.py
# URL Extractor (CLI + Non-Destructive + CSV Logging)

import os
import re
import sys
import signal
import argparse
import csv
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
def get_candidate_roots():
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

    valid.sort(key=lambda x: len(x[2]), reverse=True)
    return valid[0]


# -----------------------
# PROCESS
# -----------------------
def process_files(files, output_dir: Path):
    urls = set()

    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
            urls.update(URL_RE.findall(text))
        except:
            continue

    if not urls:
        print("❌ No valid URLs found.")
        return None

    sorted_urls = sorted(urls)

    output_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = unique_file(output_dir / f"exported-tabs_{ts}.txt")

    out_file.write_text("\n".join(sorted_urls) + "\n", encoding="utf-8")

    print(f"\n✅ Exported {len(sorted_urls)} URLs")
    print(f"📁 Output: {out_file}")

    return out_file


# -----------------------
# CSV LOGGING
# -----------------------
def log_run(env, mode, root, input_dir, output_dir):
    script_dir = Path(__file__).resolve().parent
    log_dir = script_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    csv_path = log_dir / "setxt4_dirs.csv"

    write_header = not csv_path.exists()

    with open(csv_path, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)

        if write_header:
            writer.writerow(["timestamp", "env", "mode", "root", "input_dir", "output_dir"])

        ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

        writer.writerow([
            ts,
            env,
            mode,
            str(root) if root else "",
            str(input_dir),
            str(output_dir),
        ])


# -----------------------
# MAIN
# -----------------------
def main():
    parser = argparse.ArgumentParser(
        prog="setxt4",
        description="Extract URLs from .txt files (auto-detect, non-destructive, logged).",
    )

    parser.add_argument("-e", "--envdir", help="Override root directory (expects /brave inside)")
    parser.add_argument("-d", "--dir", help="Direct input directory (skip /brave detection)")
    parser.add_argument("-o", "--output", help="Override output directory")
    parser.add_argument("-l", "--list", action="store_true", help="List detected/default paths")

    args = parser.parse_args()

    env = detect_env()
    roots = get_candidate_roots()

    # -----------------------
    # LIST MODE
    # -----------------------
    if args.list:
        print(f"\n🧠 Environment: {env}")
        print("\n📂 Default roots:")
        for r in roots:
            print(f"  - {r}")

        if args.envdir:
            print(f"\n🔧 Override root (-e): {args.envdir}")
        if args.dir:
            print(f"📥 Direct input (-d): {args.dir}")
        if args.output:
            print(f"📤 Output override (-o): {args.output}")

        return

    # -----------------------
    # INPUT RESOLUTION
    # -----------------------
    if args.dir:
        input_dir = Path(args.dir).expanduser()

        if not input_dir.exists():
            print(f"❌ Input directory not found: {input_dir}")
            sys.exit(1)

        files = [f for f in input_dir.glob("*.txt") if contains_url(f)]
        root = None
        mode = "direct"

    else:
        if args.envdir:
            roots = [Path(args.envdir).expanduser()]
            mode = "override"
        else:
            mode = "auto"

        root, brave_dir, files = find_active_root(roots)

        if not root:
            print("❌ No valid /brave/ directory found.")
            sys.exit(1)

        input_dir = brave_dir

    # -----------------------
    # OUTPUT RESOLUTION
    # -----------------------
    if args.output:
        output_dir = Path(args.output).expanduser()
    else:
        output_dir = (root if root else input_dir) / "archives"

    # -----------------------
    # RUN
    # -----------------------
    print(f"\n🧠 Environment: {env}")
    print(f"📂 Input:  {input_dir}")
    print(f"📄 Files:  {len(files)}")
    print(f"📁 Output: {output_dir}")

    process_files(files, output_dir)

    # -----------------------
    # LOG
    # -----------------------
    log_run(env, mode, root, input_dir, output_dir)

    print("\n🎉 Done (non-destructive, logged).")


if __name__ == "__main__":
    main()
