#!/usr/bin/env python3
# Script Name: banshee25.py
# ID: SCR-ID-20260325230433-4FYLBDHAGT
# Assigned with: n/a standalone-version
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: banshee25

import os
import sys
import json
import csv
import time
import queue
import signal
import shutil
import threading
import subprocess
from pathlib import Path
from datetime import datetime

# =========================================================
# 🔧 EDIT YOUR DEFAULT DIRECTORIES HERE
# =========================================================
DEFAULT_DIRS = {
    "brave_export_dir":   "/mnt/c/Users/tyler/Documents/brave/",
    "default_music_dir":  "/mnt/e/Windows/Music/clm/y-hold/",
    "default_videos_dir": "/mnt/e/Windows/Music/clm/Videos/y-hold/",
    "music_artist_dir":   "/mnt/e/Windows/Music/clm/Active-org/",
    "video_artist_dir":   "/mnt/e/Windows/Music/clm/Videos/Active-org/",
    "cookies_dir":        "/mnt/c/scr/keys/cookies/"
}

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_DIR = SCRIPT_DIR / "logs"
INFO_JSON_DIR = LOG_DIR / "info_json"
CSV_DIR = LOG_DIR / "downloads_csv"

for d in [LOG_DIR, INFO_JSON_DIR, CSV_DIR]:
    d.mkdir(parents=True, exist_ok=True)

CANCELLED = False
ACTIVE_PROCS = []

# =========================================================
# 🧠 FileOps (embedded)
# =========================================================
def detect_win_user():
    for key in ["WINUSER", "WIN_USER"]:
        val = os.environ.get(key, "").strip()
        if val:
            return val

    try:
        out = subprocess.check_output(
            ["cmd.exe", "/c", "echo %USERNAME%"], text=True
        ).strip()
        if out and "%USERNAME%" not in out:
            return out
    except:
        pass

    users = Path("/mnt/c/Users")
    if users.exists():
        for p in users.iterdir():
            if (p / "Documents").exists():
                return p.name

    return os.environ.get("USER", "user")


def build_dirs():
    win_user = detect_win_user()

    defaults = {
        k: v.replace("{WIN_USER}", win_user)
        for k, v in DEFAULT_DIRS.items()
    }

    override_path = SCRIPT_DIR / "fileops.local.json"

    if override_path.exists():
        try:
            overrides = json.loads(override_path.read_text())
            overrides = {
                k: v.replace("{WIN_USER}", win_user)
                for k, v in overrides.items()
            }
            defaults.update(overrides)
        except:
            pass

    return defaults


# =========================================================
# Utils
# =========================================================
def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_DIR / "script.log", "a") as f:
        f.write(f"[{ts}] {msg}\n")


def ensure_dependencies():
    if shutil.which("yt-dlp") is None:
        print("Installing yt-dlp...")
        subprocess.run(["sudo", "apt", "install", "-y", "yt-dlp"])
        os.execv(sys.executable, [sys.executable] + sys.argv)


def signal_handler(sig, frame):
    global CANCELLED
    CANCELLED = True
    print("\n🛑 Cancelling...")

    for p in ACTIVE_PROCS:
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGTERM)
        except:
            pass


signal.signal(signal.SIGINT, signal_handler)


# =========================================================
# Download Core
# =========================================================
def build_cmd(url, out_dir, media_type, cookies=None):
    cookies_arg = f"--cookies '{cookies}'" if cookies else ""

    if media_type == "audio":
        return f"yt-dlp {cookies_arg} -x --audio-format mp3 --write-info-json -o '{out_dir}/%(title).240s.%(ext)s' '{url}'"
    else:
        return f"yt-dlp {cookies_arg} -S 'res,ext:mp4:m4a' --recode mp4 --write-info-json -o '{out_dir}/%(title).240s.%(ext)s' '{url}'"


def run_cmd(cmd):
    proc = subprocess.Popen(cmd, shell=True, preexec_fn=os.setsid)
    ACTIVE_PROCS.append(proc)
    proc.wait()
    ACTIVE_PROCS.remove(proc)


def worker(q, out_dir, media_type, cookies):
    while not q.empty() and not CANCELLED:
        try:
            url = q.get_nowait()
        except:
            return

        print(f"🔗 {url}")
        log(f"Downloading: {url}")

        run_cmd(build_cmd(url, out_dir, media_type, cookies))


def download(urls, out_dir, media_type, threads, cookies=None):
    start = time.time()

    q = queue.Queue()
    for u in urls:
        q.put(u)

    threads_list = []
    for _ in range(threads):
        t = threading.Thread(target=worker, args=(q, out_dir, media_type, cookies))
        t.start()
        threads_list.append(t)

    for t in threads_list:
        t.join()

    move_json(out_dir)

    print(f"⏱️ Done in {round(time.time() - start, 2)}s")


# =========================================================
# File Handling
# =========================================================
def move_json(base):
    for f in Path(base).glob("*.info.json"):
        shutil.move(str(f), INFO_JSON_DIR)


def organize_by_artist(base):
    for f in INFO_JSON_DIR.glob("*.info.json"):
        try:
            data = json.load(open(f))
            artist = data.get("artist") or data.get("uploader") or "Unknown"

            artist_dir = Path(base) / artist
            artist_dir.mkdir(exist_ok=True)

            name = f.stem.replace(".info", "")

            for ext in ["mp3", "mp4", "m4a", "webm"]:
                media = Path(base) / f"{name}.{ext}"
                if media.exists():
                    shutil.move(media, artist_dir)

        except Exception as e:
            log(f"Organize error: {e}")


# =========================================================
# URL Handling
# =========================================================
def normalize(line):
    s = line.strip().strip('"').strip("'")
    return s.split()[0] if s.startswith("http") else None


def load_file(path):
    urls = []
    ext = Path(path).suffix

    with open(path) as f:
        if ext == ".csv":
            reader = csv.reader(f)
            for row in reader:
                if row:
                    u = normalize(row[0])
                    if u:
                        urls.append(u)
        else:
            for line in f:
                u = normalize(line)
                if u:
                    urls.append(u)

    return list(set(urls))


# =========================================================
# CLI
# =========================================================
def main():
    ensure_dependencies()
    dirs = build_dirs()

    print("🎵 1: Video\n🎧 2: Audio")
    media = "audio" if input("> ") == "2" else "video"

    print("\n📥 Input Mode:\n1: Manual\n2: File\n3: Brave default")
    mode = input("> ")

    if mode == "1":
        urls = []
        while True:
            line = input("> ")
            if not line:
                break
            u = normalize(line)
            if u:
                urls.append(u)

    elif mode == "2":
        path = input("File path: ")
        urls = load_file(path)

    else:
        path = Path(dirs["brave_export_dir"]) / "exported-tabs.txt"
        urls = load_file(path) if path.exists() else []

    if not urls:
        print("❌ No URLs")
        return

    print("\n📂 Output:")
    print("1: Music\n2: Video\n3: Custom")

    choice = input("> ")

    if choice == "1":
        out_dir = dirs["default_music_dir"]
    elif choice == "2":
        out_dir = dirs["default_videos_dir"]
    else:
        out_dir = input("Path: ")

    Path(out_dir).mkdir(parents=True, exist_ok=True)

    threads = os.cpu_count()
    download(urls, out_dir, media, threads)

    if input("\n🎨 Organize by artist? (y/n): ").lower() == "y":
        organize_by_artist(out_dir)

    print("\n👋 Done")


if __name__ == "__main__":
    main()
