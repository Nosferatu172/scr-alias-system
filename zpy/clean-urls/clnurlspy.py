#!/usr/bin/env python3
# Script Name: cleanurls.py
# ID: SCR-ID-20260329040937-2IUQCDDXHV
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cleanurls

import argparse
import csv
import os
import re
import shutil
import signal
import sys
from pathlib import Path

# --------------------------------------------------
# Ctrl+C handler
# --------------------------------------------------
def _sigint_handler(sig, frame):
    print("\n⛔ Cancelled. Exiting cleanly.")
    raise SystemExit(130)

signal.signal(signal.SIGINT, _sigint_handler)

# --------------------------------------------------
# Paths
# --------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
LOG_DIR = SCRIPT_DIR / "log"
DEFAULT_DIR_CSV = LOG_DIR / "default_directory.csv"

# --------------------------------------------------
# Regex (UPGRADED)
# --------------------------------------------------
YT_WATCH_PATTERN = re.compile(r"(https://www\.youtube\.com/watch\?v=[^&\s]+)")
YT_PLAYLIST_PATTERN = re.compile(r"[?&]list=([a-zA-Z0-9_-]+)")

# --------------------------------------------------
# Playlist normalization
# --------------------------------------------------
def normalize_playlist(list_id: str):
    """
    Converts playlist IDs into clean URLs.
    Filters out radio mixes (RD...).
    """
    if not list_id:
        return None

    if list_id.startswith("RD"):
        return None

    return f"https://www.youtube.com/playlist?list={list_id}"


# --------------------------------------------------
# Setup helpers
# --------------------------------------------------
def ensure_log_dir():
    LOG_DIR.mkdir(parents=True, exist_ok=True)


def save_default_directory(directory: Path):
    ensure_log_dir()
    with DEFAULT_DIR_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["default_directory"])
        writer.writerow([str(directory)])
    print(f"✅ Saved default directory: {directory}")


def load_default_directory():
    if not DEFAULT_DIR_CSV.exists():
        return None

    try:
        with DEFAULT_DIR_CSV.open("r", newline="", encoding="utf-8") as f:
            rows = list(csv.reader(f))
        if len(rows) >= 2 and rows[1]:
            value = rows[1][0].strip()
            if value:
                return Path(value).expanduser()
    except Exception as e:
        print(f"⚠️ Could not read default directory CSV: {e}")

    return None


def print_help(parser):
    parser.print_help()
    print(
        """
Examples:
  python ytclean.py -a
  python ytclean.py -l
  python ytclean.py -e
  python ytclean.py -a -bak
"""
    )


def prompt_for_directory(prompt_text="Enter the default directory path: "):
    while True:
        try:
            entered = input(prompt_text).strip().strip('"').strip("'")
        except KeyboardInterrupt:
            print("\n⛔ Cancelled.")
            raise SystemExit(130)

        if not entered:
            print("⚠️ Path cannot be empty.")
            continue

        path = Path(entered).expanduser()
        if path.is_dir():
            return path

        print(f"⚠️ Not a valid directory: {path}")


def build_brave_path_from_user(winuser: str) -> Path:
    return Path(f"/mnt/c/Users/{winuser}/Documents/mine/brave/")


def prompt_for_default_directory(parser, suggested_path=None):
    print()

    if suggested_path:
        print(f"Suggested path: {suggested_path}")
        try:
            use_suggested = input("Use suggested path? [Y/n]: ").strip().lower()
        except KeyboardInterrupt:
            print("\n⛔ Cancelled.")
            raise SystemExit(130)

        if use_suggested in ("", "y", "yes"):
            if suggested_path.is_dir():
                save_default_directory(suggested_path)
                return suggested_path
            print(f"⚠️ Suggested path does not exist: {suggested_path}")

    chosen = prompt_for_directory()
    save_default_directory(chosen)
    return chosen


def first_run_setup(parser, suggested_path=None):
    ensure_log_dir()
    saved = load_default_directory()
    if saved is None:
        print("=== First run setup ===")
        print_help(parser)
        print("No default directory has been saved yet.")
        return prompt_for_default_directory(parser, suggested_path=suggested_path)
    return saved


def list_default_directory():
    saved = load_default_directory()
    if saved is None:
        print("No default directory is saved yet.")
    else:
        print(saved)


