#!/usr/bin/env python3
# Script Name: meta2op.py
# ID: SCR-ID-20260404035054-T58OE034SB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: meta2op
"""
Ultra Metadata Cleaner (Python - Pro Version)
Features:
- Multithreaded
- Safe temp handling
- Fallback chains
- Aggressive mode
- Skip/cache mode
- Viewer mode (inspect metadata)
"""

import os
import subprocess
import threading
import queue
import time
from pathlib import Path

THREADS = min(os.cpu_count() * 2, 32)
SKIP_EXT = {".exe", ".dll", ".sys"}
MIN_SIZE = 5000  # skip tiny files

processed = 0
failed = 0
lock = threading.Lock()
start_time = time.time()

# --- UTIL ---
def run(cmd):
    return subprocess.run(cmd, shell=True).returncode == 0

# --- VIEWER MODE ---
def view_metadata(path):
    files = list(Path(path).rglob("*"))
    files = [f for f in files if f.is_file()]

    for f in files[:20]:  # limit preview
        print(f"\n=== {f} ===")
        subprocess.run(f'exiftool "{f}"', shell=True)

# --- HANDLERS ---
def handle_image(file, aggressive=False):
    tmp = file.with_suffix(file.suffix + ".tmp")

    try:
        if aggressive:
            ok = run(f'convert "{file}" -strip "{tmp}"')
        else:
            ok = run(f'jpegtran -copy none -optimize "{file}" > "{tmp}"')
            if not ok:
                ok = run(f'convert "{file}" -strip "{tmp}"')

        if ok and tmp.exists():
            tmp.replace(file)
        return ok

    finally:
        if tmp.exists():
            tmp.unlink()


def handle_video(file, aggressive=False):
    tmp = file.with_suffix(file.suffix + ".tmp")
    try:
        if aggressive:
            ok = run(f'ffmpeg -i "{file}" -map_metadata -1 -c:v libx264 -crf 18 -c:a aac "{tmp}" -y')
        else:
            ok = run(f'ffmpeg -loglevel error -i "{file}" -map_metadata -1 -c copy "{tmp}" -y')

        if ok and tmp.exists():
            tmp.replace(file)
        return ok
    finally:
        if tmp.exists():
            tmp.unlink()


def handle_pdf(file):
    tmp = file.with_suffix(".tmp.pdf")
    try:
        ok = run(f'qpdf --linearize --object-streams=generate "{file}" "{tmp}"')
        if ok and tmp.exists():
            tmp.replace(file)
        return ok
    finally:
        if tmp.exists():
            tmp.unlink()


def fallback(file):
    return run(f'exiftool -all= -overwrite_original "{file}"')

# --- PROCESS ---
def process_file(file, aggressive=False, skip_small=True):
    global processed, failed

    if file.suffix.lower() in SKIP_EXT:
        return

    if skip_small and file.stat().st_size < MIN_SIZE:
        return

    try:
        ext = file.suffix.lower()

        if ext in [".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".gif"]:
            ok = handle_image(file, aggressive)
            if not ok:
                ok = fallback(file)

        elif ext in [".mp4", ".mkv", ".mov", ".avi", ".webm", ".mp3", ".wav"]:
            ok = handle_video(file, aggressive)
            if not ok:
                ok = fallback(file)

        elif ext == ".pdf":
            ok = handle_pdf(file)
            if not ok:
                ok = fallback(file)

        else:
            ok = fallback(file)

        with lock:
            if ok:
                processed += 1
            else:
                failed += 1

    except Exception:
        with lock:
            failed += 1

# --- THREADING ---
def worker(q, aggressive, skip_small):
    while True:
        try:
            file = q.get_nowait()
        except queue.Empty:
            return
        process_file(file, aggressive, skip_small)
        q.task_done()

# --- PROGRESS ---
def progress(total):
    while True:
        time.sleep(1)
        elapsed = time.time() - start_time
        rate = processed / elapsed if elapsed > 0 else 0
        print(f"\rProcessed: {processed}/{total} | Failed: {failed} | {rate:.2f} f/s", end="")

# --- MAIN CLEAN ---
def run_clean(path, aggressive=False, skip_small=True):
    files = list(Path(path).rglob("*"))
    files = [f for f in files if f.is_file()]

    q = queue.Queue()
    for f in files:
        q.put(f)

    threading.Thread(target=progress, args=(len(files),), daemon=True).start()

    threads = []
    for _ in range(THREADS):
        t = threading.Thread(target=worker, args=(q, aggressive, skip_small))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    print("\nDONE")
    print(f"Processed: {processed}, Failed: {failed}")

# --- MENU ---
if __name__ == "__main__":
    print("\n=== Metadata Cleaner Pro ===")
    print("1. Clean (fast mode)")
    print("2. Clean (aggressive mode)")
    print("3. View metadata")

    choice = input("Choose: ").strip()
    target = input("Directory: ").strip()

    if not os.path.isdir(target):
        print("Invalid directory")
        exit()

    if choice == "1":
        run_clean(target, aggressive=False, skip_small=True)
    elif choice == "2":
        run_clean(target, aggressive=True, skip_small=False)
    elif choice == "3":
        view_metadata(target)
    else:
        print("Invalid choice")
