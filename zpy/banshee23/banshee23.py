#!/usr/bin/env python3
# Script Name: yt-downloader-127.25.py
# ID: SCR-ID-20260317131047-H97K9BCQ83
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: yt-downloader-127.25 or banshee23

import os
import re
import sys
import csv
import json
import time
import shutil
import signal
import subprocess
from dataclasses import dataclass
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

# =======================================================================
# YT-DLP - Newest Downloader with Single Download per moment (Python)
# =======================================================================
# Version: 127.25-py (fileops.py required)
# Created By: Tyler Lee Jensen
# =======================================================================
print("WELCOME TO THE DARKSIDE!")
# -----------------------------------------------------------------------
# Require fileops.py next to script (like Ruby require_relative)
# -----------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    import fileops  # must exist next to this script
except Exception as e:
    print(f"❌ Missing fileops.py next to this script.\n   {e}")
    sys.exit(1)

if not hasattr(fileops, "build_dirs"):
    print("❌ fileops.py is missing build_dirs(win_user).")
    sys.exit(1)

# -----------------------------------------------------------------------
# Setup + Paths (next to script)
# -----------------------------------------------------------------------
LOG_DIR = SCRIPT_DIR / "logs"
INFO_JSON_DIR = LOG_DIR / "info_json"
CSV_DIR = LOG_DIR / "downloads_csv"
TMP_DIR = SCRIPT_DIR / "tmp"

for d in (LOG_DIR, INFO_JSON_DIR, CSV_DIR, TMP_DIR):
    d.mkdir(parents=True, exist_ok=True)

SCRIPT_LOG = LOG_DIR / "script.log"

# -----------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------
class Color:
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    RESET = "\033[0m"

# -----------------------------------------------------------------------
# Exceptions
# -----------------------------------------------------------------------
class UserCancel(Exception):
    pass

class UserBack(Exception):
    pass

# -----------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------
def log(msg: str, color: str | None = None):
    out = f"{color or ''}{msg}{Color.RESET if color else ''}"
    print(out)
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with SCRIPT_LOG.open("a", encoding="utf-8") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass

# -----------------------------------------------------------------------
# Ctrl+C trap
# -----------------------------------------------------------------------
def setup_traps():
    def handler(sig, frame):
        raise UserCancel()
    signal.signal(signal.SIGINT, handler)

# -----------------------------------------------------------------------
# UI helpers
# -----------------------------------------------------------------------
def script_name() -> str:
    try:
        return Path(sys.argv[0]).name
    except Exception:
        return Path(__file__).name

def hint_line() -> str:
    return "Type 'back' to go back, Ctrl+C to cancel."

def print_start_banner():
    print(f"{Color.CYAN}{script_name()} — {hint_line()}{Color.RESET}")

def ask(prompt: str, allow_back: bool = True, allow_empty: bool = False) -> str:
    while True:
        try:
            s = input(prompt)
        except EOFError:
            raise UserCancel()
        s = s.strip()

        if allow_back and s.lower() == "back":
            raise UserBack()

        if (not allow_empty) and s == "":
            log("⚠️ Empty input.", Color.YELLOW)
            continue

        return s

# -----------------------------------------------------------------------
# Windows username detection (WSL-friendly)
# -----------------------------------------------------------------------
def _run_cmd_capture(cmd: list[str]) -> str:
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        return (p.stdout or "").strip().replace("\r", "")
    except Exception:
        return ""

def windows_username() -> str | None:
    out = _run_cmd_capture(["cmd.exe", "/c", "echo", "%USERNAME%"])
    if out and "%USERNAME%" not in out:
        return out

    out = _run_cmd_capture(["powershell.exe", "-NoProfile", "-Command", "$env:USERNAME"])
    if out:
        return out

    users_dir = Path("/mnt/c/Users")
    if users_dir.is_dir():
        blacklist = {"All Users", "Default", "Default User", "Public", "desktop.ini"}
        candidates = [p for p in users_dir.iterdir() if p.is_dir() and p.name not in blacklist]

        scored: list[tuple[str, int]] = []
        for p in candidates:
            score = 0
            if (p / "Documents").is_dir(): score += 3
            if (p / "Downloads").is_dir(): score += 3
            if (p / "Desktop").is_dir(): score += 2
            if (p / "Music").is_dir(): score += 1
            if (p / "Videos").is_dir(): score += 1
            scored.append((p.name, score))

        scored.sort(key=lambda t: -t[1])
        if scored and scored[0][1] > 0:
            return scored[0][0]

    return None

