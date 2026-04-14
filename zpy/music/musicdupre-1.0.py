#!/usr/bin/env python3
# Script Name: Music-duplicate-remover.py
# ID: SCR-ID-20260317131007-HC8VV3CPQY
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: Music-duplicate-remover

import os
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

# List of file extensions to consider
SUPPORTED_EXTENSIONS = ('.mp3', '.mp4', '.mov', '.jpg', '.jpeg', '.wav', '.flac', '.mkv')

def hash_file(file_path):
    """Generate SHA-256 hash for a file"""
    sha256_hash = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            # Read and update hash string value in blocks of 4K
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return file_path, sha256_hash.hexdigest()
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return file_path, None

def remove_duplicates(directory):
    """Scan directory and remove duplicate files of multiple types"""
    seen_hashes = {}
    duplicate_files = []
    total_files = 0
    duplicate_count = 0

    # Get a list of all supported files
    files_to_process = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(SUPPORTED_EXTENSIONS):
                file_path = os.path.join(root, file)
                files_to_process.append(file_path)
                total_files += 1

    # Process each file with a progress bar and parallel hashing
    print(f"Scanning {total_files} files...")

    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(hash_file, file_path): file_path for file_path in files_to_process}
        for future in tqdm(as_completed(futures), total=len(futures), desc="Processing Files"):
            file_path, file_hash = future.result()
            if file_hash:
                if file_hash in seen_hashes:
                    # Duplicate found, schedule for deletion
                    duplicate_files.append(file_path)
                    duplicate_count += 1
                else:
                    seen_hashes[file_hash] = file_path

    # Display total files processed and duplicates found
    print(f"\nTotal files processed: {total_files}")
    print(f"Total duplicates found: {duplicate_count}")

    # Remove the duplicate files
    for duplicate in duplicate_files:
        try:
            os.remove(duplicate)
            print(f"Deleted duplicate: {duplicate}")
        except Exception as e:
            print(f"Error deleting file {duplicate}: {e}")

if __name__ == "__main__":
    # Ask the user for the directory to scan
    directory = input("Enter the directory path to scan for duplicates: ")

    # Check if the directory exists
    if os.path.isdir(directory):
        remove_duplicates(directory)
    else:
        print(f"The directory {directory} does not exist. Please try again with a valid path.")
