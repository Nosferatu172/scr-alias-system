#!/usr/bin/env python3
# Script Name: alsc.py
# ID: SCR-ID-20260317123506-I8WFN6F6LX
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alsc

import os

# Directories
ACTIVE_DIR = "/mnt/c/scr/aliases/lib/"
RUBY_DIR = "/mnt/c/scr/zru"
PYTHON_DIR = "/mnt/c/scr/zpy"
BASH_SCRIPTS_DIR = "/mnt/c/scr/bash/"

def safe_input(prompt):
    """Input wrapper: exits cleanly on Ctrl+C or if user types E/e."""
    try:
        value = input(prompt)
        if value.strip().lower() == "e":
            print("Process terminated by user. Exiting...")
            exit(0)
        return value
    except KeyboardInterrupt:
        print("\nProcess terminated by user. Exiting...")
        exit(0)

def browse_directory(start_dir, file_extension=None):
    """Browse directories recursively until a file is chosen.
       If file_extension is provided, only show files with that extension.
    """
    current_dir = start_dir
    while True:
        entries = os.listdir(current_dir)
        entries.sort()
        print(f"\nBrowsing: {current_dir}")

        filtered_entries = []
        for entry in entries:
            full_path = os.path.join(current_dir, entry)
            if os.path.isdir(full_path):
                filtered_entries.append((entry, True))  # (name, is_dir)
            elif file_extension is None or entry.endswith(file_extension):
                filtered_entries.append((entry, False))

        for i, (entry, is_dir) in enumerate(filtered_entries, 1):
            prefix = "[DIR]" if is_dir else ""
            print(f"{i}. {prefix} {entry}")

        print("0. Go back")
        choice = safe_input("Enter number (or 0 to go back): ")

        if not choice.isdigit():
            print("Invalid choice.")
            continue

        choice = int(choice)
        if choice == 0:
            if current_dir == start_dir:
                return None
            current_dir = os.path.dirname(current_dir)
        else:
            if 1 <= choice <= len(filtered_entries):
                entry_name, is_dir = filtered_entries[choice - 1]
                full_path = os.path.join(current_dir, entry_name)
                if is_dir:
                    current_dir = full_path
                else:
                    return full_path
            else:
                print("Invalid choice.")

def list_files_in_dir(directory):
    files = [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))]
    for i, file in enumerate(files, 1):
        print(f"{i}. {file}")
    return files

def display_file_with_lines(filepath):
    with open(filepath, "r") as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        print(f"{i}: {line.strip()}")
    return lines

def choose_file():
    print("\nSelect a file from active aliases:")
    files = list_files_in_dir(ACTIVE_DIR)
    choice = int(safe_input("Enter number: ")) - 1
    return os.path.join(ACTIVE_DIR, files[choice])

def edit_file(filepath):
    lines = display_file_with_lines(filepath)
    print("\nOptions:")
    print("1. Append new alias")
    print("2. Remove alias")
    print("3. Edit alias")
    choice = safe_input("Select option: ")

    if choice == "1":
        add_alias(lines, filepath)
    elif choice == "2":
        line_num = int(safe_input("Enter line number to remove: "))
        if 1 <= line_num <= len(lines):
            removed = lines.pop(line_num - 1)
            print(f"Removed: {removed.strip()}")
        else:
            print("Invalid line number.")
    elif choice == "3":
        line_num = int(safe_input("Enter line number to edit: "))
        if 1 <= line_num <= len(lines):
            print(f"Current: {lines[line_num - 1].strip()}")
            new_line = safe_input("Enter new alias: ")
            lines[line_num - 1] = new_line + "\n"
        else:
            print("Invalid line number.")

    with open(filepath, "w") as f:
        f.writelines(lines)

def add_alias(lines, filepath):
    print("\nAlias types:")
    print("1. Ruby")
    print("2. Python")
    print("3. Bash (commands)")
    print("4. Basic")
    print("5. Manual")
    print("6. Bash Script")  # <-- new option

    choice = safe_input("Select type: ")

    if choice == "1":  # Ruby
        ruby_file = browse_directory(RUBY_DIR)
        if ruby_file:
            suggested = os.path.splitext(os.path.basename(ruby_file))[0]
            alias_name = safe_input(f"Enter alias name (default: {suggested}): ").strip() or suggested
            new_alias = f"alias {alias_name}='ruby {ruby_file}'\n"
        else:
            print("No file selected.")
            return

    elif choice == "2":  # Python
        py_file = browse_directory(PYTHON_DIR, file_extension=".py")
        if py_file:
            suggested = os.path.splitext(os.path.basename(py_file))[0]
            alias_name = safe_input(f"Enter alias name (default: {suggested}): ").strip() or suggested
            new_alias = f"alias {alias_name}='python3 {py_file}'\n"
        else:
            print("No file selected.")
            return

    elif choice == "3":  # Bash commands
        alias_name = safe_input("Enter alias name: ")
        cmd = safe_input("Enter bash command: ")
        new_alias = f"alias {alias_name}='{cmd}'\n"

    elif choice == "6":  # Bash scripts
        bash_file = browse_directory(BASH_SCRIPTS_DIR, file_extension=".sh")
        if bash_file:
            suggested = os.path.splitext(os.path.basename(bash_file))[0]
            alias_name = safe_input(f"Enter alias name (default: {suggested}): ").strip() or suggested
            new_alias = f"alias {alias_name}='bash {bash_file}'\n"
        else:
            print("No file selected.")
            return

    elif choice == "4":  # Basic
        alias_name = safe_input("Enter alias name: ")
        cmd = safe_input("Enter basic command: ")
        new_alias = f"alias {alias_name}='{cmd}'\n"

    elif choice == "5":  # Manual
        manual_alias = safe_input("Enter full alias line manually (e.g., alias ll='ls -la'): ")
        new_alias = manual_alias.strip() + "\n"

    else:
        print("Invalid choice.")
        return

    lines.append(new_alias)
    with open(filepath, "w") as f:
        f.writelines(lines)
    print(f"Added alias: {new_alias.strip()}")

def main():
    filepath = choose_file()
    edit_file(filepath)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nProcess terminated by user. Exiting...")
        exit(0)
