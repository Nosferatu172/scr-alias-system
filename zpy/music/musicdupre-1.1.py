#!/usr/bin/env python3
# Script Name: New-Music-duplicate-remover.py
# ID: SCR-ID-20260317131024-62UV8ED8Q4
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: New-Music-duplicate-remover

"""
dedupe_hash_rm.py

- Accepts Windows OR WSL paths (uses the same convert functions you posted)
- Ctrl+C cancels cleanly (stops scheduling / hashing as fast as possible)
- No clipboard usage (we reuse the path + input helpers only)
- Parallel SHA-256 hashing + tqdm progress (falls back if tqdm missing)
"""

import argparse
import hashlib
import os
import re
import signal
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# -----------------------
# Config
# -----------------------
SUPPORTED_EXTENSIONS = (".mp3", ".mp4", ".mov", ".jpg", ".jpeg", ".wav", ".flac", ".mkv")

# Cancellation flag set by Ctrl+C
CANCEL_EVENT = threading.Event()


# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    # First Ctrl+C: request cancellation
    if not CANCEL_EVENT.is_set():
        CANCEL_EVENT.set()
        print("\n⛔ Interrupted (Ctrl+C). Cancelling... (press Ctrl+C again to force exit)")
        return
    # Second Ctrl+C: hard exit
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# -----------------------
# Environment + path helpers (reused)
# -----------------------
def is_wsl() -> bool:
    if os.path.isdir("/mnt/c"):
        return True
    try:
        return "microsoft" in Path("/proc/version").read_text(errors="ignore").lower()
    except Exception:
        return False


def wsl_to_windows(p: str) -> str | None:
    r"""
    Convert WSL path to Windows path.
      /mnt/f/Some/Dir -> F:\Some\Dir
    """
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", p)
    if not m:
        return None
    drive = m.group(1).upper()
    rest = m.group(2).replace("/", "\\")
    return f"{drive}:\\{rest}"


def windows_to_wsl(p: str) -> str | None:
    r"""
    Convert Windows path to WSL path.
      F:\Some\Dir or F:/Some/Dir -> /mnt/f/Some/Dir
    """
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", p)
    if not m:
        return None
    drive = m.group(1).lower()
    rest = m.group(2).replace("\\", "/")
    return f"/mnt/{drive}/{rest}"


def convert_paths(input_path: str) -> dict | None:
    raw = input_path.strip()

    # WSL -> Windows
    win = wsl_to_windows(raw)
    if win:
        return {"windows": win, "wsl": raw}

    # Windows -> WSL
    wsl = windows_to_wsl(raw)
    if wsl:
        return {"windows": raw.replace("/", "\\"), "wsl": wsl}

    return None


def prompt_nonempty_below(msg: str) -> str:
    """Input below prompt, Ctrl+C cancels."""
    while True:
        try:
            print(msg)
            s = input("> ").strip()
        except KeyboardInterrupt:
            CANCEL_EVENT.set()
            raise SystemExit(130)
        if s:
            return s
        print("⚠️ Please enter a path (or use -a / --active for current directory).")


def resolve_scan_dir(raw_input: str, active: bool) -> tuple[str, dict | None]:
    """
    Returns:
      (scan_path, converted_dict_or_none)

    scan_path is a usable local path for os.walk() in the current environment.
    """
    if active:
        p = str(Path.cwd())
        converted = convert_paths(p)  # might be None if not windows/wsl style, that's ok
        return p, converted

    # If user provided a path, try to interpret it.
    converted = convert_paths(raw_input)
    if converted:
        # Prefer WSL path for scanning if we're in WSL; otherwise use the Windows/raw.
        if is_wsl():
            return converted["wsl"], converted
        return converted["windows"], converted

    # If it wasn't a recognizable Windows/WSL pattern, treat it as "local path".
    return raw_input, None


# -----------------------
# Hashing + dedupe
# -----------------------
def sha256_file(file_path: str) -> tuple[str, str | None]:
    """Generate SHA-256 hash for a file; returns (path, hexhash|None)."""
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


def iter_supported_files(root_dir: str):
    for root, _, files in os.walk(root_dir):
        if CANCEL_EVENT.is_set():
            return
        for name in files:
            if CANCEL_EVENT.is_set():
                return
            if name.lower().endswith(SUPPORTED_EXTENSIONS):
                yield os.path.join(root, name)


