#!/usr/bin/env python3
# Script Name: cuda-repair.py
# ID: SCR-ID-20260329041013-ZER66HRY1U
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cuda-repair

import os
import shutil
import sys

LIB_PATH = "/usr/lib/wsl/lib"
LIB_REAL = "libcuda.so.1.1"
LIB_LINK1 = "libcuda.so.1"
LIB_LINK2 = "libcuda.so"
BACKUP_SUFFIX = ".bak"

def backup_and_symlink(target, linkname):
    target_path = os.path.join(LIB_PATH, target)
    link_path = os.path.join(LIB_PATH, linkname)
    backup_path = link_path + BACKUP_SUFFIX

    if not os.path.exists(target_path):
        print(f"[!] Target {target_path} does not exist, skipping.")
        return

    if os.path.islink(link_path):
        print(f"[=] {linkname} is already a symlink.")
        return

    if os.path.exists(link_path):
        print(f"[*] Backing up {link_path} -> {backup_path}")
        shutil.move(link_path, backup_path)

    print(f"[*] Creating symlink {link_path} -> {target_path}")
    os.symlink(target_path, link_path)

def fix_symlinks():
    # libcuda.so.1 should point to libcuda.so.1.1
    backup_and_symlink(LIB_REAL, LIB_LINK1)

    # libcuda.so should point to libcuda.so.1
    backup_and_symlink(LIB_LINK1, LIB_LINK2)

def undo():
    for f in [LIB_LINK1, LIB_LINK2]:
        link_path = os.path.join(LIB_PATH, f)
        backup_path = link_path + BACKUP_SUFFIX

        if os.path.exists(backup_path):
            print(f"[*] Restoring backup {backup_path} -> {link_path}")
            if os.path.exists(link_path):
                os.remove(link_path)
            shutil.move(backup_path, link_path)
        else:
            print(f"[!] No backup found for {f}")

def main():
    print("CUDA Lib Symlink Fixer")
    print("======================")
    print("[1] Fix symlink issues")
    print("[2] Undo last fix")
    print("[3] Exit")
    choice = input("Choose an option: ").strip()

    if choice == "1":
        fix_symlinks()
    elif choice == "2":
        undo()
    elif choice == "3":
        print("Exiting...")
        sys.exit(0)
    else:
        print("Invalid choice.")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("[!] Run this script as root (sudo).")
        sys.exit(1)
    main()
