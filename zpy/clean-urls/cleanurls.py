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
# Cleaning regex
# --------------------------------------------------
YT_PATTERN = re.compile(r"(https://www\.youtube\.com/watch\?v=[^&\s]+)")

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
  First run / normal mode:
    python ytclean.py

  Use saved default directory:
    python ytclean.py -a

  Show saved default directory:
    python ytclean.py -l

  Edit saved default directory:
    python ytclean.py -e

  Use WINUSER environment variable to build the default path:
    python ytclean.py --use-winuser

  Use an explicit Windows username:
    python ytclean.py --use-winuser --winuser walker

  Use backup mode:
    python ytclean.py -a -bak

Behavior:
  - Lists all .txt files in the target directory
  - 0 runs all files
  - Numbered selection runs one file
  - Extracts clean YouTube watch URLs when present
  - Removes blank lines
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
                return
            print(f"⚠️ Suggested path does not exist: {suggested_path}")

    chosen = prompt_for_directory("Enter new default directory path: ")
    save_default_directory(chosen)


# --------------------------------------------------
# File selection
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

    try:
        choice = input("\nSelect a file number (0 for ALL, or 'q' to quit): ").strip()
    except KeyboardInterrupt:
        print("\n⛔ Cancelled.")
        raise SystemExit(130)

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
# Cleaning logic
# --------------------------------------------------
def clean_file(file_path: Path, make_backup: bool = False) -> int:
    """
    Cleans a single file.
    Returns number of lines written.
    """
    if make_backup:
        backup_path = file_path.with_name(file_path.name + ".bak")
        shutil.copy2(file_path, backup_path)

    cleaned_lines = []

    with file_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            match = YT_PATTERN.search(line)
            if match:
                cleaned_lines.append(match.group(1))
            else:
                cleaned_lines.append(line)

    with file_path.open("w", encoding="utf-8") as f:
        for line in cleaned_lines:
            f.write(line + "\n")

    return len(cleaned_lines)


# --------------------------------------------------
# Main run logic
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

    total_lines = 0
    files_processed = 0

    if index == 0:
        print("\n🔥 Running on ALL txt files...\n")
        for file_path in txt_files:
            lines = clean_file(file_path, make_backup=make_backup)
            files_processed += 1
            total_lines += lines
            print(f"✅ Cleaned: {file_path.name}  |  Lines: {lines}")
    else:
        file_path = txt_files[index - 1]
        lines = clean_file(file_path, make_backup=make_backup)
        files_processed = 1
        total_lines = lines
        print(f"\n✅ Cleaned YouTube URLs in: {file_path.name}")
        print(f"🔗 Lines processed: {lines}")

    print("\n------------------------------")
    print("📌 Summary")
    print(f"📄 Files processed: {files_processed}")
    print(f"🔗 Total lines processed: {total_lines}")
    print(f"🛡️ Backup: {'ENABLED' if make_backup else 'DISABLED'}")
    print("------------------------------\n")


def resolve_suggested_path(use_winuser: bool, explicit_winuser: str | None):
    if not use_winuser and not explicit_winuser:
        return None

    winuser = explicit_winuser or os.environ.get("WINUSER")
    if not winuser:
        print("⚠️ WINUSER environment variable not set, and --winuser was not provided.")
        return None

    return build_brave_path_from_user(winuser)


# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Clean YouTube URLs in TXT files using a saved default directory next to the script."
    )

    parser.add_argument(
        "-a", "--active",
        action="store_true",
        help="Use the saved default directory as the active directory"
    )
    parser.add_argument(
        "-e", "--edit-default",
        action="store_true",
        help="Edit the saved default directory"
    )
    parser.add_argument(
        "-l", "--list-default",
        action="store_true",
        help="Show the saved default directory"
    )
    parser.add_argument(
        "-bak",
        action="store_true",
        help="Create .bak backup files before cleaning"
    )
    parser.add_argument(
        "--use-winuser",
        action="store_true",
        help="Suggest /mnt/c/Users/<WINUSER>/Documents/mine/brave/ using WINUSER or --winuser"
    )
    parser.add_argument(
        "--winuser",
        help="Windows username to build /mnt/c/Users/<WINUSER>/Documents/mine/brave/"
    )

    suggested_path = resolve_suggested_path(
        use_winuser=("--use-winuser" in sys.argv),
        explicit_winuser=None
    )

    # first pass parse so flags exist cleanly
    args = parser.parse_args()

    if args.winuser:
        suggested_path = build_brave_path_from_user(args.winuser)
    elif args.use_winuser:
        env_user = os.environ.get("WINUSER")
        if env_user:
            suggested_path = build_brave_path_from_user(env_user)
        else:
            print("⚠️ WINUSER environment variable not set.")
            suggested_path = None

    # first-run setup
    first_run_setup(parser, suggested_path=suggested_path)

    if args.list_default:
        list_default_directory()
        return

    if args.edit_default:
        edit_default_directory(suggested_path=suggested_path)
        return

    if not args.active:
        print("⚠️ Use -a to run against the saved default directory.")
        print()
        print_help(parser)
        raise SystemExit(1)

    base_dir = load_default_directory()
    if base_dir is None:
        print("⚠️ No default directory saved.")
        base_dir = prompt_for_default_directory(parser, suggested_path=suggested_path)

    run_cleaner(base_dir=base_dir, make_backup=args.__dict__["-bak"] if "-bak" in args.__dict__ else args.bak)


if __name__ == "__main__":
    main()
