#!/usr/bin/env python3
# Script Name: new-musicdupre.py
# ID: SCR-ID-20260317131029-KC03MG0FWG
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: new-musicdupre

"""
dupremkr3 - Duplicate remover by content hash (Windows/WSL path aware)

Core:
- Accepts Windows OR WSL paths
- -a / --active uses launch directory as scan dir
- Ctrl+C cancels immediately (single press)
- Parallel hashing + tqdm progress (falls back if tqdm missing)
- Optional --dry-run (no deletes)
- Optional --keep strategy: first | shortest | longest

Extras:
- --pc-active: alias for scanning current directory
- --copy windows|wsl|both: copy scan dir in chosen format
- --explore: open Explorer at scan dir (WSL)
- --thunar: open Thunar at scan dir

Power:
- --version / --examples / --help-full
- --list (list duplicates)
- --report <file.{txt|json}>
- --trash moves dupes to _DUP_TRASH instead of deleting
- --min-size 10k/50m/2g or bytes
- --fast (fingerprint -> verify collisions with sha256)

Default-dir mode (stored next to script):
- -d/--defaultdir --on [path]   enable + set default (path optional; uses launch dir)
- -d/--defaultdir --off         disable
When enabled: running without a path uses saved default automatically.
"""

import argparse
import csv
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
from datetime import datetime
from pathlib import Path
from typing import Iterable

VERSION = "1.5"

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
# Self-sourcing config (default directory)
# -----------------------
SCRIPT_DIR = Path(__file__).resolve().parent
LOG_DIR = SCRIPT_DIR / "logs"
DEFAULTDIR_CSV = LOG_DIR / "default_dir.csv"


def _ensure_log_dir():
    LOG_DIR.mkdir(parents=True, exist_ok=True)


def get_effective_cwd() -> Path:
    """
    Prefer the directory the user launched the command from.
    Falls back to the current process cwd if not provided.
    """
    caller = os.environ.get("SCR_CALLER_PWD", "").strip()
    if caller and Path(caller).is_dir():
        return Path(caller).resolve()
    return Path.cwd()


def resolve_local_path(raw: str, base: Path | None = None) -> Path:
    """
    Resolve a user path relative to the caller/launch directory unless absolute.
    """
    base = base or get_effective_cwd()
    p = Path(os.path.expandvars(os.path.expanduser(raw)))
    if not p.is_absolute():
        p = base / p
    try:
        return p.resolve()
    except Exception:
        return p


def load_default_dir() -> tuple[bool, str | None]:
    _ensure_log_dir()
    if not DEFAULTDIR_CSV.exists():
        return False, None
    try:
        with DEFAULTDIR_CSV.open("r", encoding="utf-8", newline="") as f:
            r = csv.DictReader(f)
            row = next(r, None)
            if not row:
                return False, None
        enabled = str(row.get("enabled", "")).strip().lower() in ("1", "true", "yes", "on")
        path = str(row.get("path", "")).strip() or None
        return enabled, path
    except Exception:
        return False, None


def save_default_dir(enabled: bool, path: str | None):
    _ensure_log_dir()
    norm_path = None
    if path:
        try:
            norm_path = str(resolve_local_path(path))
        except Exception:
            norm_path = os.path.expanduser(path)

    with DEFAULTDIR_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["enabled", "path", "updated"])
        w.writeheader()
        w.writerow(
            {
                "enabled": "on" if enabled else "off",
                "path": norm_path or "",
                "updated": datetime.now().isoformat(timespec="seconds"),
            }
        )

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


def resolve_scan_dir(raw_input: str, base: Path | None = None) -> tuple[str, dict | None]:
    """
    Resolve a scan dir from Windows/WSL/local input.
    Relative local input is anchored to the caller/launch directory.
    """
    converted = convert_paths(raw_input)
    if converted:
        if is_wsl():
            return converted["wsl"], converted
        return converted["windows"], converted

    p = resolve_local_path(raw_input, base=base)
    return str(p), None


def prompt_nonempty_below(msg: str) -> str:
    while True:
        print(msg)
        s = input("> ").strip()
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
    p = str(resolve_local_path(wsl_path))
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
    p = str(resolve_local_path(path))
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
    return prior, current

