#!/usr/bin/env python3
# Script Name: alphabetize.py
# ID: SCR-ID-20260317123904-7UV30HXK1U
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alphabetize

import os
import sys


# --- Color Functions ---
def color(text, code):
    return f"\033[{code}m{text}\033[0m"

def green(text): return color(text, 32)
def yellow(text): return color(text, 33)
def cyan(text): return color(text, 36)
def red(text): return color(text, 31)
def bold(text): return color(text, 1)


# --- File Handling Functions ---
def list_txt_files(directory):
    return [
        f for f in os.listdir(directory)
        if os.path.isfile(os.path.join(directory, f)) and f.lower().endswith(".txt")
    ]


def read_text_file_with_fallback(file_path):
    """
    Try several common encodings and return (content, encoding_used).
    """
    encodings_to_try = [
        "utf-8",
        "utf-8-sig",
        "cp1252",
        "latin-1",
    ]

    for enc in encodings_to_try:
        try:
            with open(file_path, "r", encoding=enc) as f:
                return f.read(), enc
        except UnicodeDecodeError:
            continue

    raise UnicodeDecodeError(
        "unknown", b"", 0, 1,
        f"Could not decode file with tried encodings: {encodings_to_try}"
    )


def backup_file(file_path):
    backup_path = file_path[:-4] + "_backup.txt"
    content, enc_used = read_text_file_with_fallback(file_path)

    with open(backup_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    print(green(f"✔ Backup created: {backup_path}"))
    print(cyan(f"  ↳ Read using: {enc_used} | Backup saved as UTF-8"))


def alphabetize_file(file_path, make_backup, keep_blank_lines=False):
    if make_backup:
        backup_file(file_path)

    content, enc_used = read_text_file_with_fallback(file_path)

    lines = [line.strip() for line in content.splitlines()]

    if not keep_blank_lines:
        lines = [line for line in lines if line]

    # Case-insensitive sort
    lines = sorted(lines, key=str.casefold)

    with open(file_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(cyan(f"→ Alphabetized: {file_path}"))
    print(cyan(f"  ↳ Read using: {enc_used} | Saved as UTF-8"))


# --- MAIN PROGRAM ---
print(bold("\n🗂 Welcome to the Python TXT Alphabetizer!\n"))

dir_path = input(yellow("📁 Enter the full path to the directory: ")).strip()

if not os.path.isdir(dir_path):
    print(red("✘ That directory doesn't exist."))
    sys.exit(1)

txt_files = list_txt_files(dir_path)

if not txt_files:
    print(red("✘ No .txt files found in the directory."))
    sys.exit(1)

print(bold("\n📄 Found the following .txt files:"))
for i, file in enumerate(txt_files, 1):
    print(f"{i}. {file}")

choice = input(
    yellow("\n🔢 Type a number to select a file, or type 'all' to alphabetize all files: ")
).strip()

backup_choice = input(
    yellow("\n💾 Would you like to create backups before alphabetizing? (yes/no): ")
).strip().lower()
make_backup = backup_choice.startswith("y")

blank_choice = input(
    yellow("\n📝 Keep blank lines? (yes/no): ")
).strip().lower()
keep_blank_lines = blank_choice.startswith("y")

print("\n🛠 Processing...\n")

try:
    if choice.lower() == "all":
        for file in txt_files:
            alphabetize_file(os.path.join(dir_path, file), make_backup, keep_blank_lines)
    elif choice.isdigit() and 1 <= int(choice) <= len(txt_files):
        selected_file = txt_files[int(choice) - 1]
        alphabetize_file(os.path.join(dir_path, selected_file), make_backup, keep_blank_lines)
    else:
        print(red("✘ Invalid choice."))
        sys.exit(1)

    print(bold("\n✅ Done! Your file(s) are now alphabetized.\n"))

except Exception as e:
    print(red(f"\n✘ Error: {e}\n"))
    sys.exit(1)
