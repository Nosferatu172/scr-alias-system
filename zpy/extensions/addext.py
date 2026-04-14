#!/usr/bin/env python3
# Script Name: addext.py
# ID: SCR-ID-20260317130705-0DNZCZ9ZXA
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: addext

import os

def rename_files_with_new_extension(directory, new_ext):
    # Normalize the new extension (add dot if missing)
    if not new_ext.startswith('.'):
        new_ext = '.' + new_ext

    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)

        # Skip directories
        if os.path.isdir(filepath):
            continue

        # Remove existing extension
        base = os.path.splitext(filename)[0]

        # Create new filename with the desired extension
        new_filename = base + new_ext
        new_filepath = os.path.join(directory, new_filename)

        # Rename only if different
        if filename != new_filename:
            os.rename(filepath, new_filepath)
            print(f"Renamed: {filename} -> {new_filename}")

def main():
    directory = os.getcwd()  # Use current working directory
    print(f"Target directory: {directory}")

    # Ask user for desired extension
    new_ext = input("Enter the new extension (e.g., sh, py, rb): ").strip()

    if not new_ext:
        print("No extension entered. Exiting.")
        return

    print(f"This will rename all files in the directory to use the '.{new_ext}' extension.")
    confirm = input("Do you want to continue? (yes/no): ").strip().lower()

    if confirm in ['yes', 'y']:
        rename_files_with_new_extension(directory, new_ext)
        print("Done.")
    else:
        print("Operation cancelled.")

if __name__ == '__main__':
    main()