# -----------------------
# Action: delete or trash
# -----------------------
def move_to_trash(scan_dir: str, path: str, trash_dirname: str = "_DUP_TRASH") -> str:
    trash_root = Path(scan_dir) / trash_dirname
    trash_root.mkdir(parents=True, exist_ok=True)

    src = Path(path)
    try:
        rel = src.relative_to(Path(scan_dir))
        dest = trash_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
    except Exception:
        dest = trash_root / src.name

    if dest.exists():
        stamp = time.strftime("%Y%m%d-%H%M%S")
        dest = dest.with_name(f"{dest.stem}__{stamp}{dest.suffix}")

    shutil.move(str(src), str(dest))
    return str(dest)

# -----------------------
# Reporting
# -----------------------
def write_report(report_path: str, scan_dir: str, duplicates: list[str], unique_count: int, mode: str):
    p = Path(report_path)
    if not p.is_absolute():
        p = get_effective_cwd() / p
    p.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "scan_dir": scan_dir,
        "mode": mode,
        "unique_count": unique_count,
        "duplicates_count": len(duplicates),
        "duplicates": duplicates,
    }
    if p.suffix.lower() == ".json":
        p.write_text(json.dumps(data, indent=2), encoding="utf-8")
    else:
        lines = [
            f"scan_dir: {scan_dir}",
            f"mode: {mode}",
            f"unique: {unique_count}",
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
def run_dedupe(
    directory: str,
    extensions: tuple[str, ...],
    workers: int,
    dry_run: bool,
    keep: str,
    min_size: int,
    fast: bool,
    list_only: bool,
    report: str | None,
    trash: bool,
) -> int:
    kept_map: dict[str, str] = {}
    duplicates: list[str] = []

    files = list(iter_supported_files(directory, extensions, min_size))
    total_files = len(files)

    print(f"\n📦 Scanning: {directory}")
    print(f"📄 Candidate files: {total_files}")
    if min_size:
        print(f"📏 Min size: {min_size} bytes")
    if total_files == 0:
        return 0

    mode = "sha256"

    if not fast:
        with ThreadPoolExecutor(max_workers=workers) as ex:
            futures = [ex.submit(sha256_file, p) for p in files]
            for fut in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Hashing (sha256)"):
                file_path, file_hash = fut.result()
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
        mode = "fast"
        fp_groups: dict[str, list[str]] = {}

        with ThreadPoolExecutor(max_workers=workers) as ex:
            futures = [ex.submit(fast_fingerprint, p) for p in files]
            for fut in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Fingerprint (fast)"):
                file_path, fp = fut.result()
                if not fp:
                    continue
                fp_groups.setdefault(fp, []).append(file_path)

        collision_files = [p for grp in fp_groups.values() if len(grp) > 1 for p in grp]
        print(f"⚡ Fast mode: fingerprint collisions to verify: {len(collision_files)}")

        with ThreadPoolExecutor(max_workers=workers) as ex:
            futures = [ex.submit(sha256_file, p) for p in collision_files]
            for fut in _tqdm_wrap(as_completed(futures), total=len(futures), desc="Verify (sha256)"):
                file_path, file_hash = fut.result()
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

    dup_count = len(duplicates)
    print(f"\n✅ Unique hashes:    {len(kept_map)}")
    print(f"♻️ Duplicates found: {dup_count}")

    if report:
        write_report(report, directory, duplicates, unique_count=len(kept_map), mode=mode)
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
    input()

    acted = 0
    for p in duplicates:
        if trash:
            dest = move_to_trash(directory, p)
            acted += 1
            print(f"🗃️ Trashed: {p}  ->  {dest}")
        else:
            os.remove(p)
            acted += 1
            print(f"🗑️ Deleted: {p}")

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

  3) Only list duplicates:
     dupremkr3 -a --list

  4) Move dupes to _DUP_TRASH instead of deleting:
     dupremkr3 -a --trash

  5) Skip tiny files:
     dupremkr3 -a --min-size 5m

  6) Restrict to specific types:
     dupremkr3 -a --ext .mp3,.flac

  7) Write a report:
     dupremkr3 -a --fast --report ./dupremkr3_report.json

