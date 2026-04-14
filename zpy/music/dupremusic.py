#!/usr/bin/env python3
# Script Name: dupremusic.py
# ID: SCR-ID-20260329094537-V3CGG70V30
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dupremusic

import os
import hashlib
import re
from collections import defaultdict

CHUNK_SIZE = 65536

def quick_hash(path, chunk_size=CHUNK_SIZE):
    """Hash only first and last chunk (fast pre-check)."""
    hasher = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            start = f.read(chunk_size)
            f.seek(-chunk_size, os.SEEK_END)
            end = f.read(chunk_size)
            hasher.update(start)
            hasher.update(end)
    except Exception:
        return None
    return hasher.hexdigest()

def full_hash(path):
    """Full SHA256 hash."""
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(CHUNK_SIZE), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def scan_files(root_dir):
    """Collect files by size."""
    size_map = defaultdict(list)

    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.lower().endswith((".mp3", ".mp4")):
                path = os.path.join(dirpath, filename)
                try:
                    size = os.path.getsize(path)
                    size_map[size].append(path)
                except Exception as e:
                    print(f"⚠️ Skipped {path}: {e}")

    return size_map

def find_duplicates(root_dir):
    size_map = scan_files(root_dir)

    exact_duplicates = []
    near_duplicates = []

    for size, files in size_map.items():
        if len(files) < 2:
            continue

        # Step 1: quick hash
        quick_map = defaultdict(list)
        for f in files:
            qh = quick_hash(f)
            if qh:
                quick_map[qh].append(f)

        for group in quick_map.values():
            if len(group) < 2:
                continue

            # Step 2: full hash
            full_map = defaultdict(list)
            for f in group:
                try:
                    fh = full_hash(f)
                    full_map[fh].append(f)
                except Exception as e:
                    print(f"⚠️ Hash error {f}: {e}")

            # exact duplicates
            for fileset in full_map.values():
                if len(fileset) > 1:
                    base = fileset[0]
                    for dup in fileset[1:]:
                        exact_duplicates.append((base, dup))

            # near duplicates (same size but different hash)
            if len(full_map) > 1:
                all_files = [f for group in full_map.values() for f in group]
                if len(all_files) > 1:
                    near_duplicates.append(all_files)

    return exact_duplicates, near_duplicates

def smart_delete(duplicates):
    deleted = []
    kept = []

    for original, duplicate in duplicates:
        if re.search(r'_(\d+)\.(mp3|mp4)$', os.path.basename(duplicate), re.IGNORECASE):
            to_delete = duplicate
        elif re.search(r'_(\d+)\.(mp3|mp4)$', os.path.basename(original), re.IGNORECASE):
            to_delete = original
        else:
            to_delete = duplicate

        try:
            os.remove(to_delete)
            deleted.append(to_delete)
        except Exception as e:
            print(f"⚠️ Delete error {to_delete}: {e}")

        kept.append(original if to_delete == duplicate else duplicate)

    return deleted, kept

def main():
    print("🎵 Advanced Duplicate Cleaner 🎥")
    root_dir = input("\n📂 Enter directory: ").strip()

    if not os.path.isdir(root_dir):
        print("❌ Invalid directory.")
        return

    print("\n🔍 Scanning deeply (all subfolders)...")
    exact, near = find_duplicates(root_dir)

    print(f"\n✅ Exact duplicates: {len(exact)}")

    if near:
        print(f"⚠️ Potential near-duplicates groups: {len(near)}")
        print("These need manual review.")

    if not exact:
        return

    confirm = input("\n🗑️ Delete exact duplicates? (y/n): ").lower()
    if confirm != "y":
        return

    deleted, kept = smart_delete(exact)

    print(f"\n✅ Deleted: {len(deleted)}")
    print(f"📦 Kept: {len(kept)}")

if __name__ == "__main__":
    main()
