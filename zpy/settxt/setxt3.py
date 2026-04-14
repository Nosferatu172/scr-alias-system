#!/usr/bin/env python3
# Script Name: setxt3.py
# ID: SCR-ID-20260329031432-ICGZQ99RZ9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: setxt3

"""
setxt.py

Simple timestamped copier/mover for .txt/.csv.

Behavior:
  - No flags: copy ONE newest file from source_dir -> destination_dir
  - -f      : copy ALL files from source_dir -> destination_dir
  - -a      : use active (current) directory as the source instead of saved source_dir
  - -r      : remove originals after copy (move)
  - -es     : edit source_dir interactively
  - -ed     : edit destination_dir interactively
  - -l      : list current saved directories
  - -h/--help : help

Naming:
  YYYYMMDD_HHMMSS_<original_basename>.<ext>

Config:
  Stored at ./logs/config.json next to this script.
"""

import argparse
import json
import os
import re
import shutil
import signal
import sys
from datetime import datetime
from pathlib import Path

ALLOWED_EXTS = {".txt", ".csv"}


# -----------------------
# Ctrl+C handler
# -----------------------
def handle_sigint(sig, frame):
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    sys.exit(130)

signal.signal(signal.SIGINT, handle_sigint)


# -----------------------
# Config paths
# -----------------------
def script_paths():
    script_path = Path(__file__).resolve()
    script_dir = script_path.parent
    logs_dir = script_dir / "logs"
    cfg_path = logs_dir / "config.json"
    return logs_dir, cfg_path


def load_config() -> dict:
    logs_dir, cfg_path = script_paths()
    logs_dir.mkdir(parents=True, exist_ok=True)

    if cfg_path.exists():
        try:
            data = json.loads(cfg_path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                # ensure keys exist
                data.setdefault("source_dir", str(Path.cwd()))
                data.setdefault("dest_dir", "/mnt/f/Wyvern/mnt/c/scr/tabs")
                return data
        except Exception:
            pass

    data = {
        "source_dir": str(Path.cwd()),
        "dest_dir": "/mnt/f/Wyvern/mnt/c/scr/tabs",
    }
    cfg_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


def save_config(cfg: dict):
    logs_dir, cfg_path = script_paths()
    logs_dir.mkdir(parents=True, exist_ok=True)
    cfg_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")


def norm_dir(p: str) -> str:
    return (p or "").strip().strip('"').strip("'")


# -----------------------
# Helpers
# -----------------------
def safe_filename(name: str) -> str:
    name = name.strip()
    name = re.sub(r"\s+", " ", name)
    # replace Windows/NTFS-hostile chars + control chars
    name = re.sub(r'[<>:"/\\|?*\x00-\x1F]', "_", name)
    return name or "file"


def unique_dest_path(dest: Path) -> Path:
    if not dest.exists():
        return dest
    stem, suffix = dest.stem, dest.suffix
    i = 1
    while True:
        cand = dest.with_name(f"{stem}_{i}{suffix}")
        if not cand.exists():
            return cand
        i += 1


def list_candidates(src: Path) -> list[Path]:
    if not src.is_dir():
        return []
    files = [p for p in src.iterdir() if p.is_file() and p.suffix.lower() in ALLOWED_EXTS]
    # newest first
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return files


def edit_dir_interactive(label: str, current: str) -> str:
    print(f"{label} (current): {current}")
    val = input(f"Enter new {label} (blank = keep): ").strip()
    if not val:
        print("ℹ️ Keeping current.")
        return current
    val = norm_dir(val)
    print(f"✅ Set {label} -> {val}")
    return val


def copy_or_move_file(src_file: Path, dest_dir: Path, ts: str, remove_after: bool) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)

    base = safe_filename(src_file.stem)
    ext = src_file.suffix.lower()
    dest_name = f"{ts}_{base}{ext}"
    dest_path = unique_dest_path(dest_dir / dest_name)

    # copy2 preserves mtime
    shutil.copy2(src_file, dest_path)

    if remove_after:
        try:
            src_file.unlink()
        except Exception as e:
            print(f"⚠️ Copied but failed to remove source: {src_file} ({e})")

    return dest_path


def run_job(source_dir: Path, dest_dir: Path, all_files: bool, remove_after: bool) -> int:
    candidates = list_candidates(source_dir)
    if not candidates:
        print(f"❌ No {', '.join(sorted(ALLOWED_EXTS))} files found in: {source_dir}")
        return 0

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")

    if all_files:
        chosen = candidates[:]  # all
        print(f"📦 Mode: ALL files (-f)")
    else:
        chosen = [candidates[0]]  # newest one
        print(f"📦 Mode: ONE file (default)")

    print(f"➡️  From: {source_dir}")
    print(f"📁 To:   {dest_dir}")
    print(f"⏱️  Timestamp: {ts}")
    print(f"{'🚚 Moving' if remove_after else '📄 Copying'} {len(chosen)} file(s)\n")

    ok = 0
    for f in chosen:
        out = copy_or_move_file(f, dest_dir, ts, remove_after=remove_after)
        print(f"✅ {f.name}  →  {out.name}")
        ok += 1

    print(f"\n🎉 Done. {('Moved' if remove_after else 'Copied')} {ok} file(s) into: {dest_dir}")
    return ok


# -----------------------
# Main
# -----------------------
def main():
    parser = argparse.ArgumentParser(
        prog="setxt",
        description="Copy/move newest or all .txt/.csv files with a timestamp into a destination directory.",
        add_help=True,
    )

    parser.add_argument("-es", action="store_true", help="Edit source directory (interactive)")
    parser.add_argument("-ed", action="store_true", help="Edit destination directory (interactive)")
    parser.add_argument("-l", action="store_true", help="List current saved directories and exit")
    parser.add_argument("-a", action="store_true", help="Use active/current directory as source (override saved source_dir)")
    parser.add_argument("-f", action="store_true", help="Process ALL files in the source directory (no prompts)")
    parser.add_argument("-r", action="store_true", help="Remove originals after copy (move)")

    args = parser.parse_args()

    cfg = load_config()

    # Edit flags
    changed = False
    if args.es:
        cfg["source_dir"] = edit_dir_interactive("source_dir", cfg.get("source_dir", ""))
        changed = True
    if args.ed:
        cfg["dest_dir"] = edit_dir_interactive("dest_dir", cfg.get("dest_dir", ""))
        changed = True
    if changed:
        save_config(cfg)

    # List config
    if args.l:
        print(json.dumps(cfg, indent=2))
        return

    # Determine source/dest for the run
    source_dir = Path(Path.cwd() if args.a else cfg.get("source_dir", "")).expanduser()
    dest_dir = Path(cfg.get("dest_dir", "")).expanduser()

    # Run
    n = run_job(source_dir=source_dir, dest_dir=dest_dir, all_files=args.f, remove_after=args.r)
    if n == 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
