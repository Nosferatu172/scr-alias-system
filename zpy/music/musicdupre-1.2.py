#!/usr/bin/env python3
# Script Name: New-Music-Duplicate-remover-1.3.py
# ID: SCR-ID-20260317131011-MKM2SWODOL
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: New-Music-Duplicate-remover-1.3

"""
dedupe_hash_rm.py

- Accepts Windows OR WSL paths
- -a / --active uses current working directory (scan dir)
- --pc-active same as -a but includes optional pc-like output/copy/open helpers
- Ctrl+C cancels cleanly (first Ctrl+C cancels; second forces exit)
- Parallel SHA-256 hashing + tqdm progress (falls back if tqdm missing)
- Optional --dry-run (no deletes)
- Optional --keep strategy: first | shortest | longest
- Optional --copy windows|wsl|both to clipboard
- Optional --explore / --thunar open file manager at scan dir
"""

import argparse
import hashlib
import os
import re
import shutil
import signal
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_EXTENSIONS = (".mp3", ".mp4", ".mov", ".jpg", ".jpeg", ".wav", ".flac", ".mkv")

CANCEL_EVENT = threading.Event()


# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    if not CANCEL_EVENT.is_set():
        CANCEL_EVENT.set()
        print("\n⛔ Interrupted (Ctrl+C). Cancelling... (press Ctrl+C again to force exit)")
        return
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# -----------------------
# Environment + path helpers (same style as your pc script)
# -----------------------
def is_wsl() -> bool:
    if os.path.isdir("/mnt/c"):
        return True
    try:
        return "microsoft" in Path("/proc/version").read_text(errors="ignore").lower()
    except Exception:
        return False


def wsl_to_windows(p: str) -> str | None:
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", p)
    if not m:
        return None
    drive = m.group(1).upper()
    rest = m.group(2).replace("/", "\\")
    return f"{drive}:\\{rest}"


def windows_to_wsl(p: str) -> str | None:
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", p)
    if not m:
        return None
    drive = m.group(1).lower()
    rest = m.group(2).replace("\\", "/")
    return f"/mnt/{drive}/{rest}"


def convert_paths(input_path: str) -> dict | None:
    raw = input_path.strip()

    win = wsl_to_windows(raw)
    if win:
        return {"windows": win, "wsl": raw}

    wsl = windows_to_wsl(raw)
    if wsl:
        return {"windows": raw.replace("/", "\\"), "wsl": wsl}

    return None


def resolve_scan_dir(raw_input: str) -> tuple[str, dict | None]:
    converted = convert_paths(raw_input)
    if converted:
        if is_wsl():
            return converted["wsl"], converted
        return converted["windows"], converted
    return raw_input, None


def prompt_nonempty_below(msg: str) -> str:
    while True:
        try:
            print(msg)
            s = input("> ").strip()
        except KeyboardInterrupt:
            CANCEL_EVENT.set()
            raise SystemExit(130)
        if s:
            return s
        print("⚠️ Please enter a path (or use -a/--active).")


# -----------------------
# Clipboard helper (same behavior as pc)
# -----------------------
def copy_to_clipboard(text: str):
    try:
        if is_wsl():
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
            print("📋 Copied to clipboard!")
            return

        if os.name == "nt":
            clip = shutil.which("clip") or "clip"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
            print("📋 Copied to clipboard!")
            return

        wl = shutil.which("wl-copy")
        xc = shutil.which("xclip")
        if wl:
            subprocess.run([wl], input=text.encode("utf-8"), check=True)
            print("📋 Copied to clipboard!")
            return
        if xc:
            subprocess.run([xc, "-selection", "clipboard"], input=text.encode("utf-8"), check=True)
            print("📋 Copied to clipboard!")
            return

        raise RuntimeError("No clipboard tool found (WSL clip.exe / Windows clip / wl-copy / xclip).")
    except Exception as e:
        print(f"⚠️ Clipboard failed: {e}")


# -----------------------
# Open helpers (same spirit as pc)
# -----------------------
def open_windows_explorer_at_wsl_path(wsl_path: str):
    if not is_wsl():
        print("❌ Not running inside WSL. Explorer open is WSL-only.")
        return

    p = str(Path(wsl_path).resolve())
    win = wsl_to_windows(p)
    if not win:
        print(f"❌ Could not convert to Windows path: {p}")
        return

    explorer = shutil.which("explorer.exe") or "/mnt/c/Windows/explorer.exe"
    if not os.path.exists(explorer):
        explorer = "explorer.exe"

    subprocess.Popen([explorer, win])
    print(f"🪟 Opened Windows Explorer: {win}")


