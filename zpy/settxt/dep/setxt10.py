#!/usr/bin/env python3
# setxt4_auto.py

import os
import re
import sys
import signal
import argparse
import csv
import json
from pathlib import Path
from datetime import datetime

URL_RE = re.compile(r"https?://\S+", re.IGNORECASE)

# -----------------------
# CTRL+C
# -----------------------
def handle_sigint(sig, frame):
    print("\n⛔ Interrupted.")
    sys.exit(130)

signal.signal(signal.SIGINT, handle_sigint)

# -----------------------
# HELP PAGE
# -----------------------
def show_help():
    print(r"""
═══════════════════════════════════════════════════════════════
  SETXT4 — URL Extractor (Adaptive / Non-Destructive)
═══════════════════════════════════════════════════════════════

🧠 DESCRIPTION
  Extracts URLs from .txt files, deduplicates, sorts, and
  writes a clean output file. Automatically detects environment
  and working directories.

───────────────────────────────────────────────────────────────
⚙️ USAGE

  setxt4 [options]

───────────────────────────────────────────────────────────────
📥 INPUT MODES (priority)

  -d <dir>     Direct input directory
  -a           Use current working directory
  -e <dir>     Override root (expects /brave)
  (default)    Auto-detect /brave from config

───────────────────────────────────────────────────────────────
📤 OUTPUT

  -o <dir>     Output directory
  (default)    <root>/archives/

───────────────────────────────────────────────────────────────
🧪 MODES

  --dry-run    No file write

───────────────────────────────────────────────────────────────
⚙️ CONFIG

  -i           Interactive config
  -l           List config

  Config:
    ./logs/config.json

───────────────────────────────────────────────────────────────
📊 LOGGING

  ./logs/setxt4_dirs.csv

───────────────────────────────────────────────────────────────
💡 EXAMPLES

  setxt4
  setxt4 -a
  setxt4 -a --dry-run
  setxt4 -d ./test
  setxt4 -e /mnt/c/scr/keys/tabs
  setxt4 -o ./archives
  setxt4 -i

═══════════════════════════════════════════════════════════════
""")

# -----------------------
# CONFIG
# -----------------------
def script_paths():
    base = Path(__file__).resolve().parent
    logs = base / "logs"
    cfg = logs / "config.json"
    return logs, cfg

def default_config():
    return {
        "roots": [
            "/mnt/c/scr/keys/tabs/",
            "/c/scr/keys/tabs/",
            str(Path.home() / "shadowwalker" / "Documents"),
            str(Path.cwd())
        ],
        "output": ""
    }

def load_config():
    logs, cfg_path = script_paths()
    logs.mkdir(parents=True, exist_ok=True)

    if cfg_path.exists():
        try:
            return json.loads(cfg_path.read_text())
        except:
            pass

    cfg = default_config()
    save_config(cfg)
    return cfg

def save_config(cfg):
    logs, cfg_path = script_paths()
    logs.mkdir(parents=True, exist_ok=True)
    cfg_path.write_text(json.dumps(cfg, indent=2))

# -----------------------
# ENV
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
# INTERACTIVE
# -----------------------
def interactive_menu(cfg):
    while True:
        print("\n=== setxt4 Config ===")
        print("[1] View")
        print("[2] Edit roots")
        print("[3] Add root")
        print("[4] Remove root")
        print("[5] Set output")
        print("[6] Reset")
        print("[0] Exit")

        c = input("Choice: ").strip()

        if c == "1":
            print(json.dumps(cfg, indent=2))

        elif c == "2":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = int(input("Index: ")) - 1
            cfg["roots"][idx] = input("New path: ")

        elif c == "3":
            cfg["roots"].append(input("Path: "))

        elif c == "4":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = int(input("Remove: ")) - 1
            cfg["roots"].pop(idx)

        elif c == "5":
            cfg["output"] = input("Output dir: ")

        elif c == "6":
            cfg = default_config()

        elif c == "0":
            save_config(cfg)
            return

# -----------------------
# HELPERS
# -----------------------
def contains_url(f):
    try:
        return bool(URL_RE.search(f.read_text(errors="ignore")))
    except:
        return False

def unique_file(path):
    if not path.exists():
        return path

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    base, ext = path.stem, path.suffix

    i = 0
    while True:
        name = f"{base}_{ts}" if i == 0 else f"{base}_{ts}_{i}"
        cand = path.with_name(name + ext)
        if not cand.exists():
            return cand
        i += 1

def find_active_root(roots):
    valid = []

    for r in roots:
        root = Path(r).expanduser()
        brave = root / "brave"

        if not brave.exists():
            continue

        txt = list(brave.glob("*.txt"))
        good = [f for f in txt if contains_url(f)]

        if good:
            valid.append((root, brave, good))

    if not valid:
        return None, None, []

    valid.sort(key=lambda x: len(x[2]), reverse=True)
    return valid[0]

def process(files, out_dir, dry=False):
    urls = set()

    for f in files:
        urls.update(URL_RE.findall(f.read_text(errors="ignore")))

    if not urls:
        print("❌ No URLs found")
        return

    print(f"🔎 {len(urls)} URLs")

    if dry:
        print("🧪 Dry-run")
        return

    out_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = unique_file(out_dir / f"exported-tabs_{ts}.txt")

    out.write_text("\n".join(sorted(urls)))
    print(f"✅ {out}")

def log_run(env, mode, root, inp, out):
    logs, _ = script_paths()
    csv_path = logs / "setxt4_dirs.csv"

    new = not csv_path.exists()

    with open(csv_path, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["timestamp","env","mode","root","input","output"])

        w.writerow([
            datetime.now().strftime("%Y-%m-%d_%H-%M-%S"),
            env, mode, root or "", inp, out
        ])

# -----------------------
# MAIN
# -----------------------
def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-h", "--help", action="store_true")
    parser.add_argument("-i", action="store_true")
    parser.add_argument("-e")
    parser.add_argument("-d")
    parser.add_argument("-a", action="store_true")
    parser.add_argument("-o")
    parser.add_argument("-l", action="store_true")
    parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()
    cfg = load_config()

    if args.help:
        show_help()
        return

    if args.i:
        interactive_menu(cfg)
        return

    if args.l:
        print(json.dumps(cfg, indent=2))
        return

    env = detect_env()
    roots = cfg["roots"]

    # INPUT PRIORITY
    if args.d:
        input_dir = Path(args.d)
        files = [f for f in input_dir.glob("*.txt") if contains_url(f)]
        root = None
        mode = "direct"

    elif args.a:
        input_dir = Path.cwd()
        files = [f for f in input_dir.glob("*.txt") if contains_url(f)]
        root = None
        mode = "active"

    else:
        if args.e:
            roots = [args.e]
            mode = "override"
        else:
            mode = "auto"

        root, input_dir, files = find_active_root(roots)

        if not root:
            print("❌ No valid directory found")
            sys.exit(1)

    # OUTPUT
    output_dir = Path(args.o) if args.o else Path(cfg["output"] or (root or input_dir) / "archives")

    print(f"\n🧠 Env: {env}")
    print(f"📂 Input: {input_dir}")
    print(f"📄 Files: {len(files)}")
    print(f"📁 Output: {output_dir}")
    print(f"⚙️ Mode: {mode}")

    process(files, output_dir, args.dry_run)
    log_run(env, mode, str(root), str(input_dir), str(output_dir))

    print("\n🎉 Done")

if __name__ == "__main__":
    main()
