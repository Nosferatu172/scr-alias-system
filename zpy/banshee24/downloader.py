#!/usr/bin/env python3
# Script Name: downloader.py
# ID: SCR-ID-20260328145936-RJI82JXXN9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: downloader

import os
import json
import time
import queue
import signal
import shutil
import threading
import subprocess
from pathlib import Path
from utils import log_message

# -------------------------
# Globals (match Ruby behavior)
# -------------------------
CANCELLED = False
ACTIVE_PROCS = []


# -------------------------
# Signal Handler (Ctrl+C)
# -------------------------
def handle_sigint(sig, frame):
    global CANCELLED
    CANCELLED = True

    print("\n🛑 Ctrl+C caught — cancelling…")

    for proc in list(ACTIVE_PROCS):
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except:
            pass


signal.signal(signal.SIGINT, handle_sigint)


# -------------------------
# Command Builder
# -------------------------
def build_download_cmd(url, output_dir, media_type, cookies_file=None):
    cookies_arg = ""

    if cookies_file and str(cookies_file).strip():
        cookies_arg = f"--cookies '{cookies_file}'"

    if media_type == "audio":
        return (
            f"yt-dlp {cookies_arg} -x --audio-format mp3 "
            f"--write-info-json "
            f"-o '{output_dir}/%(title).240s.%(ext)s' '{url}'"
        )
    else:
        return (
            f"yt-dlp {cookies_arg} "
            f"-S 'res,ext:mp4:m4a' --recode mp4 "
            f"--write-info-json "
            f"-o '{output_dir}/%(title).240s.%(ext)s' '{url}'"
        )


# -------------------------
# Run Command (with process group)
# -------------------------
def run_cmd(cmd):
    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            preexec_fn=os.setsid  # creates new process group
        )

        ACTIVE_PROCS.append(proc)
        proc.wait()

    except Exception as e:
        log_message(f"Command failed: {cmd} | {e}")

    finally:
        try:
            if proc in ACTIVE_PROCS:
                ACTIVE_PROCS.remove(proc)
        except:
            pass


# -------------------------
# Worker Thread
# -------------------------
def worker(q, output_dir, media_type, cookies_file):
    global CANCELLED

    while not q.empty() and not CANCELLED:
        try:
            url = q.get_nowait()
        except queue.Empty:
            return

        if CANCELLED:
            break

        print(f"🔗 Downloading: {url}")
        log_message(f"Downloading: {url}")

        cmd = build_download_cmd(url, output_dir, media_type, cookies_file)
        run_cmd(cmd)


# -------------------------
# Move JSON files
# -------------------------
def move_json_files(base_dir, info_json_dir):
    for f in Path(base_dir).glob("*.info.json"):
        try:
            shutil.move(str(f), info_json_dir)
        except:
            pass


# -------------------------
# Organize by Artist
# -------------------------
def organize_by_artist_folder(base_dir, info_json_dir):
    info_files = list(Path(info_json_dir).glob("*.info.json"))

    if not info_files:
        print("❌ No info.json files found.")
        return

    for info_path in info_files:
        if CANCELLED:
            break

        try:
            with open(info_path, "r", encoding="utf-8") as f:
                info = json.load(f)

            artist = info.get("artist") or info.get("uploader") or "Unknown"
            artist_dir = Path(base_dir) / artist
            artist_dir.mkdir(parents=True, exist_ok=True)

            base_name = info_path.stem.replace(".info", "")

            for ext in ["mp3", "mp4", "m4a", "webm", "flac", "wav"]:
                media_file = Path(base_dir) / f"{base_name}.{ext}"

                if media_file.exists():
                    shutil.move(str(media_file), artist_dir)

            log_message(f"Moved {base_name} to {artist_dir}")

        except Exception as e:
            print(f"❌ Failed {info_path}: {e}")
            log_message(f"Error processing {info_path}: {e}")


# -------------------------
# Download Manager
# -------------------------
def download_media(urls, output_dir, media_type, threads_count, cookies_file=None):
    global CANCELLED

    start = time.time()

    q = queue.Queue()

    for u in urls:
        q.put(u)

    threads = []
    for _ in range(threads_count):
        t = threading.Thread(
            target=worker,
            args=(q, output_dir, media_type, cookies_file)
        )
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    if not CANCELLED:
        info_json_dir = Path(__file__).resolve().parent / "logs" / "info_json"
        info_json_dir.mkdir(parents=True, exist_ok=True)

        move_json_files(output_dir, info_json_dir)

        duration = round(time.time() - start, 2)
        print(f"⏱️ Finished in {duration}s")