def open_thunar(path: str):
    thunar = shutil.which("thunar")
    if not thunar:
        print("❌ Thunar not found. Install it with: sudo apt install thunar")
        return

    p = str(Path(path).resolve())
    subprocess.Popen([thunar, p])
    print(f"🐧 Opened Thunar: {p}")


# -----------------------
# Hashing + dedupe
# -----------------------
def sha256_file(file_path: str) -> tuple[str, str | None]:
    if CANCEL_EVENT.is_set():
        return file_path, None

    h = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):  # 1MB chunks
                if CANCEL_EVENT.is_set():
                    return file_path, None
                h.update(chunk)
        return file_path, h.hexdigest()
    except Exception as e:
        print(f"⚠️ Error reading file: {file_path}\n    {e}")
        return file_path, None


def iter_supported_files(root_dir: str, extensions: tuple[str, ...]):
    for root, _, files in os.walk(root_dir):
        if CANCEL_EVENT.is_set():
            return
        for name in files:
            if CANCEL_EVENT.is_set():
                return
            if name.lower().endswith(extensions):
                yield os.path.join(root, name)


def _tqdm_wrap(iterator, total: int, desc: str):
    try:
        from tqdm import tqdm  # type: ignore
        return tqdm(iterator, total=total, desc=desc)
    except Exception:
        return iterator


def remove_duplicates_by_hash(
    directory: str,
    extensions: tuple[str, ...],
    workers: int = 8,
    dry_run: bool = False,
    keep: str = "first",
) -> int:
    seen_hash_to_path: dict[str, str] = {}
    duplicates: list[str] = []

    files = list(iter_supported_files(directory, extensions))
    total_files = len(files)

    print(f"\n📦 Scanning: {directory}")
    print(f"📄 Supported files found: {total_files}")
    if total_files == 0:
        return 0

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(sha256_file, p) for p in files]

        for future in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Hashing"):
            if CANCEL_EVENT.is_set():
                break

            file_path, file_hash = future.result()
            if not file_hash:
                continue

            prior = seen_hash_to_path.get(file_hash)
            if not prior:
                seen_hash_to_path[file_hash] = file_path
                continue

            keep_path = prior
            del_path = file_path

            if keep == "shortest":
                keep_path = min(prior, file_path, key=lambda x: len(x))
                del_path = file_path if keep_path == prior else prior
            elif keep == "longest":
                keep_path = max(prior, file_path, key=lambda x: len(x))
                del_path = file_path if keep_path == prior else prior

            seen_hash_to_path[file_hash] = keep_path
            if del_path != keep_path:
                duplicates.append(del_path)

    if CANCEL_EVENT.is_set():
        print("\n⛔ Cancelled. No further actions will be taken.")
        return 130

    dup_count = len(duplicates)
    print(f"\n✅ Total files processed: {total_files}")
    print(f"🧬 Unique hashes:         {len(seen_hash_to_path)}")
    print(f"♻️ Duplicates found:      {dup_count}")

    if dup_count == 0:
        return 0

    if dry_run:
        print("\n🧪 Dry run: showing duplicates that WOULD be deleted:")
        for p in duplicates[:200]:
            print(f"  - {p}")
        if dup_count > 200:
            print(f"  ... and {dup_count - 200} more")
        return 0

    print("\n⚠️ About to delete duplicate files.")
    print("    Press Enter to proceed, or Ctrl+C to cancel.")
    try:
        input()
    except KeyboardInterrupt:
        CANCEL_EVENT.set()
        print("\n⛔ Cancelled before deletion.")
        return 130

    deleted = 0
    for p in duplicates:
        if CANCEL_EVENT.is_set():
            break
        try:
            os.remove(p)
            deleted += 1
            print(f"🗑️ Deleted: {p}")
        except Exception as e:
            print(f"⚠️ Error deleting: {p}\n    {e}")

    if CANCEL_EVENT.is_set():
        print(f"\n⛔ Cancelled during deletion. Deleted so far: {deleted}/{dup_count}")
        return 130

    print(f"\n🎯 Deleted duplicates: {deleted}/{dup_count}")
    return 0


