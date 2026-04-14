#!/usr/bin/env python3
# Script Name: dirmir2.py
# ID: SCR-ID-20260412154158-4YDYE7EPPC
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dirmir2
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

    # Windows -> WSL
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
# File Transfer
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


def unique_path(p: Path):
    if not p.exists():
        return p
    i = 1
    while True:
        new = p.with_name(f"{p.stem}_{i}{p.suffix}")
        if not new.exists():
            return new
        i += 1


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
                print(f"\nSKIP: {dest}")
                continue

        print(f"\n{'MOVE' if move else 'COPY'}: {f} -> {dest}")

        with f.open("rb") as src, dest.open("wb") as out:
            while chunk := src.read(1024 * 1024 * 4):
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
    parser = argparse.ArgumentParser(description="Simple file combiner")

    parser.add_argument("-m", "--move", action="store_true")
    parser.add_argument("-c", "--copy", action="store_true")
    parser.add_argument("-a", "--active", action="store_true")
    parser.add_argument("-s", "--source", nargs="+")
    parser.add_argument("-d", "--dest", required=True)
    parser.add_argument("-f", "--flat", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--rename", action="store_true")

    args = parser.parse_args()

    move = args.move
    if args.copy:
        move = False

    # destination
    dst = normalize_path(args.dest).resolve()

    if str(dst) == "/":
        print("❌ Refusing to write to '/'")
        return 1

    # sources
    sources = []

    if args.active:
        sources.append(Path.cwd())

    if args.source:
        for s in args.source:
            sources.append(normalize_path(s).resolve())

    if not sources:
        print("❌ No sources provided")
        return 1

    # gather files
    files = list(get_files(sources))

    if not files:
        print("❌ No files found")
        return 1

    print("\n📂 PLAN")
    print(f"Mode: {'MOVE' if move else 'COPY'}")
    print(f"Dest: {dst}")
    print(f"Files: {len(files)}\n")

    if move:
        confirm = input("⚠️ Move deletes originals. Continue? (y/n): ")
        if confirm.lower() != "y":
            return 0

    transfer(
        files=files,
        dst=dst,
        move=move,
        flatten=args.flat,
        overwrite=args.overwrite,
        rename=args.rename,
    )

    print("\n✅ Done")


if __name__ == "__main__":
    main()