# -----------------------------------------------------------------------
# Directory safety
# -----------------------------------------------------------------------
def ensure_dir(path: Path, label: str = "directory") -> bool:
    try:
        path.mkdir(parents=True, exist_ok=True)
        return True
    except PermissionError as e:
        log(f"❌ Can't create {label}: {path}", Color.RED)
        log(f"   {type(e).__name__}: {e}", Color.YELLOW)
        return False

def ensure_writable_dir(path: Path) -> Path:
    try:
        path.mkdir(parents=True, exist_ok=True)
        testfile = path / f".writetest_{os.getpid()}"
        testfile.write_text("ok", encoding="utf-8")
        try:
            testfile.unlink()
        except Exception:
            pass
        return path
    except PermissionError as e:
        log(f"❌ Can't write to: {path}", Color.RED)
        log(f"   {type(e).__name__}: {e}", Color.YELLOW)
        log("➡️ Pick another folder (under /mnt/c/Users/<you>/).", Color.CYAN)
        new_path = Path(ask("Enter a new output directory: ", allow_back=True, allow_empty=False))
        return ensure_writable_dir(new_path)

# -----------------------------------------------------------------------
# yt-dlp helpers
# -----------------------------------------------------------------------
def yt_dlp_available() -> bool:
    return shutil.which("yt-dlp") is not None

