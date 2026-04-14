#!/usr/bin/env python3
# Script Name: empfolders.py
# ID: SCR-ID-20260329031407-6NHARM3O7K
# Created by: Tyler Jensen

import os
import shutil
import subprocess
import sys
import argparse

# ==========================================================
# Path Converter
# ==========================================================
def convert_paths(path: str):
    path = path.strip().strip('"').strip("'")
    results = {}

    # WSL → Windows
    if path.startswith("/mnt/") and len(path) > 6:
        drive = path[5].upper()
        win_path = path.replace(f"/mnt/{path[5]}/", f"{drive}:/").replace("/", "\\")
        results["windows"] = win_path
        results["scr"] = path

    # Windows → WSL
    elif len(path) > 2 and path[1:3] == ":\\":
        drive = path[0].lower()
        scr_path = f"/mnt/{drive}/" + path[3:].replace("\\", "/")
        results["windows"] = path
        results["scr"] = scr_path

    else:
        return None

    return results


# ==========================================================
# Clipboard
# ==========================================================
def copy_to_clipboard(text: str):
    try:
        if os.path.isdir("/mnt/c"):
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
        else:
            subprocess.run(["clip"], input=text.encode("utf-16le"), check=True)
    except Exception as e:
        print(f"⚠️ Clipboard failed: {e}")


# ==========================================================
# Empty Folder Removal
# ==========================================================
def remove_empty_dirs(root_dir):
    removed = []

    for root, dirs, files in os.walk(root_dir, topdown=False):
        if files:
            continue

        if any(os.path.isdir(os.path.join(root, d)) for d in dirs):
            continue

        try:
            os.rmdir(root)
            removed.append(root)
            print(f"🗑️ Removed empty folder: {root}")
        except OSError:
            pass

    return removed


# ==========================================================
# Argument Parser
# ==========================================================
def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove empty folders (supports Windows & WSL paths)",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument(
        "-d", "--dir",
        help="Target directory (C:\\path OR /mnt/c/path)"
    )

    parser.add_argument(
        "-a", "--active",
        action="store_true",
        help="Use current working directory"
    )

    parser.add_argument(
        "-c", "--copy",
        choices=["w", "l"],
        help="Copy path to clipboard (w = Windows, l = WSL)"
    )

    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Skip confirmation prompt"
    )

    return parser.parse_args()


# ==========================================================
# Main
# ==========================================================
def main():
    args = parse_args()

    # Determine input path
    if args.active:
        input_path = os.getcwd()
    elif args.dir:
        input_path = args.dir
    else:
        print("❌ You must provide -d or use -a")
        sys.exit(1)

    converted = convert_paths(input_path)

    if not converted:
        print("❌ Unrecognized path format.")
        sys.exit(1)

    print("\n=== Path Info ===")
    print(f"WSL Path:     {converted['scr']}")
    print(f"Windows Path: {converted['windows']}")

    # Clipboard option
    if args.copy == "w":
        copy_to_clipboard(converted["windows"])
        print("✅ Windows path copied.")
    elif args.copy == "l":
        copy_to_clipboard(converted["scr"])
        print("✅ WSL path copied.")

    target_dir = converted["scr"]

    if not os.path.isdir(target_dir):
        print(f"❌ Directory does not exist: {target_dir}")
        sys.exit(1)

    # Confirmation
    if not args.yes:
        confirm = input(f"\nDelete ALL empty folders under:\n{target_dir}\n(y/n): ").lower()
        if confirm != "y":
            print("❌ Aborted.")
            sys.exit(0)

    # Execute cleanup
    removed_dirs = remove_empty_dirs(target_dir)

    print("\n=== Cleanup Complete ===")
    print(f"Total empty folders removed: {len(removed_dirs)}")


if __name__ == "__main__":
    main()
