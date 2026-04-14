#!/usr/bin/env python3
# Script Name: remext.py
# ID: SCR-ID-20260317130709-U2356YWU0Q
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: remext

import os

def remove_extensions_in_directory():
    directory = input("Enter the full path of the directory: ").strip()

    if not os.path.isdir(directory):
        print("❌ Not a valid directory.")
        return

    renamed_count = 0

    for filename in os.listdir(directory):
        full_path = os.path.join(directory, filename)

        if os.path.isfile(full_path):
            name, ext = os.path.splitext(filename)

            # Only rename if there's an extension
            if ext:
                new_path = os.path.join(directory, name)

                # Check if destination exists already to avoid overwriting
                if not os.path.exists(new_path):
                    os.rename(full_path, new_path)
                    print(f"Renamed: {filename} → {name}")
                    renamed_count += 1
                else:
                    print(f"⚠️ Skipped (would overwrite): {name}")

    print(f"\n✅ Done! Renamed {renamed_count} file(s).")

if __name__ == "__main__":
    remove_extensions_in_directory()