def fetch_title(url: str) -> str:
    try:
        p = subprocess.run(
            ["yt-dlp", "--no-warnings", "--no-playlist", "--print", "%(title)s", url],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        title = (p.stdout or "").strip()
        return title if title else "Unknown title"
    except Exception:
        return "Unknown title"

def build_cmd(url: str, output_dir: Path, media_type: str) -> list[str]:
    outtmpl = str(output_dir / "%(title).240s.%(ext)s")
    if media_type == "audio":
        return [
            "yt-dlp",
            "-x", "--audio-format", "mp3",
            "--write-info-json",
            "-o", outtmpl,
            url,
        ]
    else:
        return [
            "yt-dlp",
            "-S", "res,ext:mp4:m4a",
            "--recode", "mp4",
            "--write-info-json",
            "-o", outtmpl,
            url,
        ]

def run_download(cmd: list[str]) -> bool:
    try:
        p = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return p.returncode == 0
    except Exception:
        return False

# -----------------------------------------------------------------------
# Organize by Artist
# -----------------------------------------------------------------------
MEDIA_EXTS = ("mp3", "mp4", "m4a", "webm", "flac", "wav")

def move_info_json_files(base_dir: Path):
    for f in base_dir.glob("*.info.json"):
        try:
            shutil.move(str(f), str(INFO_JSON_DIR / f.name))
        except Exception:
            pass

def safe_dir_name(name: str) -> str:
    name = (name or "").strip()
    name = re.sub(r'[\/\\:\*\?"<>\|]', "_", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name[:120] if len(name) > 120 else name

def organize_by_artist(base_dir: Path):
    info_files = sorted(INFO_JSON_DIR.glob("*.info.json"))
    if not info_files:
        log("❌ No info.json files found.", Color.RED)
        return

    for info_file in info_files:
        try:
            data = json.loads(info_file.read_text(encoding="utf-8", errors="replace"))
            artist = data.get("artist") or data.get("uploader") or "Unknown"
            artist = safe_dir_name(str(artist))

            artist_dir = base_dir / artist
            artist_dir.mkdir(parents=True, exist_ok=True)

            base_name = info_file.name[:-len(".info.json")]

            moved_any = False
            deleted_dupes = 0

            for ext in MEDIA_EXTS:
                src = base_dir / f"{base_name}.{ext}"
                if not src.exists():
                    continue

                dest = artist_dir / src.name
                if dest.exists():
                    try:
                        src.unlink()
                        deleted_dupes += 1
                        log(f"🧹 Duplicate name found — kept existing, deleted new: {src.name}", Color.YELLOW)
                    except Exception:
                        log(f"⚠️ Could not delete duplicate: {src.name}", Color.YELLOW)
                    continue

                try:
                    shutil.move(str(src), str(dest))
                    moved_any = True
                except Exception as e:
                    log(f"❌ Move failed: {src.name} -> {artist_dir} ({e})", Color.RED)

            if moved_any:
                log(f"📁 Organized: {base_name} → {artist_dir}", Color.GREEN)
            elif deleted_dupes > 0:
                log(f"✅ Duplicates removed (by name): {base_name}", Color.GREEN)
            else:
                log(f"⚠️ No media found for: {base_name}", Color.YELLOW)

        except Exception as e:
            log(f"❌ Error processing {info_file.name}: {e}", Color.RED)

# -----------------------------------------------------------------------
# URL Helpers
# -----------------------------------------------------------------------
def read_urls_from_file(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    urls = []
    for l in lines:
        s = l.strip()
        if not s or s.startswith("#"):
            continue
        urls.append(s)
    return urls

def save_urls_to_csv(urls: list[str]):
    csv_path = CSV_DIR / f"urls_{datetime.now().strftime('%Y%m%d%H%M%S')}.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        for u in urls:
            w.writerow([u])
    log(f"Saved URL list to {csv_path}", Color.YELLOW)

# -----------------------------------------------------------------------
# Job model
# -----------------------------------------------------------------------
@dataclass
class Job:
    idx: int
    total: int
    url: str
    title: str

# -----------------------------------------------------------------------
# Main Program (state machine with back)
# -----------------------------------------------------------------------
def main():
    setup_traps()
    print_start_banner()

    if not yt_dlp_available():
        log("❌ yt-dlp not found. Install it first (e.g., sudo apt install yt-dlp) or ensure it’s in PATH.", Color.RED)
        return

    win_user = windows_username()
    if not win_user:
        log("⚠️ Could not auto-detect Windows username.", Color.YELLOW)
        win_user = ask("Enter your Windows username (folder under /mnt/c/Users): ", allow_back=False)

    # Use YOUR fileops.py config
    dirs = fileops.build_dirs(win_user)
    brave_dir = Path(dirs["brave_export_dir"])
    default_music = Path(dirs["default_music_dir"])
    default_videos = Path(dirs["default_videos_dir"])
    music_artist = Path(dirs["music_artist_dir"])
    video_artist = Path(dirs["video_artist_dir"])

    ensure_dir(brave_dir, label="Brave export folder")

    media_type: str | None = None
    urls: list[str] = []
    output_choice: str | None = None
    output_dir: Path | None = None
    mode_choice: str | None = None

    history: list[str] = []
    state = "media_type"

    while True:
        try:
            if state == "media_type":
                print("\n🎵 Download type?")
                print("1: Video")
                print("2: Audio")
                c = ask("> ", allow_back=True)
                media_type = "audio" if c == "2" else "video"
                history.append(state)
                state = "url_source"

            elif state == "url_source":
                print("\n📥 How would you like to input URLs?")
                print("1: Manually input URLs")
                print("2: Load from a file (provide path)")
                print("3: Use default exported-tabs.txt")
                print(f"4: Choose from directory: {brave_dir}")
                choice = ask("> ", allow_back=True)

                urls = []

                if choice == "1":
                    print("\n🎯 Enter URLs (blank line to finish).")
                    print(f"{Color.CYAN}Type ':back' to go back (URL entry only).{Color.RESET}")
                    while True:
                        try:
                            line = input()
                        except EOFError:
                            raise UserCancel()
                        line = line.strip()
                        if line.lower() == ":back":
                            raise UserBack()
                        if line == "":
                            break
                        urls.append(line)

                elif choice == "2":
                    p = Path(ask("Enter full file path: ", allow_back=True))
                    if p.exists():
                        urls = read_urls_from_file(p)
                    else:
                        log(f"❌ File not found: {p}", Color.RED)
                        continue

                elif choice == "3":
                    default_file = brave_dir / "exported-tabs.txt"
                    if default_file.exists():
                        urls = read_urls_from_file(default_file)
                    else:
                        log(f"❌ Default file not found: {default_file}", Color.RED)
                        log("➡️ Put exported-tabs.txt there, or pick option 2/4.", Color.CYAN)
                        continue

                elif choice == "4":
                    ensure_dir(brave_dir, label="Brave export folder")
                    txt_files = sorted(brave_dir.glob("*.txt"))
                    if not txt_files:
                        log(f"❌ No .txt files found in: {brave_dir}", Color.RED)
                        log("➡️ Drop your exported tabs .txt files in there.", Color.CYAN)
                        continue

                    print("\n📄 Files:")
                    for i, f in enumerate(txt_files, start=1):
                        print(f"{i}: {f.name}")

                    idx = int(ask("Choose a file #: ", allow_back=True)) - 1
                    if 0 <= idx < len(txt_files):
                        urls = read_urls_from_file(txt_files[idx])
                    else:
                        log("❌ Invalid selection.", Color.RED)
                        continue

                else:
                    log("❌ Invalid choice.", Color.RED)
                    continue

                if not urls:
                    log("⚠️ No URLs found.", Color.YELLOW)
                    continue

                save_urls_to_csv(urls)
                history.append(state)
                state = "output_dir"

            elif state == "output_dir":
                print("\n📂 Choose output directory:")
                print(f"1: Default Music: {default_music}")
                print(f"2: Default Videos: {default_videos}")
                print("3: Enter custom path")
                print(f"4: {music_artist} + organize by artist")
                print(f"5: {video_artist} + organize by artist")
                output_choice = ask("> ", allow_back=True)

                if output_choice == "1":
                    output_dir = default_music
                elif output_choice == "2":
                    output_dir = default_videos
                elif output_choice == "3":
                    output_dir = Path(ask("Enter custom output directory: ", allow_back=True))
                elif output_choice == "4":
                    output_dir = music_artist
                elif output_choice == "5":
                    output_dir = video_artist
                else:
                    output_dir = default_music

                if not str(output_dir).strip():
                    log("❌ Output directory is empty.", Color.RED)
                    continue

                output_dir = ensure_writable_dir(output_dir)
                log(f"✅ Saving to: {output_dir}", Color.GREEN)

                history.append(state)
                state = "mode"

            elif state == "mode":
                print("\n🧠 Select download mode:")
                print("1: Multi-threaded (fastest)")
                print("2: Sequential (one at a time, automatic)")
                print("3: One-by-one with confirmation after each download")
                mode_choice = ask("> ", allow_back=True)

                if mode_choice not in ("1", "2", "3"):
                    log("❌ Invalid mode choice.", Color.RED)
                    continue

                history.append(state)
                state = "run"

            elif state == "run":
                assert media_type is not None
                assert output_dir is not None
                assert mode_choice is not None
                assert output_choice is not None

                total = len(urls)
                start_time = time.time()

                if mode_choice == "1":
                    num_threads = max(os.cpu_count() or 1, 1)
                    log(f"🧵 Threads: {num_threads}", Color.CYAN)

                    jobs: list[Job] = []
                    for i, url in enumerate(urls, start=1):
                        title = fetch_title(url)
                        progress = f"[{i}/{total}]"
                        log(f"🔗 {progress} Preparing:", Color.CYAN)
                        log(f"   🌐 {url}", Color.CYAN)
                        log(f"   🏷️  {title}", Color.CYAN)
                        jobs.append(Job(i, total, url, title))

                    def worker(job: Job) -> tuple[int, bool]:
                        cmd = build_cmd(job.url, output_dir, media_type)
                        ok = run_download(cmd)
                        return (job.idx, ok)

                    with ThreadPoolExecutor(max_workers=num_threads) as ex:
                        futures = [ex.submit(worker, j) for j in jobs]
                        for fut in as_completed(futures):
                            idx, ok = fut.result()
                            status = "✅ Completed" if ok else "❌ Failed"
                            log(f"{status} [{idx}/{total}]", Color.GREEN if ok else Color.RED)

                else:
                    completed = 0
                    for url in urls:
                        completed += 1
                        progress = f"[{completed}/{total}]"
                        title = fetch_title(url)
                        log(f"🔗 {progress} Preparing:", Color.CYAN)
                        log(f"   🌐 {url}", Color.CYAN)
                        log(f"   🏷️  {title}", Color.CYAN)

                        if mode_choice == "3":
                            resp = ask(
                                "Press Enter to download, type 'skip' to skip, or 'back' to go back: ",
                                allow_back=False,
                                allow_empty=True,
                            ).strip().lower()
                            if resp == "back":
                                raise UserBack()
                            if resp == "skip":
                                log(f"⏩ Skipped: {url}", Color.YELLOW)
                                continue

                        cmd = build_cmd(url, output_dir, media_type)
                        ok = run_download(cmd)
                        log(f"{'✅ Completed' if ok else '❌ Failed'} {progress}", Color.GREEN if ok else Color.RED)

                move_info_json_files(output_dir)
                if output_choice in ("4", "5"):
                    organize_by_artist(output_dir)

                duration = round(time.time() - start_time, 2)
                log(f"⏱️ Finished in {duration}s", Color.CYAN)
                break

            else:
                log(f"❌ Internal state error: {state}", Color.RED)
                break

        except UserBack:
            if not history:
                log("↩️ Already at the first step.", Color.YELLOW)
                state = "media_type"
            else:
                state = history.pop()

        except UserCancel:
            log("\n🛑 Cancelled (Ctrl+C). Exiting safely.", Color.YELLOW)
            break

if __name__ == "__main__":
    main()
