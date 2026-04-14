#!/usr/bin/env python3
# Script Name: meta2py.py
# ID: SCR-ID-20260404035109-OF712HTQPF
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: meta2py
"""
Ultra Metadata Cleaner (Python version)
- Multithreaded
- Safer temp handling
- Better error handling
- Supports images, video, pdf, docx, fallback via exiftool
"""

import os
import shutil
import subprocess
import threading
import queue
import time
from pathlib import Path

# --- CONFIG ---
THREADS = min(os.cpu_count() * 2, 32)
SKIP_EXT = {".exe", ".dll", ".sys"}

processed = 0
failed = 0
lock = threading.Lock()
start_time = time.time()

# --- UTIL ---
def run(cmd):
    return subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

# --- HANDLERS ---
def handle_image(file):
    ext = file.suffix.lower()
    tmp = file.with_suffix(file.suffix + ".tmp")

    try:
        if ext in [".jpg", ".jpeg"]:
            ok = run(f'jpegtran -copy none -optimize "{file}" > "{tmp}"')
            if not ok:
                ok = run(f'convert "{file}" -strip "{tmp}"')
        elif ext == ".png":
            ok = run(f'convert "{file}" -strip "{tmp}"')
        else:
            ok = run(f'mogrify -strip "{file}"')
            return ok

        if ok and tmp.exists():
            tmp.replace(file)
        return ok

    finally:
        if tmp.exists():
            tmp.unlink()


def handle_video(file):
    tmp = file.with_suffix(file.suffix + ".tmp")
    try:
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


def handle_doc(file):
    return run(f'exiftool -all= -overwrite_original "{file}"')


def fallback(file):
    return run(f'exiftool -all= -overwrite_original "{file}"')


# --- ROUTER ---
def process_file(file):
    global processed, failed

    if file.suffix.lower() in SKIP_EXT:
        return

    try:
        if file.suffix.lower() in [".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".gif"]:
            ok = handle_image(file)
        elif file.suffix.lower() in [".mp4", ".mkv", ".mov", ".avi", ".webm", ".mp3", ".wav"]:
            ok = handle_video(file)
        elif file.suffix.lower() == ".pdf":
            ok = handle_pdf(file)
        elif file.suffix.lower() in [".docx", ".xlsx", ".pptx"]:
            ok = handle_doc(file)
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


# --- WORKER ---
def worker(q):
    while True:
        try:
            file = q.get_nowait()
        except queue.Empty:
            return
        process_file(file)
        q.task_done()


# --- PROGRESS ---
def progress(total):
    while True:
        time.sleep(1)
        elapsed = time.time() - start_time
        rate = processed / elapsed if elapsed > 0 else 0
        print(f"\rProcessed: {processed}/{total} | Failed: {failed} | {rate:.2f} f/s", end="")


# --- MAIN ---
def run_clean(path, recursive=True):
    files = list(Path(path).rglob("*") if recursive else Path(path).glob("*"))
    files = [f for f in files if f.is_file()]

    q = queue.Queue()
    for f in files:
        q.put(f)

    threading.Thread(target=progress, args=(len(files),), daemon=True).start()

    threads = []
    for _ in range(THREADS):
        t = threading.Thread(target=worker, args=(q,))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    print("\nDONE")
    print(f"Processed: {processed}, Failed: {failed}")


if __name__ == "__main__":
    target = input("Directory: ").strip()
    if not os.path.isdir(target):
        print("Invalid directory")
    else:
        run_clean(target)
