#!/usr/bin/env python3
# Script Name: dupre-music-1.2.py

import os
import hashlib
import re
import argparse
from tqdm import tqdm

# ----------------------------
# Hashing
# ----------------------------
def file_hash(path, block_size=65536):
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(block_size), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

# ----------------------------
# Collect files
# ----------------------------
def collect_files(root_dir):
    targets = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.lower().endswith((".mp3", ".mp4")):
                targets.append(os.path.join(dirpath, filename))
    return targets

# ----------------------------
# Find duplicates
# ----------------------------
def find_duplicates(root_dir):
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

# ----------------------------
# Smart delete
# ----------------------------
def smart_delete(duplicates):
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

# ----------------------------
# Main
# ----------------------------
def main():
    parser = argparse.ArgumentParser(
        description="🎵 Duplicate MP3/MP4 Cleaner 🎥",
        epilog="Examples:\n"
               "  dupre-music -a\n"
               "  dupre-music /mnt/c/Music\n",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument(
        "path",
        nargs="?",
        help="Directory to scan"
    )

    parser.add_argument(
        "-a", "--active",
        action="store_true",
        help="Use current directory"
    )

    args = parser.parse_args()

    # ----------------------------
    # Determine target directory
    # ----------------------------
    if args.active:
        root_dir = os.getcwd()
    elif args.path:
        root_dir = args.path
    else:
        # fallback to interactive prompt
        root_dir = input("\n📂 Enter full directory path to scan: ").strip()

    if not os.path.isdir(root_dir):
        print("❌ Invalid directory. Exiting.")
        return

    print(f"\n📁 Target Directory: {root_dir}")
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

# ----------------------------
if __name__ == "__main__":
    main()
