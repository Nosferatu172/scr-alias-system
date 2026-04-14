#!/usr/bin/env python3
# Script Name: scriptgrab.py
# ID: SCR-ID-20260317130903-R9GBUXEEO7
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scriptgrab

import argparse
import os
import re
import shutil
import signal
from pathlib import Path


# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# -----------------------
# Input helpers
# -----------------------
def input_below(prompt: str) -> str:
    try:
        print(prompt)
        return input("> ").strip()
    except KeyboardInterrupt:
        print("\n⛔ Cancelled.")
        raise SystemExit(130)


def prompt_nonempty(prompt: str) -> str:
    while True:
        value = input_below(prompt)
        if value:
            return value
        print("⚠️ Please enter a valid path.")


# -----------------------
# Path helpers
# -----------------------
def normalize_path(raw: str) -> Path:
    """
    Normalize a user path for WSL/Linux usage.

    Accepts:
    - /mnt/c/...
    - /home/...
    - ~/...
    - ./...
    - ../...
    - C:/...
    - C:\\...
    """
    s = raw.strip().strip('"').strip("'")
    s = os.path.expandvars(s)
    s = os.path.expanduser(s)

    # Windows drive path -> WSL path
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", s)
    if m:
        drive = m.group(1).lower()
        rest = m.group(2).replace("\\", "/")
        s = f"/mnt/{drive}/{rest}"

    p = Path(s)
    if not p.is_absolute():
        p = Path.cwd() / p

    try:
        return p.resolve(strict=False)
    except Exception:
        return p


# -----------------------
# File helpers
# -----------------------
def unique_dest_path(dest_dir: Path, original_name: str) -> Path:
    """
    Prevent overwrite:
      test.rb
      test_001.rb
      test_002.rb
    """
    candidate = dest_dir / original_name
    if not candidate.exists():
        return candidate

    stem = Path(original_name).stem
    suffix = Path(original_name).suffix
    counter = 1

    while True:
        new_name = f"{stem}_{counter:03d}{suffix}"
        candidate = dest_dir / new_name
        if not candidate.exists():
            return candidate
        counter += 1


def is_inside(child: Path, parent: Path) -> bool:
    try:
        child.resolve(strict=False).relative_to(parent.resolve(strict=False))
        return True
    except Exception:
        return False


def find_matching_files(source_dir: Path, extension: str, dest_dir: Path | None = None) -> list[Path]:
    matches = []

    for path in source_dir.rglob("*"):
        if not path.is_file():
            continue

        if path.suffix.lower() != extension.lower():
            continue

        if dest_dir and is_inside(path, dest_dir):
            continue

        matches.append(path)

    return matches


def move_files(files: list[Path], dest_dir: Path, dry_run: bool = False, quiet: bool = False) -> tuple[int, int]:
    moved = 0
    failed = 0

    for src in files:
        dst = unique_dest_path(dest_dir, src.name)

        if not quiet or dry_run:
            print(f"{src}  ->  {dst}")

        if dry_run:
            continue

        try:
            shutil.move(str(src), str(dst))
            moved += 1
        except Exception as e:
            failed += 1
            print(f"⚠️ Failed to move: {src}")
            print(f"   Reason: {e}")

    return moved, failed


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="grab",
        description="Recursively find files by extension and move them into one folder.",
        epilog="""
Examples:
  grab
      Prompt for source and destination, default extension .rb

  grab -a
      Use current directory as source, then prompt for destination

  grab -a -d /mnt/c/scr/rb_store
      Use current directory and move all .rb files to that folder

  grab /mnt/c/scr/zru -d /mnt/c/scr/rb_store -x .rb
      Scan a specific source for .rb files

  grab -a -d ./collected_rb -n
      Dry run only
""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "source",
        nargs="?",
        help="Source directory to scan recursively."
    )
    parser.add_argument(
        "-a", "--active",
        action="store_true",
        help="Use current working directory as the source directory."
    )
    parser.add_argument(
        "-d", "--dest",
        help="Destination folder to move matching files into."
    )
    parser.add_argument(
        "-x", "--ext",
        default=".rb",
        help="File extension to gather. Default: .rb"
    )
    parser.add_argument(
        "-n", "--dry-run",
        action="store_true",
        help="Preview moves without actually moving files."
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Reduce output."
    )

    args = parser.parse_args()

    # Normalize extension
    ext = args.ext.strip()
    if not ext.startswith("."):
        ext = "." + ext
    ext = ext.lower()

    # Source
    if args.active:
        source_dir = Path.cwd()
    elif args.source:
        source_dir = normalize_path(args.source)
    else:
        source_dir = normalize_path(prompt_nonempty(f"Enter source directory to scan for {ext} files:"))

    if not source_dir.exists():
        print(f"❌ Source does not exist:\n   {source_dir}")
        return 2

    if not source_dir.is_dir():
        print(f"❌ Source is not a directory:\n   {source_dir}")
        return 2

    # Destination
    if args.dest:
        dest_dir = normalize_path(args.dest)
    else:
        dest_dir = normalize_path(prompt_nonempty(f"Enter destination directory to move all {ext} files into:"))

    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"❌ Could not create/access destination directory:\n   {dest_dir}")
        print(f"   {e}")
        return 2

    print("\n--- Grab Summary ---")
    print(f"Source:      {source_dir}")
    print(f"Destination: {dest_dir}")
    print(f"Extension:   {ext}")
    print(f"Dry run:     {'yes' if args.dry_run else 'no'}")

    if is_inside(dest_dir, source_dir):
        print("ℹ️ Destination is inside the source tree.")
        print("   Files already in the destination folder will be skipped.")

    files = find_matching_files(source_dir, ext, dest_dir=dest_dir)

    if not files:
        print(f"\nℹ️ No {ext} files found.")
        return 0

    print(f"\nFound {len(files)} matching file(s).\n")

    moved, failed = move_files(files, dest_dir, dry_run=args.dry_run, quiet=args.quiet)

    print("\n--- Done ---")
    if args.dry_run:
        print("No files were moved because dry-run mode was used.")
    else:
        print(f"Moved:  {moved}")
        print(f"Failed: {failed}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
