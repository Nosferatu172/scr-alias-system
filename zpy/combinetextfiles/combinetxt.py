#!/usr/bin/env python3
# Script Name: combinetxt.py
# ID: SCR-ID-20260329040943-K83L3OENHO
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: combinetxt

import argparse
import os
from pathlib import Path

DEFAULT_EXTENSIONS = {
    ".txt", ".log", ".csv", ".lst", ".list",
    ".conf", ".cfg", ".ini",
    ".json", ".xml",
    ".yaml", ".yml",
    ".md", ".text"
}

ENCODINGS_TO_TRY = [
    "utf-8",
    "utf-8-sig",
    "cp1252",
    "latin-1"
]


def get_effective_cwd() -> Path:
    """
    Prefer the directory the user launched the command from.
    Falls back to the current process cwd if not provided.
    """
    caller = os.environ.get("SCR_CALLER_PWD", "").strip()
    if caller and Path(caller).is_dir():
        return Path(caller).resolve()
    return Path.cwd()


def looks_binary(path, sample_size=4096):
    try:
        with open(path, "rb") as f:
            chunk = f.read(sample_size)
        return b"\x00" in chunk
    except Exception:
        return True


def read_lines(path):
    for enc in ENCODINGS_TO_TRY:
        try:
            with open(path, "r", encoding=enc) as f:
                return [line.rstrip("\r\n") for line in f]
        except UnicodeDecodeError:
            continue
        except Exception:
            return None

    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return [line.rstrip("\r\n") for line in f]
    except Exception:
        return None


def parse_extensions(ext_string):
    exts = set()
    for item in ext_string.split(","):
        item = item.strip().lower()
        if not item:
            continue
        if not item.startswith("."):
            item = "." + item
        exts.add(item)
    return exts


def collect_files(directory, recursive, exts, include_no_ext):
    if recursive:
        iterator = directory.rglob("*")
    else:
        iterator = directory.iterdir()

    files = []

    for p in iterator:
        if not p.is_file():
            continue

        suffix = p.suffix.lower()

        if include_no_ext and suffix == "":
            files.append(p)
        elif suffix in exts:
            files.append(p)

    return sorted(files)


def combine(directory, output_name, recursive, exts, include_no_ext, keep_blank, preserve_order):
    output = directory / output_name
    files = collect_files(directory, recursive, exts, include_no_ext)

    seen = set()
    combined = []

    files_read = 0
    skipped_binary = 0
    skipped_failed = 0

    for file in files:
        if file.resolve() == output.resolve():
            continue

        if looks_binary(file):
            skipped_binary += 1
            continue

        lines = read_lines(file)

        if lines is None:
            skipped_failed += 1
            continue

        files_read += 1

        for line in lines:
            if not keep_blank and not line.strip():
                continue

            if preserve_order:
                if line not in seen:
                    seen.add(line)
                    combined.append(line)
            else:
                seen.add(line)

    final_lines = combined if preserve_order else sorted(seen)

    with open(output, "w", encoding="utf-8") as f:
        for line in final_lines:
            f.write(line + "\n")

    print(f"\nOutput file: {output}")
    print(f"Files scanned: {len(files)}")
    print(f"Files read: {files_read}")
    print(f"Unique lines: {len(final_lines)}")
    print(f"Binary skipped: {skipped_binary}")
    print(f"Failed skipped: {skipped_failed}")


def interactive():
    base_cwd = get_effective_cwd()

    while True:
        directory = input("Enter directory (or 'e' to exit): ").strip()

        if directory.lower() == "e":
            break

        if not directory:
            p = base_cwd
        else:
            p = Path(directory).expanduser()
            if not p.is_absolute():
                p = (base_cwd / p).resolve()

        if not p.is_dir():
            print("Invalid directory.\n")
            continue

        combine(
            directory=p,
            output_name="combined_sorted_unique.txt",
            recursive=False,
            exts=DEFAULT_EXTENSIONS,
            include_no_ext=False,
            keep_blank=False,
            preserve_order=False
        )


def main():
    parser = argparse.ArgumentParser(
        description="Combine unique lines from many text-like files."
    )

    parser.add_argument(
        "directory",
        nargs="?",
        help="Directory to scan"
    )

    parser.add_argument(
        "-a",
        "--active",
        action="store_true",
        help="Use current working directory"
    )

    parser.add_argument(
        "-e",
        "--extensions",
        default=",".join(sorted(DEFAULT_EXTENSIONS)),
        help="Comma separated extensions (example: txt,csv,log)"
    )

    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="Search recursively"
    )

    parser.add_argument(
        "--include-no-ext",
        action="store_true",
        help="Include files without extension"
    )

    parser.add_argument(
        "--keep-blank",
        action="store_true",
        help="Keep blank lines"
    )

    parser.add_argument(
        "--preserve-order",
        action="store_true",
        help="Preserve first-seen order"
    )

    parser.add_argument(
        "-o",
        "--output",
        default="combined_sorted_unique.txt",
        help="Output filename"
    )

    args = parser.parse_args()

    if args.active:
        directory = get_effective_cwd()

    elif args.directory:
        directory = Path(args.directory).expanduser()
        if not directory.is_absolute():
            directory = (get_effective_cwd() / directory).resolve()

    else:
        interactive()
        return

    if not directory.is_dir():
        print(f"Invalid directory: {directory}")
        return

    exts = parse_extensions(args.extensions)

    combine(
        directory=directory,
        output_name=args.output,
        recursive=args.recursive,
        exts=exts,
        include_no_ext=args.include_no_ext,
        keep_blank=args.keep_blank,
        preserve_order=args.preserve_order
    )


if __name__ == "__main__":
    main()
