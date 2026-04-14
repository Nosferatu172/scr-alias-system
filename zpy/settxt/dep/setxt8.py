#!/usr/bin/env python3
# Script Name: setxt4_auto.py
# URL Extractor (CLI + Interactive Config + Logging)

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
# CTRL+C HANDLER
# -----------------------
def handle_sigint(sig, frame):
    print("\n⛔ Interrupted. Exiting cleanly.")
    sys.exit(130)

signal.signal(signal.SIGINT, handle_sigint)

# -----------------------
# PATHS / CONFIG
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
# ENV DETECT
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
        print("\n=== setxt4 Interactive Config ===")
        print("[1] View config")
        print("[2] Edit root directories")
        print("[3] Add root directory")
        print("[4] Remove root directory")
        print("[5] Set default output directory")
        print("[6] Reset to defaults")
        print("[0] Exit")

        choice = input("Select option: ").strip()

        if choice == "1":
            print(json.dumps(cfg, indent=2))

        elif choice == "2":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = input("Select index to edit: ").strip()
            if idx.isdigit() and 1 <= int(idx) <= len(cfg["roots"]):
                new_val = input("New path: ").strip()
                cfg["roots"][int(idx)-1] = new_val

        elif choice == "3":
            new = input("Enter new root path: ").strip()
            if new:
                cfg["roots"].append(new)

        elif choice == "4":
            for i, r in enumerate(cfg["roots"], 1):
                print(f"{i}. {r}")
            idx = input("Remove which index: ").strip()
            if idx.isdigit() and 1 <= int(idx) <= len(cfg["roots"]):
                cfg["roots"].pop(int(idx)-1)

        elif choice == "5":
            new = input("Set default output dir (blank to clear): ").strip()
            cfg["output"] = new

        elif choice == "6":
            cfg = default_config()
            print("🔄 Reset to defaults")

        elif choice == "0":
            save_config(cfg)
            print("💾 Saved.")
            return

        else:
            print("❌ Invalid option")


# -----------------------
# HELPERS
# -----------------------
def contains_url(file: Path):
    try:
        return bool(URL_RE.search(file.read_text(errors="ignore")))
    except:
        return False


def unique_file(path: Path):
    if not path.exists():
        return path

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    base, ext = path.stem, path.suffix

    i = 0
    while True:
        suffix = f"_{ts}" if i == 0 else f"_{ts}_{i}"
        candidate = path.with_name(f"{base}{suffix}{ext}")
        if not candidate.exists():
            return candidate
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


def process(files, out_dir):
    urls = set()

    for f in files:
        urls.update(URL_RE.findall(f.read_text(errors="ignore")))

    if not urls:
        print("❌ No URLs found")
        return

    out_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = unique_file(out_dir / f"exported-tabs_{ts}.txt")

    out_file.write_text("\n".join(sorted(urls)))

    print(f"✅ {len(urls)} URLs → {out_file}")


def log_run(env, mode, root, input_dir, output_dir):
    logs, _ = script_paths()
    csv_path = logs / "setxt4_dirs.csv"

    new = not csv_path.exists()

    with open(csv_path, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["timestamp", "env", "mode", "root", "input", "output"])

        w.writerow([
            datetime.now().strftime("%Y-%m-%d_%H-%M-%S"),
            env,
            mode,
            root or "",
            input_dir,
            output_dir
        ])


# -----------------------
# MAIN
# -----------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", action="store_true", help="Interactive config menu")
    parser.add_argument("-e", help="Override root")
    parser.add_argument("-d", help="Direct input dir")
    parser.add_argument("-o", help="Output dir override")
    parser.add_argument("-l", action="store_true", help="List config")

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

    if args.d:
        input_dir = Path(args.d)
        files = [f for f in input_dir.glob("*.txt") if contains_url(f)]
        root = None
        mode = "direct"
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

    output_dir = Path(args.o) if args.o else Path(cfg["output"] or root / "archives")

    print(f"\n🧠 {env}")
    print(f"📂 {input_dir}")
    print(f"📁 {output_dir}")

    process(files, output_dir)
    log_run(env, mode, str(root), str(input_dir), str(output_dir))

    print("🎉 Done")


if __name__ == "__main__":
    main()