def edit_default_directory(suggested_path=None):
    current = load_default_directory()
    if current is not None:
        print(f"Current default directory: {current}")
    else:
        print("No default directory is currently saved.")

    chosen = prompt_for_directory("Enter new default directory path: ")
    save_default_directory(chosen)


# --------------------------------------------------
# File handling
# --------------------------------------------------
def list_txt_files(base_dir: Path):
    return sorted(
        [p for p in base_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt"],
        key=lambda p: p.name.lower()
    )


def choose_file(txt_files):
    print("\n📄 Available TXT files:\n")
    print("  0. 🔥 RUN ALL FILES")

    for i, f in enumerate(txt_files, 1):
        print(f"  {i}. {f.name}")

    choice = input("\nSelect file (0=ALL, q=quit): ").strip()

    if choice.lower() == "q":
        raise SystemExit(0)

    try:
        index = int(choice)
    except ValueError:
        print("❌ Invalid selection.")
        raise SystemExit(1)

    if index < 0 or index > len(txt_files):
        print("❌ Invalid selection.")
        raise SystemExit(1)

    return index


# --------------------------------------------------
# CLEANING CORE (UPGRADED)
# --------------------------------------------------
def clean_file(file_path: Path, make_backup: bool = False) -> int:

    if make_backup:
        backup_path = file_path.with_name(file_path.name + ".bak")
        shutil.copy2(file_path, backup_path)

    cleaned = set()

    with file_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Watch URLs
            watch = YT_WATCH_PATTERN.search(line)
            if watch:
                cleaned.add(watch.group(1))

            # Playlist extraction
            playlist = YT_PLAYLIST_PATTERN.search(line)
            if playlist:
                list_id = playlist.group(1)
                normalized = normalize_playlist(list_id)
                if normalized:
                    cleaned.add(normalized)

            # fallback raw YouTube URL
            elif "youtube.com" in line:
                cleaned.add(line)

    with file_path.open("w", encoding="utf-8") as f:
        for url in sorted(cleaned):
            f.write(url + "\n")

    return len(cleaned)


# --------------------------------------------------
# RUNNER
# --------------------------------------------------
def run_cleaner(base_dir: Path, make_backup: bool):

    if not base_dir.is_dir():
        print(f"❌ Directory not found:\n{base_dir}")
        raise SystemExit(1)

    txt_files = list_txt_files(base_dir)

    if not txt_files:
        print("❌ No .txt files found.")
        raise SystemExit(0)

    index = choose_file(txt_files)

    total_files = 0
    total_lines = 0

    if index == 0:
        print("\n🔥 Running ALL files...\n")

        for file_path in txt_files:
            lines = clean_file(file_path, make_backup)
            total_files += 1
            total_lines += lines
            print(f"✅ {file_path.name} | {lines} URLs")

    else:
        file_path = txt_files[index - 1]
        lines = clean_file(file_path, make_backup)
        total_files = 1
        total_lines = lines
        print(f"\n✅ Cleaned: {file_path.name}")
        print(f"🔗 URLs: {lines}")

    print("\n----------------------")
    print("📌 Summary")
    print(f"📄 Files: {total_files}")
    print(f"🔗 URLs: {total_lines}")
    print(f"🛡️ Backup: {'YES' if make_backup else 'NO'}")
    print("----------------------\n")


# --------------------------------------------------
# MAIN
# --------------------------------------------------
def main():

    parser = argparse.ArgumentParser(description="Clean YouTube URLs in TXT files")

    parser.add_argument("-a", "--active", action="store_true")
    parser.add_argument("-e", "--edit-default", action="store_true")
    parser.add_argument("-l", "--list-default", action="store_true")
    parser.add_argument("-bak", action="store_true")

    args = parser.parse_args()

    first_run_setup(parser)

    if args.list_default:
        list_default_directory()
        return

    if args.edit_default:
        edit_default_directory()
        return

    if not args.active:
        print("⚠️ Use -a to run.")
        print_help(parser)
        raise SystemExit(1)

    base_dir = load_default_directory()
    if base_dir is None:
        base_dir = prompt_for_default_directory(parser)

    run_cleaner(base_dir, make_backup=args.bak)


if __name__ == "__main__":
    main()
