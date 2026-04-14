#!/usr/bin/env python3
# Script Name: backup-all.py
# ID: SCR-ID-20260329040920-VMVX10XUE7
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: backup-all

import os
import shutil
import sys

# Source and destination directories
src = "/mnt/f/"
dests = ["/mnt/f/", "/mnt/g/"]

def copy_verbose(src_path, dest_path):
    """Copy file or directory recursively with verbose output."""
    if os.path.isdir(src_path):
        # Ensure destination directory exists
        if not os.path.exists(dest_path):
            os.makedirs(dest_path, exist_ok=True)
            print(f"mkdir: '{dest_path}'")

        for root, dirs, files in os.walk(src_path):
            rel_path = os.path.relpath(root, src_path)
            dest_root = os.path.join(dest_path, rel_path)

            if not os.path.exists(dest_root):
                os.makedirs(dest_root, exist_ok=True)
                print(f"mkdir: '{dest_root}'")

            # Copy files
            for file in files:
                src_file = os.path.join(root, file)
                dest_file = os.path.join(dest_root, file)

                shutil.copy2(src_file, dest_file)
                print(f"'{src_file}' -> '{dest_file}'")
    else:
        shutil.copy2(src_path, dest_path)
        print(f"'{src_path}' -> '{dest_path}'")

def main():
    # Copy everything in src to each destination
    for item in os.listdir(src):
        item_path = os.path.join(src, item)
        for dest in dests:
            copy_verbose(item_path, dest)

if __name__ == "__main__":
    main()
