#!/usr/bin/env python3
# Script Name: dupre-music-1.1.py

import os
import hashlib
import re
from tqdm import tqdm

def file_hash(path, block_size=65536):
    """Generate a SHA256 hash for the given file."""
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(block_size), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def collect_files(root_dir):
    """Collect all target files first (so tqdm knows total)."""
    targets = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.lower().endswith((".mp3", ".mp4")):
                targets.append(os.path.join(dirpath, filename))
    return targets

def find_duplicates(root_dir):
    """Scan directory for duplicate mp3/mp4 files."""
    file_hashes = {}
    duplicates = []

    files = collect_files(root_dir)

    for full_path in tqdm(files, desc="🔍 Hashing files", unit="file"):
        try:
            hash_value = file_hash(full_path)
        except Exception as e:
            print(f"\n⚠️ Could not hash {full_path}: {e}")
            continue

        if hash_value in file_hashes:
            duplicates.append((file_hashes[hash_value], full_path))
        else:
            file_hashes[hash_value] = full_path

    return duplicates

def smart_delete(duplicates):
    """Prefer deleting _1, _2, etc., if duplicates exist."""
    deleted = []
    kept = []

    for original, duplicate in tqdm(duplicates, desc="🗑️ Deleting duplicates", unit="file"):
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
            print(f"\n⚠️ Error deleting {to_delete}: {e}")

        kept.append(original if to_delete == duplicate else duplicate)

    return deleted, kept

def main():
    print("🎵 Duplicate MP3/MP4 Cleaner 🎥")
    root_dir = input("\n📂 Enter full directory path to scan: ").strip()

    if not os.path.isdir(root_dir):
        print("❌ Invalid directory. Exiting.")
        return

    print("\n🔍 Scanning for duplicates...")
    duplicates = find_duplicates(root_dir)

    if not duplicates:
        print("✅ No duplicates found.")
        return

    print(f"\nFound {len(duplicates)} duplicate pairs.")
    confirm = input("🗑️  Do you want to delete duplicates (y/n)? ").lower()
    if confirm != "y":
        print("❎ No files were deleted.")
        return

    deleted, kept = smart_delete(duplicates)
    print(f"\n✅ Deleted {len(deleted)} duplicates.")
    print(f"📦 Kept {len(kept)} originals.\n")

if __name__ == "__main__":
    main()