def parse_exts(ext_arg: str) -> tuple[str, ...]:
    exts: list[str] = []
    for e in ext_arg.split(","):
        e = e.strip().lower()
        if not e:
            continue
        if not e.startswith("."):
            e = "." + e
        exts.append(e)
    return tuple(exts) if exts else DEFAULT_EXTENSIONS


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="dedupe_hash_rm",
        description="Find and remove duplicate media files by SHA-256 (Windows/WSL path aware, Ctrl+C safe).",
    )
    parser.add_argument("path", nargs="*", help="Directory to scan (Windows path or /mnt/x/... or local path).")

    # active modes
    parser.add_argument("-a", "--active", action="store_true",
                        help="Use current working directory as scan dir.")
    parser.add_argument("--pc-active", action="store_true",
                        help="Use current working directory as scan dir (pc-style convenience).")

    # pc-style extras for scan dir (optional)
    parser.add_argument("--copy", choices=["windows", "wsl", "both"],
                        help="Copy the scan directory path to clipboard in the chosen format.")
    parser.add_argument("--explore", action="store_true",
                        help="(WSL) Open Windows Explorer at the scan directory.")
    parser.add_argument("--thunar", action="store_true",
                        help="(Linux/WSL) Open Thunar at the scan directory.")

    # dedupe options
    parser.add_argument("-j", "--jobs", type=int, default=8, help="Hashing worker threads (default: 8).")
    parser.add_argument("--dry-run", action="store_true", help="Do not delete; just show duplicates.")
    parser.add_argument("--keep", choices=["first", "shortest", "longest"], default="first",
                        help="Which duplicate to keep (default: first).")
    parser.add_argument("--ext", default=",".join(DEFAULT_EXTENSIONS),
                        help="Comma-separated extensions to include. Ex: .mp3,.flac")

    args = parser.parse_args()

    extensions = parse_exts(args.ext)

    use_active = args.active or args.pc_active
    if use_active:
        scan_dir = str(Path.cwd())
        converted = convert_paths(scan_dir)  # may be None if not /mnt/x or X:\ format
    else:
        raw = " ".join(args.path).strip()
        if not raw:
            raw = prompt_nonempty_below("Enter the directory path to scan for duplicates:")
        scan_dir, converted = resolve_scan_dir(raw)

    # normalize scan_dir
    try:
        scan_dir = str(Path(scan_dir).expanduser().resolve())
    except Exception:
        scan_dir = os.path.expanduser(scan_dir)

    if not os.path.isdir(scan_dir):
        print(f"❌ Directory not found:\n{scan_dir}")
        return 2

    # Display both styles if we can infer them
    conv2 = converted or convert_paths(scan_dir)
    if conv2:
        print(f"\n🧭 Scan dir interpreted as:")
        print(f"   Windows: {conv2['windows']}")
        print(f"   WSL:     {conv2['wsl']}")
    else:
        print(f"\n🧭 Scan dir: {scan_dir}")

    # Optional pc-like actions (operate on scan dir)
    if args.copy:
        if not conv2:
            # If scan_dir isn't convertible, just copy raw scan_dir
            copy_to_clipboard(scan_dir)
        else:
            if args.copy == "windows":
                copy_to_clipboard(conv2["windows"])
            elif args.copy == "wsl":
                copy_to_clipboard(conv2["wsl"])
            else:
                block = f"Windows: {conv2['windows']}\nWSL:     {conv2['wsl']}\n"
                copy_to_clipboard(block)

    if args.explore:
        # Prefer WSL path for explorer open (it converts internally)
        if conv2 and conv2.get("wsl"):
            open_windows_explorer_at_wsl_path(conv2["wsl"])
        else:
            # If we are in WSL and scan_dir is already WSL, use it
            open_windows_explorer_at_wsl_path(scan_dir)

    if args.thunar:
        open_thunar(scan_dir)

    # Run dedupe
    return remove_duplicates_by_hash(
        directory=scan_dir,
        extensions=extensions,
        workers=max(1, args.jobs),
        dry_run=args.dry_run,
        keep=args.keep,
    )


if __name__ == "__main__":
    raise SystemExit(main())
