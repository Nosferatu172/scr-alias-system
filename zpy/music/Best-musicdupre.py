#!/usr/bin/env python3
# Script Name: Best-Music-Duplicates-remover.py
# ID: SCR-ID-20260317131003-65ZFSSUTN3
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: Best-Music-Duplicates-remover

import os
import hashlib
import shutil
from tqdm import tqdm

def hash_file(file_path, block_size=65536):
    hasher = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            while chunk := f.read(block_size):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        print(f"Error hashing file {file_path}: {e}")
        return None

def find_duplicates(directory, use_size_filter=True):
    seen_hashes = {}
    duplicates = []
    file_list = []

    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            if os.path.isfile(file_path):
                file_list.append(file_path)

    print(f"\nHashing {len(file_list)} files...")
    for file_path in tqdm(file_list, desc="Hashing files"):
        try:
            file_size = os.path.getsize(file_path)
            file_hash = hash_file(file_path)

            if not file_hash:
                continue

            key = (file_hash, file_size) if use_size_filter else file_hash

            if key in seen_hashes:
                duplicates.append((file_path, seen_hashes[key]))
            else:
                seen_hashes[key] = file_path
        except Exception as e:
            print(f"Failed processing {file_path}: {e}")

    return duplicates

def handle_duplicates(duplicates, target_directory):
    if not duplicates:
        print("\nNo duplicates found.")
        return

    duplicates_dir = os.path.join(target_directory, "duplicates")
    os.makedirs(duplicates_dir, exist_ok=True)

    print(f"\nFound {len(duplicates)} duplicate(s).")
    for dup, original in duplicates:
        try:
            base_name = os.path.basename(dup)
            dest = os.path.join(duplicates_dir, base_name)

            if os.path.exists(dest):
                base_name = f"copy_of_{base_name}"
                dest = os.path.join(duplicates_dir, base_name)

            shutil.move(dup, dest)
            print(f"Moved duplicate: {dup} → {dest}")
        except Exception as e:
            print(f"Could not move {dup}: {e}")

def main():
    print("Duplicate File Finder (Hash-Based)")
    directory = input("Enter target directory: ").strip()

    if not os.path.isdir(directory):
        print("Invalid directory.")
        return

    use_size = input("Use file size filtering for performance? (y/n): ").strip().lower() == 'y'

    duplicates = find_duplicates(directory, use_size_filter=use_size)
    handle_duplicates(duplicates, directory)

if __name__ == "__main__":
    main()
