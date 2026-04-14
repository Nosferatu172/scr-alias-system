#!/usr/bin/env python3
# Script Name: New-Music-Duplicate-remover-1.4.py
# ID: SCR-ID-20260317131015-QQSO8SI7K8
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: New-Music-Duplicate-remover-1.4

"""
dupremkr3 - Duplicate remover by content hash (Windows/WSL path aware)

Core:
- Accepts Windows OR WSL paths
- -a / --active uses current working directory as scan dir
- Ctrl+C cancels cleanly (first cancels, second forces exit)
- Parallel SHA-256 hashing + tqdm progress (falls back if tqdm missing)
- Optional --dry-run (no deletes)
- Optional --keep strategy: first | shortest | longest

Extras:
- --pc-active: alias for scanning current directory (pc-style convenience)
- --copy windows|wsl|both: copy scan dir in chosen format
- --explore: open Explorer at scan dir (WSL)
- --thunar: open Thunar at scan dir

Upgrades:
- --version
- --examples
- --help-full (prints extended usage block)
- --list (print duplicates list)
- --report <file.{txt|json}>
- --trash (move dupes to _DUP_TRASH instead of deleting)
- --min-size 10k/50m/2g or bytes
- --fast (quick fingerprint -> verify collisions with SHA-256)
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Iterable

VERSION = "1.3"

DEFAULT_EXTENSIONS = (".mp3", ".mp4", ".mov", ".jpg", ".jpeg", ".wav", ".flac", ".mkv")
CANCEL_EVENT = threading.Event()


# -----------------------
# Ctrl+C handler (single press = exit)
# -----------------------
def _sigint_handler(sig, frame):
    CANCEL_EVENT.set()
    print("\n⛔ Interrupted (Ctrl+C). Cancelling and exiting cleanly.")
    raise SystemExit(130)

signal.signal(signal.SIGINT, _sigint_handler)

# -----------------------
# Environment + path helpers (pc-style)
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
# Clipboard helper
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
# Open helpers
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
# Small helpers
# -----------------------
def _tqdm_wrap(iterator, total: int, desc: str):
    try:
        from tqdm import tqdm  # type: ignore
        return tqdm(iterator, total=total, desc=desc)
    except Exception:
        return iterator


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


def parse_size(s: str) -> int:
    """
    Accepts:
      "123" bytes
      "10k" "50m" "2g" (base-1024)
    """
    s = s.strip().lower()
    if not s:
        return 0
    m = re.match(r"^(\d+)([kmg])?$", s)
    if not m:
        raise ValueError("Invalid size format. Use bytes or 10k/50m/2g.")
    n = int(m.group(1))
    suf = m.group(2)
    if suf == "k":
        return n * 1024
    if suf == "m":
        return n * 1024**2
    if suf == "g":
        return n * 1024**3
    return n


# -----------------------
# File iteration
# -----------------------
def iter_supported_files(root_dir: str, extensions: tuple[str, ...], min_size: int) -> Iterable[str]:
    for root, _, files in os.walk(root_dir):
        if CANCEL_EVENT.is_set():
            return
        for name in files:
            if CANCEL_EVENT.is_set():
                return
            if not name.lower().endswith(extensions):
                continue
            p = os.path.join(root, name)
            try:
                if min_size > 0 and os.path.getsize(p) < min_size:
                    continue
            except Exception:
                # if we can't stat it, still try hashing later
                pass
            yield p


# -----------------------
# Hashing
# -----------------------
def sha256_file(file_path: str) -> tuple[str, str | None]:
    if CANCEL_EVENT.is_set():
        return file_path, None

    h = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                if CANCEL_EVENT.is_set():
                    return file_path, None
                h.update(chunk)
        return file_path, h.hexdigest()
    except Exception as e:
        print(f"⚠️ Error reading file: {file_path}\n    {e}")
        return file_path, None


def fast_fingerprint(file_path: str) -> tuple[str, str | None]:
    """
    Quick fingerprint:
      size + first 64KB + last 64KB (if large enough)
    Then we SHA-256 only within collision groups.
    """
    if CANCEL_EVENT.is_set():
        return file_path, None
    try:
        size = os.path.getsize(file_path)
        h = hashlib.blake2b(digest_size=16)
        h.update(str(size).encode("utf-8"))
        with open(file_path, "rb") as f:
            head = f.read(64 * 1024)
            h.update(head)
            if size > 128 * 1024:
                f.seek(max(0, size - 64 * 1024))
                tail = f.read(64 * 1024)
                h.update(tail)
        return file_path, h.hexdigest()
    except Exception as e:
        print(f"⚠️ Error fingerprinting: {file_path}\n    {e}")
        return file_path, None


# -----------------------
# Dedupe selection
# -----------------------
def choose_keep_and_delete(prior: str, current: str, keep: str) -> tuple[str, str]:
    if keep == "shortest":
        keep_path = min(prior, current, key=lambda x: len(x))
        del_path = current if keep_path == prior else prior
        return keep_path, del_path
    if keep == "longest":
        keep_path = max(prior, current, key=lambda x: len(x))
        del_path = current if keep_path == prior else prior
        return keep_path, del_path
    return prior, current  # keep first encountered


# -----------------------
# Action: delete or trash
# -----------------------
def move_to_trash(scan_dir: str, path: str, trash_dirname: str = "_DUP_TRASH") -> str:
    trash_root = Path(scan_dir) / trash_dirname
    trash_root.mkdir(parents=True, exist_ok=True)

    src = Path(path)
    # preserve relative structure if possible
    try:
        rel = src.relative_to(Path(scan_dir))
        dest = trash_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
    except Exception:
        dest = trash_root / src.name

    # avoid overwriting
    if dest.exists():
        stamp = time.strftime("%Y%m%d-%H%M%S")
        dest = dest.with_name(f"{dest.stem}__{stamp}{dest.suffix}")

    shutil.move(str(src), str(dest))
    return str(dest)


# -----------------------
# Reporting
# -----------------------
def write_report(report_path: str, scan_dir: str, duplicates: list[str], kept_map: dict[str, str], mode: str):
    p = Path(report_path)
    p.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "scan_dir": scan_dir,
        "mode": mode,
        "duplicates_count": len(duplicates),
        "duplicates": duplicates,
        "unique_count": len(kept_map),
    }

    if p.suffix.lower() == ".json":
        p.write_text(json.dumps(data, indent=2), encoding="utf-8")
    else:
        lines = [
            f"scan_dir: {scan_dir}",
            f"mode: {mode}",
            f"unique: {len(kept_map)}",
            f"duplicates: {len(duplicates)}",
            "",
            "duplicates:",
            *[f"  - {x}" for x in duplicates],
            "",
        ]
        p.write_text("\n".join(lines), encoding="utf-8")


# -----------------------
# Main dedupe engine
# -----------------------
def remove_duplicates_by_hash(
    directory: str,
    extensions: tuple[str, ...],
    workers: int = 8,
    dry_run: bool = False,
    keep: str = "first",
    min_size: int = 0,
    fast: bool = False,
    list_only: bool = False,
    report: str | None = None,
    trash: bool = False,
) -> int:
    kept_map: dict[str, str] = {}          # hash -> kept path (full hash)
    duplicates: list[str] = []

    files = list(iter_supported_files(directory, extensions, min_size))
    total_files = len(files)

    print(f"\n📦 Scanning: {directory}")
    print(f"📄 Candidate files: {total_files}")
    if min_size:
        print(f"📏 Min size: {min_size} bytes")
    if total_files == 0:
        return 0

    if not fast:
        # Full SHA-256 for everything
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(sha256_file, p) for p in files]

            for future in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Hashing (sha256)"):
                if CANCEL_EVENT.is_set():
                    break
                file_path, file_hash = future.result()
                if not file_hash:
                    continue

                prior = kept_map.get(file_hash)
                if not prior:
                    kept_map[file_hash] = file_path
                    continue

                keep_path, del_path = choose_keep_and_delete(prior, file_path, keep)
                kept_map[file_hash] = keep_path
                if del_path != keep_path:
                    duplicates.append(del_path)
    else:
        # FAST mode: fingerprint first, then sha256 only for collisions
        fp_groups: dict[str, list[str]] = {}

        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(fast_fingerprint, p) for p in files]
            for future in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Fingerprint (fast)"):
                if CANCEL_EVENT.is_set():
                    break
                file_path, fp = future.result()
                if not fp:
                    continue
                fp_groups.setdefault(fp, []).append(file_path)

        collision_files = [p for grp in fp_groups.values() if len(grp) > 1 for p in grp]
        print(f"⚡ Fast mode: fingerprint collisions to verify: {len(collision_files)}")

        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(sha256_file, p) for p in collision_files]
            for future in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Verify (sha256)"):
                if CANCEL_EVENT.is_set():
                    break
                file_path, file_hash = future.result()
                if not file_hash:
                    continue

                prior = kept_map.get(file_hash)
                if not prior:
                    kept_map[file_hash] = file_path
                    continue

                keep_path, del_path = choose_keep_and_delete(prior, file_path, keep)
                kept_map[file_hash] = keep_path
                if del_path != keep_path:
                    duplicates.append(del_path)

    if CANCEL_EVENT.is_set():
        print("\n⛔ Cancelled. No further actions will be taken.")
        return 130

    dup_count = len(duplicates)
    print(f"\n✅ Unique hashes:    {len(kept_map)}")
    print(f"♻️ Duplicates found: {dup_count}")

    if report:
        write_report(report, directory, duplicates, kept_map, mode=("fast" if fast else "sha256"))
        print(f"📝 Report written: {report}")

    if dup_count == 0:
        return 0

    if list_only or dry_run:
        print("\n📋 Duplicates:")
        for p in duplicates[:500]:
            print(f"  - {p}")
        if dup_count > 500:
            print(f"  ... and {dup_count - 500} more")
        return 0

    action = "move to trash" if trash else "delete"
    print(f"\n⚠️ About to {action} duplicate files.")
    print("    Press Enter to proceed, or Ctrl+C to cancel.")
    try:
        input()
    except KeyboardInterrupt:
        CANCEL_EVENT.set()
        print("\n⛔ Cancelled before action.")
        return 130

    acted = 0
    for p in duplicates:
        if CANCEL_EVENT.is_set():
            break
        try:
            if trash:
                dest = move_to_trash(directory, p)
                acted += 1
                print(f"🗃️ Trashed: {p}  ->  {dest}")
            else:
                os.remove(p)
                acted += 1
                print(f"🗑️ Deleted: {p}")
        except Exception as e:
            print(f"⚠️ Error processing: {p}\n    {e}")

    if CANCEL_EVENT.is_set():
        print(f"\n⛔ Cancelled during action. Processed so far: {acted}/{dup_count}")
        return 130

    print(f"\n🎯 Done. Processed duplicates: {acted}/{dup_count}")
    return 0


# -----------------------
# Help / examples
# -----------------------
FULL_HELP = f"""
dupremkr3 v{VERSION}

