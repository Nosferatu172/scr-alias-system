#!/usr/bin/env python3
# Script Name: username-changer-1.1.py
# ID: SCR-ID-20260317130936-UPBTIXSXSD
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: username-changer-1.1

import os

def replace_word_in_files():
    # Get user input
    directory = input("Enter the directory path: ").strip()
    file_ext = input("Enter the file extension (e.g., .txt): ").strip()
    old_word = input("Enter the word to replace: ")
    new_word = input("Enter the replacement word: ")

    if not os.path.isdir(directory):
        print("❌ The directory does not exist.")
        return

    files_modified = 0

    # Traverse directory
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(file_ext):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    if old_word in content:
                        new_content = content.replace(old_word, new_word)
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print(f"✅ Modified: {file_path}")
                        files_modified += 1

                except Exception as e:
                    print(f"⚠️ Could not process {file_path}: {e}")

    print(f"\nDone. {files_modified} file(s) modified.")

if __name__ == "__main__":
    replace_word_in_files()
