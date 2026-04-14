#!/usr/bin/env python3
# Script Name: main.py
# ID: SCR-ID-20260325230259-9H8XIKAMMP
# Assigned with: Everything in zpy/yt/lib16/
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: banshee24

import os
from fileops import FileOps
from utils import prompt_choice, show_header
from url_ops import *
from downloader import *
from batch_ops import *

print("This is Banshee24, Welcome to the Darkside!")

def main():
    dirs = FileOps.build_dirs()

    data = {
        "media_type": None,
        "urls": [],
        "output_choice": None,
        "output_dir": None,
        "threads_count": os.cpu_count(),
        "cookies_enabled": False,
        "cookies_file": None,
        "input_file_used": None
    }

    state_stack = []
    state = "media_type"

    show_header()

    while True:

        # =========================
        # MEDIA TYPE
        # =========================
        if state == "media_type":
            ans = prompt_choice(
                "🎵 Download type? (1: Video, 2: Audio)  [b=back, e=exit]:"
            )

            if ans == "exit":
                break
            if ans == "back":
                state = state_stack.pop() if state_stack else "media_type"
                continue

            data["media_type"] = "audio" if ans == "2" else "video"

            state_stack.append("media_type")
            state = "cookies"

        # =========================
        # COOKIES
        # =========================
        elif state == "cookies":
            print("\n🍪 Cookies:")
            print(f"   cookies_dir => {dirs['cookies_dir']}")

            ans = prompt_choice(
                "Use cookies for yt-dlp? (1: No, 2: Yes)  [b=back, e=exit]:"
            )

            if ans == "exit":
                break
            if ans == "back":
                state = state_stack.pop()
                continue

            if ans == "2":
                cookies = select_cookie_file(dirs["cookies_dir"])

                if cookies == "exit":
                    break
                if cookies == "back":
                    continue

                data["cookies_enabled"] = True
                data["cookies_file"] = cookies
            else:
                data["cookies_enabled"] = False
                data["cookies_file"] = None

            state_stack.append("cookies")
            state = "url_input_mode"

        # =========================
        # URL INPUT MODE
        # =========================
        elif state == "url_input_mode":

            print("\n📥 How would you like to input URLs?  (b=back, e=exit)")
            print("1: Manually input URLs")
            print("2: Load from a file (path)")
            print("3: Use default exported-tabs.txt")
            print(f"4: Choose from directory: {dirs['brave_export_dir']}")
            print("5: Edit directory overrides")
            print("6: Batch process directory")

            ans = prompt_choice("Select option:")

            if ans == "exit":
                break
            if ans == "back":
                state = state_stack.pop()
                continue

            urls = []
            input_file = None

            if ans == "1":
                urls = input_urls_manually()

            elif ans == "2":
                pth = prompt_choice("Enter full file path:")
                if pth not in ["exit", "back"] and os.path.exists(pth):
                    urls = load_urls_from_file(pth)
                    input_file = pth

            elif ans == "3":
                default = os.path.join(dirs["brave_export_dir"], "exported-tabs.txt")
                if os.path.exists(default):
                    urls = load_urls_from_file(default)
                    input_file = default

            elif ans == "4":
                selected = select_file_from_directory(dirs["brave_export_dir"])
                if selected not in ["exit", "back"]:
                    urls = load_urls_from_file(selected)
                    input_file = selected

            elif ans == "5":
                print("🛠️ Override editor coming next phase")
                continue

            elif ans == "6":
                run_batch_mode(dirs, data)
                break

            urls = list(set(urls))

            if not urls:
                print("⚠️ No URLs found.")
                continue

            data["urls"] = urls
            data["input_file_used"] = input_file

            state_stack.append("url_input_mode")
            state = "output_dir"

        # =========================
        # OUTPUT DIR
        # =========================
        elif state == "output_dir":
            print("\n📂 Choose output directory:  (b=back, e=exit)")
            print(f"1: Default Music: {dirs['default_music_dir']}")
            print(f"2: Default Videos: {dirs['default_videos_dir']}")
            print("3: Custom path")

            ans = prompt_choice("Select option:")

            if ans == "exit":
                break
            if ans == "back":
                state = state_stack.pop()
                continue

            if ans == "1":
                out_dir = dirs["default_music_dir"]
            elif ans == "2":
                out_dir = dirs["default_videos_dir"]
            else:
                out_dir = prompt_choice("Enter custom path:")

            os.makedirs(out_dir, exist_ok=True)

            data["output_dir"] = out_dir

            state_stack.append("output_dir")
            state = "download_mode"

        # =========================
        # DOWNLOAD MODE
        # =========================
        elif state == "download_mode":
            print("\n🧠 Select download mode:")
            print(f"1: Multithreaded ({os.cpu_count()} threads)")
            print("2: Single-threaded")

            ans = prompt_choice("Select option:")

            if ans == "exit":
                break
            if ans == "back":
                state = state_stack.pop()
                continue

            data["threads_count"] = 1 if ans == "2" else os.cpu_count()

            state_stack.append("download_mode")
            state = "run"

        # =========================
        # RUN
        # =========================
        elif state == "run":
            print("\n🚀 Starting downloads… (Ctrl+C to cancel)")

            download_media(
                data["urls"],
                data["output_dir"],
                data["media_type"],
                data["threads_count"],
                data["cookies_file"]
            )

            print("\n👋 Exiting.")
            break


if __name__ == "__main__":
    main()