def _tqdm_wrap(iterator, total: int, desc: str):
    """Use tqdm if available; otherwise yield directly."""
    try:
        from tqdm import tqdm  # type: ignore

        return tqdm(iterator, total=total, desc=desc)
    except Exception:
        # No tqdm installed
        return iterator


def remove_duplicates_by_hash(
    directory: str,
    workers: int = 8,
    dry_run: bool = False,
    keep: str = "first",
) -> int:
    """
    keep:
      - "first": keep first encountered path, delete later duplicates
      - "shortest": keep shortest filepath, delete others
      - "longest": keep longest filepath, delete others
    """
    seen_hash_to_path: dict[str, str] = {}
    duplicates: list[str] = []

    files = list(iter_supported_files(directory))
    total_files = len(files)
    print(f"\n📦 Scanning: {directory}")
    print(f"📄 Supported files found: {total_files}")
    if total_files == 0:
        return 0

    # Hash in parallel
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

            # Decide which to keep based on strategy
            keep_path = prior
            del_path = file_path

            if keep == "shortest":
                keep_path = min(prior, file_path, key=lambda x: len(x))
                del_path = file_path if keep_path == prior else prior
            elif keep == "longest":
                keep_path = max(prior, file_path, key=lambda x: len(x))
                del_path = file_path if keep_path == prior else prior
            else:
                # keep == "first": keep prior, delete current
                keep_path = prior
                del_path = file_path

            # Update keeper record
            seen_hash_to_path[file_hash] = keep_path

            # Only mark for deletion if it's not the keeper
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


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="dedupe_hash_rm",
        description="Find and remove duplicate media files by SHA-256 (Windows/WSL path aware, Ctrl+C safe).",
    )
    parser.add_argument("path", nargs="*", help="Directory to scan (Windows path or /mnt/x/... or normal local path).")
    parser.add_argument("-a", "--active", action="store_true", help="Use current working directory.")
    parser.add_argument("-j", "--jobs", type=int, default=8, help="Hashing worker threads (default: 8).")
    parser.add_argument("--dry-run", action="store_true", help="Do not delete; just show duplicates.")
    parser.add_argument(
        "--keep",
        choices=["first", "shortest", "longest"],
        default="first",
        help="Which duplicate to keep (default: first).",
    )
    parser.add_argument(
        "--ext",
        default=",".join(SUPPORTED_EXTENSIONS),
        help="Comma-separated extensions to include (default is built-in list).",
    )
    args = parser.parse_args()

    # Override extensions if user provides --ext
    global SUPPORTED_EXTENSIONS
    if args.ext:
        exts = []
        for e in args.ext.split(","):
            e = e.strip().lower()
            if not e:
                continue
            if not e.startswith("."):
                e = "." + e
            exts.append(e)
        if exts:
            SUPPORTED_EXTENSIONS = tuple(exts)

    raw = " ".join(args.path).strip()
    if not args.active and not raw:
        raw = prompt_nonempty_below("Enter the directory path to scan for duplicates:")

    scan_dir, converted = resolve_scan_dir(raw, args.active)

    # Normalize/resolve if possible
    try:
        scan_dir = str(Path(scan_dir).expanduser().resolve())
    except Exception:
        scan_dir = os.path.expanduser(scan_dir)

    if not os.path.isdir(scan_dir):
        # Helpful hint if they passed Windows path while inside WSL but it didn't match regex
        if is_wsl() and re.match(r"^[A-Za-z]:[\\/]", raw):
            maybe = windows_to_wsl(raw)
            if maybe and os.path.isdir(maybe):
                scan_dir = maybe

        if not os.path.isdir(scan_dir):
            print(f"❌ Directory not found:\n{scan_dir}")
            return 2

    # Print both path styles if we can
    if converted:
        print(f"\n🧭 Path interpreted as:")
        print(f"   Windows: {converted['windows']}")
        print(f"   WSL:     {converted['wsl']}")
    else:
        # Try to derive windows/wsl forms from the resolved scan_dir
        conv2 = convert_paths(scan_dir)
        if conv2:
            print(f"\n🧭 Resolved path:")
            print(f"   Windows: {conv2['windows']}")
            print(f"   WSL:     {conv2['wsl']}")

    return remove_duplicates_by_hash(
        directory=scan_dir,
        workers=max(1, args.jobs),
        dry_run=args.dry_run,
        keep=args.keep,
    )


if __name__ == "__main__":
    raise SystemExit(main())
