#!/usr/bin/env python3
# Script Name: dirmir3.py
# ID: SCR-ID-20260412154206-G3T2TLRBIF
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dirmir3
import argparse
import os
import shutil
import sys
import time
from pathlib import Path

# ---------------------------
# Helpers
# ---------------------------

def is_wsl():
    try:
        return "microsoft" in os.uname().release.lower()
    except:
        return False


def normalize_path(p: str) -> Path:
    p = (p or "").strip().strip('"').strip("'")
    p = os.path.expandvars(os.path.expanduser(p))

    # Windows → WSL
    if is_wsl() and ":" in p:
        drive = p[0].lower()
        rest = p[2:].replace("\\", "/")
        return Path(f"/mnt/{drive}/{rest}")

    return Path(p)


def format_bytes(n):
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}PB"


# ---------------------------
# Progress Bar
# ---------------------------

class Progress:
    def __init__(self, total):
        self.total = total
        self.done = 0
        self.start = time.time()

    def update(self, amount):
        self.done += amount
        percent = (self.done / self.total * 100) if self.total else 100
        speed = self.done / (time.time() - self.start + 0.001)

        bar_len = 30
        filled = int(bar_len * percent / 100)
        bar = "#" * filled + "-" * (bar_len - filled)

        print(
            f"\r[{bar}] {percent:5.1f}% "
            f"{format_bytes(self.done)}/{format_bytes(self.total)} "
            f"{format_bytes(speed)}/s",
            end="",
            flush=True,
        )

    def finish(self):
        print()


# ---------------------------
# File Discovery
# ---------------------------

def get_files(sources):
    for src in sources:
        if src.is_file():
            yield src
        elif src.is_dir():
            for root, _, files in os.walk(src):
                for f in files:
                    yield Path(root) / f


def total_size(files):
    total = 0
    for f in files:
        try:
            total += f.stat().st_size
        except:
            pass
    return total


# ---------------------------
# Conflict Handling
# ---------------------------

def unique_path(p: Path):
    if not p.exists():
        return p
    i = 1
    while True:
        new = p.with_name(f"{p.stem}_{i}{p.suffix}")
        if not new.exists():
            return new
        i += 1


# ---------------------------
# Transfer Logic
# ---------------------------

def transfer(files, dst, move, flatten, overwrite, rename):
    size = total_size(files)
    prog = Progress(size)

    for f in files:
        target_dir = dst if flatten else dst / f.parent.name
        target_dir.mkdir(parents=True, exist_ok=True)

        dest = target_dir / f.name

        if dest.exists():
            if overwrite:
                dest.unlink()
            elif rename:
                dest = unique_path(dest)
            else:
                print(f"\nSKIP (exists): {dest}")
                continue

        print(f"\n{'MOVE' if move else 'COPY'}: {f} -> {dest}")

        with f.open("rb") as src, dest.open("wb") as out:
            while chunk := src.read(4 * 1024 * 1024):
                out.write(chunk)
                prog.update(len(chunk))

        shutil.copystat(f, dest)

        if move:
            f.unlink()

    prog.finish()


# ---------------------------
# Main
# ---------------------------

def main():
    parser = argparse.ArgumentParser(
        prog="combine4car5",
        description=(
            "Safe directory/file transfer (COPY default).\n"
            "Supports folders, files, and globs.\n"
            "Default conflict policy: SKIP existing (no dupes)."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    # Modes
    parser.add_argument("-c", "--copy", action="store_true",
                        help="Copy mode (default)")
    parser.add_argument("-m", "--move", action="store_true",
                        help="Move mode (destructive)")

    # Sources
    parser.add_argument("-a", "--active-dir", action="store_true",
                        help="Use active directory as source")
    parser.add_argument("-s", "--source", nargs="+",
                        help="Source paths (files, folders, or globs)")

    # Destination
    parser.add_argument("-d", "--dest", required=True,
                        help="Destination directory")

    # Behavior
    parser.add_argument("-f", "--flat", "--flatten", action="store_true",
                        help="Flatten all files into destination root")

    parser.add_argument("-o", "--overwrite", action="store_true",
                        help="Overwrite existing files")

    parser.add_argument("--rename", action="store_true",
                        help="Rename on conflict: *_1, *_2, etc.")

    parser.add_argument("--no-progress", action="store_true",
                        help="Disable progress bar")

    args = parser.parse_args()

    # Mode resolution
    move = args.move
    if args.copy:
        move = False

    # Destination
    dst = normalize_path(args.dest).resolve()

    if str(dst) == "/":
        print("❌ Refusing to write to '/'")
        return 1

    # Sources
    sources = []

    if args.active_dir:
        sources.append(Path.cwd())

    if args.source:
        for s in args.source:
            sources.append(normalize_path(s).resolve())

    if not sources:
        print("❌ No sources provided")
        return 1

    # Collect files
    files = list(get_files(sources))

    if not files:
        print("❌ No files found")
        return 1

    # Plan output
    print("\n📂 plan")
    print(f"Mode:      {'MOVE' if move else 'COPY'}")
    print(f"Dest:      {dst}")
    print(f"Flatten:   {'YES' if args.flat else 'NO'}")
    print(f"Overwrite: {'YES' if args.overwrite else 'NO'}")
    print(f"Conflicts: {'RENAME' if args.rename else ('OVERWRITE' if args.overwrite else 'SKIP')}")
    print(f"Files:     {len(files)}")

    if move:
        confirm = input("\n⚠️ MOVE deletes originals. Continue? (y/n): ")
        if confirm.lower() != "y":
            print("❎ Aborted.")
            return 0

    # Execute
    transfer(
        files=files,
        dst=dst,
        move=move,
        flatten=args.flat,
        overwrite=args.overwrite,
        rename=args.rename,
    )

    print("\n✅ Done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
