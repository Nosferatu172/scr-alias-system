#!/usr/bin/env python3
# Script Name: batch_ops.py
# ID: SCR-ID-20260328145925-O41106YB7S
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: batch_ops

import os
import csv
import time
import shutil
from pathlib import Path
from utils import prompt_choice, log_message
from url_ops import load_urls_from_file
from downloader import download_media, organize_by_artist_folder, CANCELLED


# -------------------------
# Save URLs to CSV
# -------------------------
def save_urls_to_csv(urls, csv_dir):
    csv_dir = Path(csv_dir)
    csv_dir.mkdir(parents=True, exist_ok=True)

    filename = f"urls_{time.strftime('%Y%m%d%H%M%S')}.csv"
    path = csv_dir / filename

    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        for u in urls:
            writer.writerow([u])

    return str(path)


# -------------------------
# Completed Directory
# -------------------------
def completed_dir_for(base_dir):
    return Path(base_dir).parent / "completed"


def move_to_completed(input_file, base_dir):
    if not input_file or not os.path.exists(input_file):
        return None

    dest_dir = completed_dir_for(base_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    base = os.path.basename(input_file)
    dest = dest_dir / base

    if dest.exists():
        stamp = time.strftime("%Y%m%d%H%M%S")
        name = Path(base).stem
        ext = Path(base).suffix
        dest = dest_dir / f"{name}_{stamp}{ext}"

    shutil.move(input_file, dest)
    return str(dest)


# -------------------------
# Batch File Discovery
# -------------------------
def batch_files_in_dir(directory, exts=(".txt", ".csv")):
    if not os.path.isdir(directory):
        return []

    files = [
        os.path.join(directory, f)
        for f in os.listdir(directory)
        if Path(f).suffix.lower() in exts and not f.startswith(".")
    ]

    return sorted(files)


# -------------------------
# Selection Parser
# -------------------------
def parse_selection_input(text, max_items):
    s = text.strip().lower()

    if s in ["a", "all"]:
        return "all"
    if s == "b":
        return "back"
    if s == "e":
        return "exit"
    if not s:
        return []

    picks = []

    for token in s.split(","):
        token = token.strip()

        if "-" in token:
            try:
                a, b = map(int, token.split("-", 1))
                lo, hi = min(a, b), max(a, b)
                for i in range(lo, hi + 1):
                    if 1 <= i <= max_items:
                        picks.append(i)
            except:
                continue
        else:
            try:
                n = int(token)
                if 1 <= n <= max_items:
                    picks.append(n)
            except:
                continue

    return sorted(set(picks))


# -------------------------
# File Selection UI
# -------------------------
def select_files_from_list(files):
    if not files:
        return []

    print("\n📄 Files found:")
    for i, f in enumerate(files, 1):
        print(f"  {i}: {os.path.basename(f)}")

    print("\n✅ Choose files to run:")
    print("   - a / all")
    print("   - 1,5,10")
    print("   - 2-8")
    print("   - 1-3,7,10")

    ans = prompt_choice("Selection (a/all, b=back, e=exit):")

    if ans in ["exit", "back"]:
        return ans

    parsed = parse_selection_input(ans, len(files))

    if parsed == "all":
        return files

    if not parsed:
        print("⚠️ Nothing selected.")
        return []

    return [files[i - 1] for i in parsed]


# -------------------------
# Batch Runner
# -------------------------
def run_batch_mode(dirs, data):
    brave_dir = dirs["brave_export_dir"]
    csv_dir = Path(__file__).resolve().parent / "logs" / "downloads_csv"

    files = batch_files_in_dir(brave_dir)

    if not files:
        print(f"⚠️ No .txt/.csv files found in: {brave_dir}")
        return

    selected = select_files_from_list(files)

    if selected in ["exit", "back"]:
        return

    if not selected:
        print("⚠️ No files selected.")
        return

    completed_dir = completed_dir_for(brave_dir)
    completed_dir.mkdir(parents=True, exist_ok=True)

    print("\n📦 Batch mode:")
    print(f"   Input dir:      {brave_dir}")
    print(f"   Completed dir: {completed_dir}")
    print(f"   Files selected: {len(selected)}")

    for idx, file_path in enumerate(selected, 1):

        if CANCELLED:
            break

        print(f"\n▶️ ({idx}/{len(selected)}) Processing: {os.path.basename(file_path)}")

        urls = load_urls_from_file(file_path)
        urls = list(set(u.strip() for u in urls if u and u.startswith("http")))

        if not urls:
            print("⚠️ No URLs in file, moving anyway.")
            moved = move_to_completed(file_path, brave_dir)
            if moved:
                print(f"📁 Moved to: {moved}")
            continue

        csv_out = save_urls_to_csv(urls, csv_dir)
        print(f"🧾 Saved URL list to: {csv_out}")

        print("\n🚀 Starting downloads… (Ctrl+C to cancel)")

        download_media(
            urls,
            data["output_dir"],
            data["media_type"],
            data["threads_count"],
            data["cookies_file"]
        )

        if CANCELLED:
            break

        if data["output_choice"] in ["4", "5"]:
            print("\n🎨 Organizing by creator/uploader...")
            info_dir = Path(__file__).resolve().parent / "logs" / "info_json"
            organize_by_artist_folder(data["output_dir"], info_dir)

        moved = move_to_completed(file_path, brave_dir)

        if moved:
            print(f"✅ Completed + moved input file to: {moved}")
            log_message(f"Completed file moved: {file_path} -> {moved}")

    if not CANCELLED:
        print("\n✅ Batch run finished.")
