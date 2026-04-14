#!/usr/bin/env python3
# Script Name: kzip.py
# ID: SCR-ID-20260404035118-YI6FETLHUI
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: kzip
# Description: Archive utility with safe unzip, progress, and verbose modes

import argparse
import os
import signal
import zipfile
from pathlib import Path

# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# -----------------------
# Path helper
# -----------------------
def normalize_posix_path(p: str) -> str:
    p = p.strip().strip('"').strip("'")
    p = os.path.expandvars(p)
    p = os.path.expanduser(p)

    pp = Path(p)
    if not pp.is_absolute():
        pp = Path.cwd() / pp

    return str(pp.resolve(strict=False))


# -----------------------
# Archive helpers
# -----------------------
SUPPORTED_ARCHIVES = (".zip")


def is_archive(filename: str) -> bool:
    return filename.lower().endswith(SUPPORTED_ARCHIVES)


def get_unique_folder(base_path: str) -> str:
    if not os.path.exists(base_path):
        return base_path

    counter = 1
    while True:
        new_path = f"{base_path}_{counter}"
        if not os.path.exists(new_path):
            return new_path
        counter += 1


# -----------------------
# UNZIP
# -----------------------
def unzip_file(filepath: str, extract_here=False, safe=False, verbose=False):
    filepath = normalize_posix_path(filepath)

    if not zipfile.is_zipfile(filepath):
        print(f"⚠️ Not a valid zip: {filepath}")
        return 1

    base_dir = os.path.dirname(filepath)
    name = os.path.splitext(os.path.basename(filepath))[0]

    if safe:
        target_dir = get_unique_folder(os.path.join(base_dir, name))
    else:
        if extract_here:
            target_dir = base_dir
        else:
            target_dir = get_unique_folder(os.path.join(base_dir, name))

    os.makedirs(target_dir, exist_ok=True)

    try:
        with zipfile.ZipFile(filepath, 'r') as z:
            members = z.namelist()

            for i, member in enumerate(members, 1):
                z.extract(member, target_dir)

                if verbose:
                    print(f"   [{i}/{len(members)}] {member}")

        print(f"📦 Extracted: {filepath} -> {target_dir}")
        return 0

    except Exception as e:
        print(f"❌ Failed to unzip {filepath}: {e}")
        return 1


def unzip_in_directory(directory: str, extract_here=False, all_files=False,
                        safe=False, verbose=False, progress=False):

    directory = normalize_posix_path(directory)

    # Single file case
    if os.path.isfile(directory):
        return unzip_file(directory, extract_here, safe, verbose)

    if not os.path.isdir(directory):
        print(f"❌ Not a valid directory: {directory}")
        return 2

    archives = [f for f in os.listdir(directory) if is_archive(f)]

    if not archives:
        print("⚠️ No zip files found.")
        return 0

    total = len(archives)
    processed = 0

    for i, filename in enumerate(archives, 1):
        filepath = os.path.join(directory, filename)

        if progress:
            print(f"📦 [{i}/{total}] Processing: {filename}")

        unzip_file(filepath, extract_here, safe, verbose)
        processed += 1

        if not all_files:
            break

    print(f"✅ Processed {processed} archive(s).")
    return 0


# -----------------------
# ZIP
# -----------------------
def zip_directory(directory: str, output_name=None):
    directory = normalize_posix_path(directory)

    if not os.path.isdir(directory):
        print(f"❌ Not a valid directory: {directory}")
        return 2

    base_name = output_name or os.path.basename(directory.rstrip("/"))
    zip_path = os.path.join(os.path.dirname(directory), base_name + ".zip")

    try:
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
            for root, _, files in os.walk(directory):
                for f in files:
                    full_path = os.path.join(root, f)
                    rel_path = os.path.relpath(full_path, directory)
                    z.write(full_path, rel_path)

        print(f"🗜️ Created: {zip_path}")
        return 0

    except Exception as e:
        print(f"❌ Failed to zip: {e}")
        return 1


# -----------------------
# MAIN
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cop",
        description="Archive tool with safe unzip, progress, and verbose modes."
    )

    parser.add_argument("path", nargs="*", help="Target path")

    parser.add_argument("--unzip", action="store_true", help="Unzip archive(s).")
    parser.add_argument("--zip", action="store_true", help="Zip a directory.")

    parser.add_argument("--all", action="store_true", help="Process all archives.")
    parser.add_argument("--here", action="store_true", help="Extract into current directory (can mix files).")

    parser.add_argument("--safe", action="store_true",
                        help="Always extract into isolated folders (recommended).")

    parser.add_argument("--verbose", action="store_true",
                        help="Show detailed file extraction.")

    parser.add_argument("--progress", action="store_true",
                        help="Show progress while processing.")

    parser.add_argument("--zip-name", metavar="NAME", help="Custom zip filename.")

    args = parser.parse_args()

    input_path = " ".join(args.path).strip()
    if not input_path:
        input_path = str(Path.cwd())

    target = normalize_posix_path(input_path)

    # Prevent conflicting modes
    special_flags = sum([
        args.unzip,
        args.zip,
    ])

    if special_flags > 1:
        print("❌ Choose only one of --zip or --unzip.")
        return 2

    # -----------------------
    # UNZIP
    # -----------------------
    if args.unzip:
        return unzip_in_directory(
            target,
            extract_here=args.here,
            all_files=args.all,
            safe=args.safe,
            verbose=args.verbose,
            progress=args.progress
        )

    # -----------------------
    # ZIP
    # -----------------------
    if args.zip:
        return zip_directory(
            target,
            output_name=args.zip_name
        )

    print("ℹ️ No action specified. Use --zip or --unzip.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
