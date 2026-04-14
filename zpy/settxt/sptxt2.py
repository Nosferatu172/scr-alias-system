#!/usr/bin/env python3
# Script Name: sptxt2.py
# ID: SCR-ID-20260329031454-4ENRX4BI92
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: sptxt2

import os

#WINPROFILE = ENV["WINPROFILE"]
WINPROFILE = ENV["/mnt/c/scr/keys/"]

def list_text_files(directory):
    """List all .txt files in the given directory."""
    files = [f for f in os.listdir(directory) if f.endswith('.txt')]
    if not files:
        print("No .txt files found in this directory.")
        return []
    print("\nAvailable text files:\n")
    for idx, file in enumerate(files, start=1):
        print(f"{idx}. {file}")
    return files

def split_file(input_file, lines_per_file=5):
    """Split a text file into multiple files with 5 lines each."""
    with open(input_file, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]  # Ignore empty lines

    num_files = len(lines) // lines_per_file + (1 if len(lines) % lines_per_file > 0 else 0)

    for i in range(num_files):
        start_line = i * lines_per_file
        end_line = start_line + lines_per_file
        file_lines = lines[start_line:end_line]

        new_file_name = f"{input_file.rsplit('.', 1)[0]}_part_{i + 1:03}.txt"

        with open(new_file_name, 'w') as new_file:
            new_file.write('\n'.join(file_lines) + '\n')

        print(f"✅ Created: {new_file_name}")

def main():
    # Default directory
    default_directory = "$WINPROFILE/tabs/brave/"
    #default_directory = "/mnt/c/scr/keys/tabs/brave/"
    print("Enter directory path to look for .txt files.")
    print(f"(Press Enter to use default: {default_directory})\n")

    directory = input().strip() or default_directory
    if not os.path.isdir(directory):
        print("❌ Invalid directory.")
        return

    files = list_text_files(directory)
    if not files:
        return

    choice = input("\nEnter the number of the file to split: ").strip()
    if not choice.isdigit() or int(choice) not in range(1, len(files) + 1):
        print("❌ Invalid selection.")
        return

    input_file = os.path.join(directory, files[int(choice) - 1])
    print(f"\nSplitting '{input_file}' into chunks of 5 lines each...\n")
    split_file(input_file, lines_per_file=3)

if __name__ == "__main__":
    main()
