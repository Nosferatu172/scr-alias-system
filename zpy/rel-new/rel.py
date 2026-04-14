#!/usr/bin/env python3

# Script Name: rel.py
# ID: SCR-ID-20260406012753-V9ZSSWOQ0Q
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rel


import os
import sys
import argparse
import fnmatch
import signal
from pathlib import Path

# =============================
# Ctrl+C handler (clean exit)
# =============================
def handle_sigint(sig, frame):
    print("\n⛔ Cancelled (Ctrl+C). Exiting cleanly.", file=sys.stderr)
    sys.exit(130)

signal.signal(signal.SIGINT, handle_sigint)

# =============================
# Core helpers
# =============================
def get_effective_cwd():
    caller = os.environ.get("SCR_CALLER_PWD")
    if caller and os.path.isdir(caller):
        return Path(caller)
    return Path.cwd()

def choose_directory():
    cwd = get_effective_cwd()

    while True:
        print("Enter directory (ENTER = current, q = quit):", file=sys.stderr)
        raw = input("> ").strip()

        if raw.lower() == "q":
            sys.exit(0)

        if raw == "":
            return cwd

        p = Path(raw).expanduser()
        if p.is_dir():
            return p

        print("❌ Invalid directory", file=sys.stderr)

def list_entries(directory):
    entries = sorted(directory.iterdir(), key=lambda x: x.name.lower())

    if not entries:
        print("(empty)")
        return []

    print(f"\nBrowsing: {directory}\n")

    for i, entry in enumerate(entries):
        tag = "[DIR]" if entry.is_dir() else "     "
        print(f"{i:3d}: {tag} {entry.name}")

    return entries

def choose_entry(entries):
    while True:
        s = input("> ").strip()

        if s.lower() == "q":
            sys.exit(0)

        if s.isdigit():
            idx = int(s)
            if 0 <= idx < len(entries):
                return entries[idx]

        print("❌ Invalid selection")

def confirm_delete(target, dry):
    print()
    if dry:
        print("🧪 DRY RUN")

    print(f"Delete: {target}")
    input("Press ENTER to continue (Ctrl+C to cancel)")

def delete_target(path, dry):
    if dry:
        print(f"[DRY] {path}")
        return

    if path.is_dir():
        # delete contents first
        for sub in sorted(path.rglob("*"), reverse=True):
            if sub.is_file() or sub.is_symlink():
                sub.unlink(missing_ok=True)
            elif sub.is_dir():
                sub.rmdir()
        path.rmdir()
    else:
        path.unlink(missing_ok=True)

def match_filters(name, pattern, ext):
    if pattern and not fnmatch.fnmatch(name, pattern):
        return False

    if ext:
        if not ext.startswith("."):
            ext = "." + ext
        if not name.lower().endswith(ext.lower()):
            return False

    return True

def gather_targets(base, recursive, only_files, only_dirs, pattern, ext):
    items = base.rglob("*") if recursive else base.iterdir()
    targets = []

    for item in items:
        name = item.name

        if only_files and not item.is_file():
            continue
        if only_dirs and not item.is_dir():
            continue

        if match_filters(name, pattern, ext):
            targets.append(item)

    return targets

def delete_all(base, args):
    targets = gather_targets(
        base,
        args.recursive,
        args.only_files,
        args.only_dirs,
        args.pattern,
        args.ext
    )

    if not targets:
        print("Nothing matched.")
        return

    print(f"\n📌 Targets: {len(targets)}\n")

    for t in targets:
        tag = "[DIR]" if t.is_dir() else "     "
        print(f"{tag} {t}")

    confirm_delete(base, args.dry)

    for t in targets:
        delete_target(t, args.dry)

    if args.dry:
        print("🧪 Dry run complete.")
    else:
        print("✅ Done.")

# =============================
# Main
# =============================
def main():
    parser = argparse.ArgumentParser(description="rel - interactive remover")

    parser.add_argument("-a", "--active", action="store_true")
    parser.add_argument("-all", action="store_true")
    parser.add_argument("-r", "--recursive", action="store_true")
    parser.add_argument("--dry", action="store_true")
    parser.add_argument("--only-files", action="store_true")
    parser.add_argument("--only-dirs", action="store_true")
    parser.add_argument("--pattern")
    parser.add_argument("--ext")

    args = parser.parse_args()

    if args.only_files and args.only_dirs:
        print("❌ Cannot combine --only-files and --only-dirs")
        return 2

    base = get_effective_cwd() if args.active else choose_directory()

    if not base.is_dir():
        print("❌ Invalid directory")
        return 2

    print(f"\n📂 Base directory: {base}\n")

    if args.all:
        delete_all(base, args)
        return

    entries = list_entries(base)
    if not entries:
        return

    target = choose_entry(entries)

    confirm_delete(target, args.dry)
    delete_target(target, args.dry)

    if args.dry:
        print("🧪 Dry run.")
    else:
        print("✅ Deleted.")

# =============================
# Entrypoint (extra safe)
# =============================
if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⛔ Cancelled.", file=sys.stderr)
        sys.exit(130)