Recipes:
  1) Dry-run current directory:
     dupremkr3 -a --dry-run

  2) Fast mode (good for huge trees):
     dupremkr3 -a --fast --dry-run

  3) Only list duplicates (no prompt):
     dupremkr3 -a --list

  4) Move dupes to _DUP_TRASH instead of deleting:
     dupremkr3 -a --trash

  5) Skip tiny files:
     dupremkr3 -a --min-size 5m

  6) Restrict to specific types:
     dupremkr3 -a --ext .mp3,.flac

  7) Make a report:
     dupremkr3 -a --fast --report /mnt/c/scr/logs/dupremkr3_report.json

  8) pc-style convenience: copy scan dir formats:
     dupremkr3 -a --copy both
"""


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="dupremkr3",
        description="Find and remove duplicate media files by content (hash), Windows/WSL path aware, Ctrl+C safe.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Tip: use --help-full for recipes and power flags.",
    )

    parser.add_argument("path", nargs="*", help="Directory to scan (Windows path, /mnt/x, or local path).")

    # help-ish extras
    parser.add_argument("--version", action="store_true", help="Print version and exit.")
    parser.add_argument("--examples", action="store_true", help="Print examples and exit.")
    parser.add_argument("--help-full", action="store_true", help="Print full help with recipes and exit.")

    # active modes
    parser.add_argument("-a", "--active", action="store_true", help="Use current working directory as scan dir.")
    parser.add_argument("--pc-active", action="store_true", help="Alias for scanning current directory.")

    # pc-style convenience for scan dir
    parser.add_argument("--copy", choices=["windows", "wsl", "both"],
                        help="Copy the scan directory path to clipboard in the chosen format.")
    parser.add_argument("--explore", action="store_true", help="(WSL) Open Windows Explorer at the scan directory.")
    parser.add_argument("--thunar", action="store_true", help="(Linux/WSL) Open Thunar at the scan directory.")

    # dedupe options
    parser.add_argument("-j", "--jobs", type=int, default=8, help="Worker threads (default: 8).")
    parser.add_argument("--dry-run", action="store_true", help="Do not delete; just show duplicates.")
    parser.add_argument("--list", action="store_true", help="List duplicates and exit (no delete prompt).")
    parser.add_argument("--keep", choices=["first", "shortest", "longest"], default="first",
                        help="Which duplicate to keep (default: first).")
    parser.add_argument("--ext", default=",".join(DEFAULT_EXTENSIONS),
                        help="Comma-separated extensions. Ex: .mp3,.flac")
    parser.add_argument("--min-size", default="0",
                        help="Skip files smaller than this (bytes or 10k/50m/2g). Default: 0")
    parser.add_argument("--fast", action="store_true",
                        help="Fast mode: fingerprint first, then sha256 only for collisions.")
    parser.add_argument("--report", default=None,
                        help="Write report to file (.txt or .json).")
    parser.add_argument("--trash", action="store_true",
                        help="Move duplicates to _DUP_TRASH instead of deleting.")

    args = parser.parse_args()

    if args.version:
        print(VERSION)
        return 0
    if args.examples or args.help_full:
        print(FULL_HELP.strip())
        return 0

    # parse extensions + min size
    extensions = parse_exts(args.ext)
    try:
        min_size = parse_size(args.min_size)
    except Exception as e:
        print(f"❌ --min-size invalid: {e}")
        return 2

    # decide scan dir
    use_active = args.active or args.pc_active
    if use_active:
        scan_dir = str(Path.cwd())
        converted = convert_paths(scan_dir)
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

    # show both styles if possible
    conv2 = converted or convert_paths(scan_dir)
    if conv2:
        print(f"\n🧭 Scan dir interpreted as:")
        print(f"   Windows: {conv2['windows']}")
        print(f"   WSL:     {conv2['wsl']}")
    else:
        print(f"\n🧭 Scan dir: {scan_dir}")

    # optional pc-style actions on scan dir
    if args.copy:
        if not conv2:
            copy_to_clipboard(scan_dir)
        else:
            if args.copy == "windows":
                copy_to_clipboard(conv2["windows"])
            elif args.copy == "wsl":
                copy_to_clipboard(conv2["wsl"])
            else:
                copy_to_clipboard(f"Windows: {conv2['windows']}\nWSL:     {conv2['wsl']}\n")

    if args.explore:
        if conv2 and conv2.get("wsl"):
            open_windows_explorer_at_wsl_path(conv2["wsl"])
        else:
            open_windows_explorer_at_wsl_path(scan_dir)

    if args.thunar:
        open_thunar(scan_dir)

    # run
    return remove_duplicates_by_hash(
        directory=scan_dir,
        extensions=extensions,
        workers=max(1, args.jobs),
        dry_run=args.dry_run,
        keep=args.keep,
        min_size=min_size,
        fast=args.fast,
        list_only=args.list,
        report=args.report,
        trash=args.trash,
    )


if __name__ == "__main__":
    raise SystemExit(main())
