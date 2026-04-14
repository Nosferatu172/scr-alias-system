#!/usr/bin/env python3
# Script Name: duprelinestxt.py
# ID: SCR-ID-20260317130659-XHBHQALU1S
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: duprelinestxt

import argparse
import csv
import shutil
import signal
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
  First run / normal:
    python dedupe_lines.py

  Use saved default directory:
    python dedupe_lines.py -a

  Use saved default directory with backup:
    python dedupe_lines.py -a -bak

  Show saved default directory:
    python dedupe_lines.py -l

  Edit saved default directory:
    python dedupe_lines.py -e

Behavior:
  - Lists files in the target directory
  - 0 runs all files
  - Numbered selection runs one file
  - Removes duplicate lines
  - Preserves original line order
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


def prompt_for_default_directory(parser):
    chosen = prompt_for_directory()
    save_default_directory(chosen)
    return chosen


def first_run_setup(parser):
    ensure_log_dir()
    saved = load_default_directory()
    if saved is None:
        print("=== First run setup ===")
        print_help(parser)
        print("No default directory has been saved yet.")
        return prompt_for_default_directory(parser)
    return saved


def list_default_directory():
    saved = load_default_directory()
    if saved is None:
        print("No default directory is saved yet.")
    else:
        print(saved)


def edit_default_directory():
    current = load_default_directory()
    if current is not None:
        print(f"Current default directory: {current}")
    else:
        print("No default directory is currently saved.")

    chosen = prompt_for_directory("Enter new default directory path: ")
    save_default_directory(chosen)

# --------------------------------------------------
# File listing / selection
# --------------------------------------------------
def list_files(base_dir: Path, extension: str | None = None):
    files = [p for p in base_dir.iterdir() if p.is_file()]
    if extension:
        ext = extension.lower()
        files = [p for p in files if p.suffix.lower() == ext]
    return sorted(files, key=lambda p: p.name.lower())


def choose_file(files):
    print("\n📄 Available files:\n")
    print("  0. 🔥 RUN ALL FILES")
    for i, f in enumerate(files, 1):
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

    if index < 0 or index > len(files):
        print("❌ Invalid selection.")
        raise SystemExit(1)

    return index

# --------------------------------------------------
# Duplicate removal logic
# --------------------------------------------------
def remove_duplicate_lines(
    file_path: Path,
    make_backup: bool = False,
    ignore_case: bool = False,
    strip_compare: bool = False,
) -> tuple[int, int]:
    """
    Removes duplicate lines while preserving original order.

    Returns:
        (original_line_count, written_line_count)
    """
    if make_backup:
        backup_path = file_path.with_name(file_path.name + ".bak")
        shutil.copy2(file_path, backup_path)

    with file_path.open("r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    seen = set()
    unique_lines = []

    for line in lines:
        compare_value = line.rstrip("\n\r")

        if strip_compare:
            compare_value = compare_value.strip()

        if ignore_case:
            compare_value = compare_value.lower()

        if compare_value not in seen:
            seen.add(compare_value)
            unique_lines.append(line)

    with file_path.open("w", encoding="utf-8") as f:
        f.writelines(unique_lines)

    return len(lines), len(unique_lines)

# --------------------------------------------------
# Main run logic
# --------------------------------------------------
def run_dedupe(base_dir: Path, make_backup: bool, extension: str | None, ignore_case: bool, strip_compare: bool):
    if not base_dir.is_dir():
        print(f"❌ Directory not found:\n{base_dir}")
        raise SystemExit(1)

    files = list_files(base_dir, extension=extension)

    if not files:
        if extension:
            print(f"❌ No {extension} files found.")
        else:
            print("❌ No files found.")
        raise SystemExit(0)

    index = choose_file(files)

    files_processed = 0
    total_original = 0
    total_written = 0
    total_removed = 0

    if index == 0:
        print("\n🔥 Running on ALL files...\n")
        for file_path in files:
            original_count, written_count = remove_duplicate_lines(
                file_path=file_path,
                make_backup=make_backup,
                ignore_case=ignore_case,
                strip_compare=strip_compare,
            )
            removed_count = original_count - written_count

            files_processed += 1
            total_original += original_count
            total_written += written_count
            total_removed += removed_count

            print(
                f"✅ Cleaned: {file_path.name}  |  "
                f"Original: {original_count}  |  "
                f"Kept: {written_count}  |  "
                f"Removed: {removed_count}"
            )
    else:
        file_path = files[index - 1]
        original_count, written_count = remove_duplicate_lines(
            file_path=file_path,
            make_backup=make_backup,
            ignore_case=ignore_case,
            strip_compare=strip_compare,
        )
        removed_count = original_count - written_count

        files_processed = 1
        total_original = original_count
        total_written = written_count
        total_removed = removed_count

        print(f"\n✅ Removed duplicate lines in: {file_path.name}")
        print(f"📄 Original lines: {original_count}")
        print(f"📌 Unique lines kept: {written_count}")
        print(f"🗑️ Duplicate lines removed: {removed_count}")

    print("\n------------------------------")
    print("📌 Summary")
    print(f"📄 Files processed: {files_processed}")
    print(f"📥 Total original lines: {total_original}")
    print(f"📤 Total unique lines kept: {total_written}")
    print(f"🗑️ Total duplicate lines removed: {total_removed}")
    print(f"🛡️ Backup: {'ENABLED' if make_backup else 'DISABLED'}")
    print(f"🔠 Ignore case: {'ENABLED' if ignore_case else 'DISABLED'}")
    print(f"✂️ Strip compare: {'ENABLED' if strip_compare else 'DISABLED'}")
    print("------------------------------\n")

# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Remove duplicate lines from files using a saved default directory next to the script."
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
        dest="make_backup",
        action="store_true",
        help="Create .bak backup files before processing"
    )
    parser.add_argument(
        "-x", "--ext",
        help="Only process files with this extension, example: .txt"
    )
    parser.add_argument(
        "-i", "--ignore-case",
        action="store_true",
        help="Treat uppercase/lowercase lines as duplicates"
    )
    parser.add_argument(
        "-s", "--strip",
        dest="strip_compare",
        action="store_true",
        help="Strip leading/trailing whitespace before comparing lines"
    )

    first_run_setup(parser)
    args = parser.parse_args()

    if args.list_default:
        list_default_directory()
        return

    if args.edit_default:
        edit_default_directory()
        return

    if not args.active:
        print("⚠️ Use -a to run against the saved default directory.")
        print()
        print_help(parser)
        raise SystemExit(1)

    base_dir = load_default_directory()
    if base_dir is None:
        print("⚠️ No default directory saved.")
        base_dir = prompt_for_default_directory(parser)

    extension = args.ext
    if extension and not extension.startswith("."):
        extension = "." + extension

    run_dedupe(
        base_dir=base_dir,
        make_backup=args.make_backup,
        extension=extension,
        ignore_case=args.ignore_case,
        strip_compare=args.strip_compare,
    )


if __name__ == "__main__":
    main()
