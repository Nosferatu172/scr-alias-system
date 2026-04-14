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
# INTERACTIVE MENU
# -----------------------
def interactive_menu(cfg):
    while True:
        print("\n=== setxt4 Config ===")
        print("[1] View config")
        print("[2] Edit roots")
        print("[3] Add root")
        print("[4] Remove root")
        print("[5] Set output dir")
        print("[6] Reset defaults")
        print("[0] Exit")

        c = input("Choice: ").strip()

        if c == "1":
            print(json.dumps(cfg, indent=2))

        elif c == "2":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = input("Index: ")
            if idx.isdigit():
                new = input("New path: ")
                cfg["roots"][int(idx)-1] = new

        elif c == "3":
            new = input("Add path: ")
            if new:
                cfg["roots"].append(new)

        elif c == "4":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = input("Remove index: ")
            if idx.isdigit():
                cfg["roots"].pop(int(idx)-1)

        elif c == "5":
            cfg["output"] = input("Output dir: ")

        elif c == "6":
            cfg = default_config()
            print("🔄 Reset")

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
        suffix = f"_{ts}" if i == 0 else f"_{ts}_{i}"
        cand = path.with_name(f"{base}{suffix}{ext}")
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


def process(files, out_dir, dry_run=False):
    urls = set()

    for f in files:
        urls.update(URL_RE.findall(f.read_text(errors="ignore")))

    if not urls:
        print("❌ No URLs found")
        return

    print(f"🔎 Found {len(urls)} unique URLs")

    if dry_run:
        print("🧪 Dry-run mode (no file written)")
        return

    out_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = unique_file(out_dir / f"exported-tabs_{ts}.txt")

    out_file.write_text("\n".join(sorted(urls)))

    print(f"✅ Saved → {out_file}")


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
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", action="store_true")
    parser.add_argument("-e")
    parser.add_argument("-d")
    parser.add_argument("-a", action="store_true")
    parser.add_argument("-o")
    parser.add_argument("-l", action="store_true")
    parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    cfg = load_config()

    if args.i:
        interactive_menu(cfg)
        return

    if args.l:
        print(json.dumps(cfg, indent=2))
        return

    env = detect_env()
    roots = cfg["roots"]

    # -----------------------
    # INPUT LOGIC (priority)
    # -----------------------
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

    # -----------------------
    # OUTPUT
    # -----------------------
    output_dir = Path(args.o) if args.o else Path(cfg["output"] or (root or input_dir) / "archives")

    print(f"\n🧠 Env: {env}")
    print(f"📂 Input: {input_dir}")
    print(f"📄 Files: {len(files)}")
    print(f"📁 Output: {output_dir}")
    print(f"⚙️ Mode: {mode}")

    process(files, output_dir, dry_run=args.dry_run)

    log_run(env, mode, str(root), str(input_dir), str(output_dir))

    print("\n🎉 Done")


if __name__ == "__main__":
    main()