Default-dir mode:
  Enable and set to current directory:
     dupremkr3 -d --on

  Enable and set to a specific directory:
     dupremkr3 -d --on /mnt/f/Music/mine/Active

  Disable:
     dupremkr3 -d --off

  After enabling, running with no path uses it:
     dupremkr3 --dry-run
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

    parser.add_argument("--version", action="store_true", help="Print version and exit.")
    parser.add_argument("--examples", action="store_true", help="Print examples and exit.")
    parser.add_argument("--help-full", action="store_true", help="Print full help with recipes and exit.")

    parser.add_argument(
        "-d", "--defaultdir", action="store_true",
        help="Use/manage a saved default scan directory (stored next to script in logs/default_dir.csv)."
    )
    parser.add_argument(
        "--on", dest="defaultdir_on", action="store_true",
        help="With -d: enable defaultdir mode (and optionally set the default path)."
    )
    parser.add_argument(
        "--off", dest="defaultdir_off", action="store_true",
        help="With -d: disable defaultdir mode."
    )

    parser.add_argument("-a", "--active", action="store_true", help="Use current working directory as scan dir.")
    parser.add_argument("--pc-active", action="store_true", help="Alias for scanning current directory.")

    parser.add_argument("--copy", choices=["windows", "wsl", "both"],
                        help="Copy the scan directory path to clipboard in the chosen format.")
    parser.add_argument("--explore", action="store_true", help="(WSL) Open Windows Explorer at the scan directory.")
    parser.add_argument("--thunar", action="store_true", help="(Linux/WSL) Open Thunar at the scan directory.")

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
    parser.add_argument("--report", default=None, help="Write report to file (.txt or .json).")
    parser.add_argument("--trash", action="store_true",
                        help="Move duplicates to _DUP_TRASH instead of deleting.")

    args = parser.parse_args()

    if args.version:
        print(VERSION)
        return 0
    if args.examples or args.help_full:
        print(FULL_HELP.strip())
        return 0

    base_cwd = get_effective_cwd()

    # Handle defaultdir settings command
    if args.defaultdir:
        if (args.defaultdir_on and args.defaultdir_off) or (not args.defaultdir_on and not args.defaultdir_off):
            print("❌ With -d/--defaultdir, choose exactly one: --on or --off")
            return 2

        if args.defaultdir_off:
            save_default_dir(False, None)
            print("✅ Default directory mode: OFF")
            print(f"📝 Config: {DEFAULTDIR_CSV}")
            return 0

        provided = " ".join(args.path).strip()
        if provided:
            resolved_default, _ = resolve_scan_dir(provided, base=base_cwd)
            new_default = str(resolve_local_path(resolved_default, base=base_cwd))
        else:
            new_default = str(base_cwd)

        if not os.path.isdir(new_default):
            print(f"❌ Not a directory:\n{new_default}")
            return 2

        save_default_dir(True, new_default)
        print("✅ Default directory mode: ON")
        print(f"📌 Default scan dir set to:\n{new_default}")
        print(f"📝 Config: {DEFAULTDIR_CSV}")
        return 0

    extensions = parse_exts(args.ext)
    try:
        min_size = parse_size(args.min_size)
    except Exception as e:
        print(f"❌ --min-size invalid: {e}")
        return 2

    # Decide scan dir
    use_active = args.active or args.pc_active
    if use_active:
        scan_dir = str(base_cwd)
        converted = convert_paths(scan_dir)
    else:
        raw = " ".join(args.path).strip()

        if not raw:
            enabled, saved = load_default_dir()
            if enabled and saved and os.path.isdir(saved):
                raw = saved
                print(f"📌 Using saved default directory:\n{saved}")
            else:
                raw = prompt_nonempty_below("Enter the directory path to scan for duplicates:")

        scan_dir, converted = resolve_scan_dir(raw, base=base_cwd)

    # Normalize scan dir
    try:
        scan_dir = str(resolve_local_path(scan_dir, base=base_cwd))
    except Exception:
        scan_dir = os.path.expanduser(scan_dir)

    if not os.path.isdir(scan_dir):
        print(f"❌ Directory not found:\n{scan_dir}")
        return 2

    conv2 = converted or convert_paths(scan_dir)
    if conv2:
        print(f"\n🧭 Scan dir interpreted as:")
        print(f"   Windows: {conv2['windows']}")
        print(f"   WSL:     {conv2['wsl']}")
    else:
        print(f"\n🧭 Scan dir: {scan_dir}")

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

    return run_dedupe(
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
