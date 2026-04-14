#!/usr/bin/env python3
# Script Name: music-converter-max.py
# ID: SCR-ID-20260317130940-VMVGXD6D3V
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: music-converter-max

import os
import subprocess
import signal
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing

# Graceful shutdown
stop_requested = False
def handle_exit(signum, frame):
    global stop_requested
    stop_requested = True
    print("\nShutdown requested... Finishing current task.")

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)

def convert_single(mp4_path, mp3_path):
    try:
        print(f"Converting: {mp4_path} -> {mp3_path}")
        subprocess.run([
            "ffmpeg",
            "-i", mp4_path,
            "-vn",
            "-ab", "192k",
            "-ar", "44100",
            "-y",
            mp3_path
        ], check=True)

        os.remove(mp4_path)
        print(f"Deleted original: {mp4_path}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to convert {mp4_path}: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")

def gather_files(directory):
    tasks = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(".mp4"):
                mp4_path = os.path.join(root, file)
                mp3_path = os.path.splitext(mp4_path)[0] + ".mp3"
                tasks.append((mp4_path, mp3_path))
    return tasks

def convert_mp4_to_mp3_parallel(directory):
    tasks = gather_files(directory)
    if not tasks:
        print("No .mp4 files found.")
        return

    max_workers = multiprocessing.cpu_count()
    print(f"Using {max_workers} threads for conversion...")

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for mp4_path, mp3_path in tasks:
            if stop_requested:
                print("Conversion interrupted before queuing all tasks.")
                break
            futures.append(executor.submit(convert_single, mp4_path, mp3_path))

        try:
            for future in as_completed(futures):
                if stop_requested:
                    print("Cancellation requested. Waiting for running threads to finish.")
                    break
        except KeyboardInterrupt:
            print("Keyboard interrupt received, exiting...")

def main():
    directory = input("Enter the root directory for conversion: ").strip('"')
    if not os.path.isdir(directory):
        print(f"Invalid directory: {directory}")
        return

    print("Press Ctrl+C to stop at any time.\n")
    convert_mp4_to_mp3_parallel(directory)
    print("All done!" if not stop_requested else "Stopped before completion.")

if __name__ == "__main__":
    main()
