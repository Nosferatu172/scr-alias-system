#!/usr/bin/env python3
# Script Name: seplinestxt.py
# ID: SCR-ID-20260317130713-HZRTK0U65G
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: seplinestxty

import argparse
import csv
import signal
from pathlib import Path
import sys

# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    print("\n⛔ Cancelled. Exiting cleanly.")
    raise SystemExit(130)

signal.signal(signal.SIGINT, _sigint_handler)

# -----------------------
# Paths
# -----------------------
SCRIPT_DIR = Path(__file__).resolve().parent
LOG_DIR = SCRIPT_DIR / "log"
DEFAULT_DIR_FILE = LOG_DIR / "default_directory.csv"


# -----------------------
# Setup helpers
# -----------------------
def ensure_log():
    LOG_DIR.mkdir(exist_ok=True)


def save_default_directory(directory: Path):
    ensure_log()
    with open(DEFAULT_DIR_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["default_directory"])
        writer.writerow([str(directory)])


def load_default_directory():
    if not DEFAULT_DIR_FILE.exists():
        return None

    try:
        with open(DEFAULT_DIR_FILE) as f:
            rows = list(csv.reader(f))
        if len(rows) >= 2:
            return Path(rows[1][0])
    except:
        pass

    return None


def ask_default_directory():
    while True:
        p = input("Enter default directory: ").strip().strip('"')
        path = Path(p).expanduser()

        if path.is_dir():
            save_default_directory(path)
            print(f"Saved: {path}")
            return path

        print("⚠ Directory does not exist.")


def first_run(parser):
    ensure_log()

    if not DEFAULT_DIR_FILE.exists():
        print("=== First run setup ===")
        parser.print_help()
        print()
        print("No default directory set.")
        ask_default_directory()


# -----------------------
# Directory tools
# -----------------------
def list_default():
    d = load_default_directory()
    if d:
        print(d)
    else:
        print("No default directory saved.")


def edit_default():
    current = load_default_directory()
    if current:
        print(f"Current default directory: {current}")
    ask_default_directory()


# -----------------------
# File chooser
# -----------------------
def choose_file(directory: Path):
    files = sorted([f for f in directory.iterdir() if f.is_file()])

    if not files:
        print("No files found.")
        sys.exit(1)

    print(f"\nFiles in {directory}:\n")

    for i, f in enumerate(files, 1):
        print(f"{i}. {f.name}")

    while True:
        choice = input("\nSelect number or filename (E to exit): ").strip()

        if choice.lower() == "e":
            sys.exit()

        if choice.isdigit():
            idx = int(choice)
            if 1 <= idx <= len(files):
                return files[idx - 1]

        f = directory / choice
        if f.exists():
            return f

        print("Invalid selection.")


# -----------------------
# Split logic
# -----------------------
def split_file(input_file: Path, lines_per_file: int, output_dir: Path):

    with open(input_file, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    if not lines:
        print("File empty.")
        return

    base_name = input("\nEnter output base filename: ").strip()

    if not base_name:
        base_name = input_file.stem

    ext = input_file.suffix if input_file.suffix else ".txt"

    output_dir.mkdir(exist_ok=True)

    count = 0
    for i in range(0, len(lines), lines_per_file):
        count += 1

        chunk = lines[i:i + lines_per_file]

        new_file = output_dir / f"{base_name}_{count}{ext}"

        with open(new_file, "w", encoding="utf-8") as f:
            f.writelines(chunk)

        print(f"Created: {new_file}")

    print(f"\nDone. {count} files created.")


# -----------------------
# Main
# -----------------------
def main():

    parser = argparse.ArgumentParser(
        description="Split a file into numbered files with custom base name."
    )

    parser.add_argument(
        "file",
        nargs="?",
        help="Input file"
    )

    parser.add_argument(
        "-n",
        "--lines",
        default=1,
        type=int,
        help="Lines per file"
    )

    parser.add_argument(
        "-a",
        "--active",
        action="store_true",
        help="Use saved default directory"
    )

    parser.add_argument(
        "-l",
        "--list-default",
        action="store_true"
    )

    parser.add_argument(
        "-e",
        "--edit-default",
        action="store_true"
    )

    parser.add_argument(
        "-o",
        "--output",
        help="Output directory"
    )

    first_run(parser)

    args = parser.parse_args()

    if args.list_default:
        list_default()
        return

    if args.edit_default:
        edit_default()
        return

    default_dir = load_default_directory()

    output_dir = Path(args.output).expanduser() if args.output else None

    # Active mode
    if args.active:

        if args.file:
            input_file = default_dir / args.file
        else:
            input_file = choose_file(default_dir)

        if not input_file.exists():
            print("File not found.")
            return

        split_file(
            input_file,
            args.lines,
            output_dir or input_file.parent
        )

        return

    # Normal mode
    if not args.file:
        parser.print_help()
        return

    input_file = Path(args.file).expanduser()

    if not input_file.exists():
        print("File not found.")
        return

    split_file(
        input_file,
        args.lines,
        output_dir or input_file.parent
    )


if __name__ == "__main__":
    main()
