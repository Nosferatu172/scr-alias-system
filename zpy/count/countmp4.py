#!/usr/bin/env python3
# Script Name: countmp4.py
# ID: SCR-ID-20260317130634-C3Q0010SVV
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: countmp4

import os
import sys
import shutil
import subprocess
import signal

# =======================
# CHANGE ONLY THIS
# =======================
TARGET_EXTENSIONS = (".mp4",)   # e.g. (".py",) (".mp3",) (".mp4",) (".rb",)
# =======================

# -----------------------
# Ctrl+C handler
# -----------------------
def handle_interrupt(signum, frame):
    print("\n🛑 Operation cancelled by user (Ctrl+C).")
    sys.exit(130)

signal.signal(signal.SIGINT, handle_interrupt)

# -----------------------
# Clipboard helper
# -----------------------
def copy_to_clipboard(text: str):
    try:
        # WSL / Windows clipboard
        if os.path.isdir("/mnt/c"):
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
        else:
            # Native Linux fallback
            if shutil.which("wl-copy"):
                subprocess.run(["wl-copy"], input=text.encode(), check=True)
            elif shutil.which("xclip"):
                subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode(), check=True)
            else:
                raise RuntimeError("No clipboard utility found")
        print("📋 Copied to clipboard!")
    except Exception as e:
        print(f"⚠️ Clipboard failed: {e}")

# -----------------------
# File counter
# -----------------------
def count_target_files(directory, extensions):
    exts = tuple(e.lower() for e in extensions)
    file_count = 0
    file_paths = []

    for root, _, files in os.walk(directory):
        for name in files:
            if name.lower().endswith(exts):
                file_count += 1
                file_paths.append(os.path.join(root, name))

    return file_count, file_paths

# -----------------------
# Main
# -----------------------
def main():
    try:
        cwd = os.getcwd()
        print(f"📍 Current directory: {cwd}")

        choice = input("Use current directory? (Y/n): ").strip().lower()
        if choice in ("", "y", "yes"):
            path = cwd
        else:
            path = input("📂 Enter directory to scan: ").strip()

        if not os.path.isdir(path):
            print("❌ Invalid directory.")
            return

        copy_dir = input("📋 Copy directory path to clipboard? (y/N): ").lower().startswith("y")
        if copy_dir:
            copy_to_clipboard(path)

        count, files = count_target_files(path, TARGET_EXTENSIONS)

        print(f"\n✅ Total {', '.join(TARGET_EXTENSIONS)} files found: {count}")

        show_files = input("📜 Show file paths? (y/N): ").lower().startswith("y")
        if show_files:
            for f in files:
                print(f)

        copy_choice = input("\n📋 Copy results to clipboard? (none/count/paths/both): ").lower()

        if copy_choice in ("count", "both"):
            copy_to_clipboard(str(count))

        if copy_choice in ("paths", "both"):
            copy_to_clipboard("\n".join(files))

    except EOFError:
        print("\n🛑 Input cancelled.")

if __name__ == "__main__":
    main()
