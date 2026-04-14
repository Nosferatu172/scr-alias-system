#!/usr/bin/env python3
# Script Name: empfolders.py
# ID: SCR-ID-20260329031407-6NHARM3O7K
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: empfolders

import os
import shutil
import subprocess
import sys

# ==========================================================
# Path Converter (Python version of your Ruby script)
# ==========================================================
def convert_paths(path: str):
    path = path.strip()
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
        # Skip if files exist
        if files:
            continue

        # Skip if subdirs still exist
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
# Main
# ==========================================================
print("=== Empty Folder Cleanup Tool ===")

input_path = input("Enter directory (Windows or WSL path): ").strip('"').strip("'")
converted = convert_paths(input_path)

if not converted:
    print("❌ Unrecognized path format.")
    sys.exit(1)

print(f"\nWSL Path:     {converted['scr']}")
print(f"Windows Path: {converted['windows']}")

choice = input("\nCopy which path to clipboard? (w = Windows, l = WSL, n = none): ").lower()
if choice == "w":
    copy_to_clipboard(converted["windows"])
    print("✅ Windows path copied.")
elif choice == "l":
    copy_to_clipboard(converted["scr"])
    print("✅ WSL path copied.")

target_dir = converted["scr"]

if not os.path.isdir(target_dir):
    print(f"❌ Directory does not exist: {target_dir}")
    sys.exit(1)

confirm = input(f"\nDelete ALL empty folders under:\n{target_dir}\n(y/n): ").lower()
if confirm != "y":
    print("❌ Aborted.")
    sys.exit(0)

removed_dirs = remove_empty_dirs(target_dir)

print("\n=== Cleanup Complete ===")
print(f"Total empty folders removed: {len(removed_dirs)}")
