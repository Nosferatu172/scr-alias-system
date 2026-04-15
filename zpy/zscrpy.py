#!/usr/bin/env python3
# Script Name: zscr.py
# ID: SCR-ID-20260317130723-99IYOJDJLK
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: zscr

import sys
import argparse
import csv
import shutil
import signal
import string
import tarfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

# Best zip an spread script folder script i got so far.
# =======================
# Python version check
# =======================
REQUIRED_PYTHON = (3, 9)

if sys.version_info < REQUIRED_PYTHON:
    print(f"❌ Python {REQUIRED_PYTHON[0]}.{REQUIRED_PYTHON[1]}+ required.")
    raise SystemExit(1)


# =======================
# Ctrl+C handler
# =======================
def _sigint_handler(sig, frame):
    print("\n⛔ Cancelled (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# =======================
# Paths / config
# =======================
SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
LOG_DIR = SCRIPT_DIR / "logs"
CSV_PATH = LOG_DIR / "dirs.csv"

CSV_HEADERS = ["kind", "name", "path", "is_default", "enabled"]


# =======================
# CSV model
# =======================
@dataclass
class DirEntry:
    kind: str        # source | dest
    name: str
    path: str
    is_default: bool
    enabled: bool


# =======================
# Helpers
# =======================
def vprint(*args, silent: bool = False, **kwargs) -> None:
    if not silent:
        print(*args, **kwargs)


def safe_mkdir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def is_accessible_dir(p: Path) -> bool:
    try:
        return p.exists() and p.is_dir()
    except OSError:
        return False


def bool_to_str(b: bool) -> str:
    return "1" if b else "0"


def str_to_bool(s: str) -> bool:
    return str(s).strip().lower() in ("1", "true", "yes", "y", "on")


def suffix_from_index(n: int) -> str:
    """
    0->a, 1->b, ... 25->z, 26->aa, 27->ab ...
    """
    letters = []
    while True:
        n, r = divmod(n, 26)
        letters.append(string.ascii_lowercase[r])
        if n == 0:
            break
        n -= 1
    return "".join(reversed(letters))


def next_available_name(dest_dir: Path, base_filename: str) -> str:
    """
    If base_filename exists in dest_dir, returns base+suffix (a, b, ..., z, aa, ab...)
    Example:
      scr-2026-12-31.tar.gz
      scr-2026-12-31a.tar.gz
      scr-2026-12-31b.tar.gz
    """
    if not (dest_dir / base_filename).exists():
        return base_filename

    if base_filename.endswith(".tar.gz"):
        stem = base_filename[:-7]
    else:
        stem = base_filename.rsplit(".", 1)[0]

    i = 0
    while True:
        suf = suffix_from_index(i)
        candidate = f"{stem}{suf}.tar.gz"
        if not (dest_dir / candidate).exists():
            return candidate
        i += 1


def ensure_dest_root(dest_root: Path, label: str, silent: bool = False) -> bool:
    """
    Ensures the destination root exists (e.g. /mnt/i/scr).
    """
    try:
        if dest_root.exists():
            if dest_root.is_dir():
                return True
            print(f"⚠️ {label}: destination exists but is not a directory: {dest_root}")
            return False

        vprint(f"🛠️  {label}: creating destination root: {dest_root}", silent=silent)
        dest_root.mkdir(parents=True, exist_ok=True)
        return dest_root.is_dir()
    except Exception as ex:
        print(f"⚠️ {label}: failed to create destination root {dest_root}: {ex}")
        return False


def mount_root_ok(dest_root: Path) -> bool:
    """
    For /mnt/<drive>/scr, verify /mnt/<drive> exists first.
    """
    parts = dest_root.parts
    if len(parts) >= 3 and parts[1] == "mnt":
        mnt_drive = Path("/", parts[1], parts[2])  # /mnt/i
        try:
            return mnt_drive.exists() and mnt_drive.is_dir()
        except OSError:
            return False
    return True


def rotate_swap_tarballs(swap: Path, new_archives: Path, dry_run: bool, label: str, silent: bool = False) -> None:
    """
    Move ALL *.tar.gz files from swap -> new-archives, resolving name conflicts.
    """
    try:
        existing = sorted(
            p for p in swap.iterdir()
            if p.is_file() and p.name.lower().endswith(".tar.gz")
        )
    except FileNotFoundError:
        existing = []

    if not existing:
        return

    for old_file in existing:
        dest_name = next_available_name(new_archives, old_file.name)
        dest_path = new_archives / dest_name

        if dry_run:
            vprint(f"DRY RUN: would move {old_file} -> {dest_path}", silent=silent)
            continue

        try:
            shutil.move(str(old_file), str(dest_path))
            vprint(f"📦 {label}: moved swap -> new-archives/{dest_path.name}", silent=silent)
        except Exception as ex:
            print(f"⚠️ {label}: failed to move {old_file.name} from swap: {ex}")


def print_progress(current: int, total: int, prefix: str = "Progress", width: int = 40) -> None:
    """
    Simple dependency-free progress bar.
    Tracks item count, not byte count.
    """
    if total <= 0:
        total = 1

    ratio = current / total
    filled = int(width * ratio)
    bar = "#" * filled + "-" * (width - filled)
    percent = ratio * 100

    print(f"\r{prefix}: [{bar}] {current}/{total} ({percent:5.1f}%)", end="", flush=True)

    if current >= total:
        print()


# =======================
# CSV handling
# =======================
def ensure_default_config() -> None:
    safe_mkdir(LOG_DIR)

    if CSV_PATH.exists():
        return

    entries = [
        DirEntry("source", "main", "/mnt/c/scr", True, True),
    ]

    for d in ["/mnt/d/scr", "/mnt/e/scr", "/mnt/f/scr", "/mnt/g/scr", "/mnt/h/scr", "/mnt/i/scr"]:
        label = Path(d).parts[2] if len(Path(d).parts) > 2 else Path(d).name
        entries.append(DirEntry("dest", label, d, False, True))

    write_entries(entries)
    print(f"✅ Created default config: {CSV_PATH}")


def read_entries() -> list[DirEntry]:
    ensure_default_config()
    entries: list[DirEntry] = []

    with CSV_PATH.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            entries.append(
                DirEntry(
                    kind=r.get("kind", "").strip(),
                    name=r.get("name", "").strip(),
                    path=r.get("path", "").strip(),
                    is_default=str_to_bool(r.get("is_default", "0")),
                    enabled=str_to_bool(r.get("enabled", "0")),
                )
            )

    entries = [e for e in entries if e.kind in ("source", "dest") and e.path]

    sources = [e for e in entries if e.kind == "source" and e.enabled]
    if sources and not any(e.is_default for e in sources):
        sources[0].is_default = True
        write_entries(entries)

    return entries


def write_entries(entries: list[DirEntry]) -> None:
    safe_mkdir(LOG_DIR)
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=CSV_HEADERS)
        w.writeheader()
        for e in entries:
            w.writerow({
                "kind": e.kind,
                "name": e.name,
                "path": e.path,
                "is_default": bool_to_str(e.is_default),
                "enabled": bool_to_str(e.enabled),
            })


# =======================
# Listing
# =======================
def list_entries(entries: list[DirEntry]) -> None:
    print(f"\nConfig: {CSV_PATH}\n")

    print("Sources:")
    for i, e in enumerate(entries):
        if e.kind != "source":
            continue
        flags = []
        if e.is_default:
            flags.append("default")
        if not e.enabled:
            flags.append("disabled")
        tag = f" ({', '.join(flags)})" if flags else ""
        print(f"  [{i}] {e.name}: {e.path}{tag}")

    print("\nDestinations:")
    for i, e in enumerate(entries):
        if e.kind != "dest":
            continue
        flags = []
        if not e.enabled:
            flags.append("disabled")
        tag = f" ({', '.join(flags)})" if flags else ""
        print(f"  [{i}] {e.name}: {e.path}{tag}")
    print("")


# =======================
# Edit menu
# =======================
def pick_index(prompt: str, entries: list[DirEntry]) -> int | None:
    try:
        s = input(prompt).strip()
    except KeyboardInterrupt:
        raise SystemExit(130)

    if s == "":
        return None
    if not s.isdigit():
        return None

    i = int(s)
    return i if 0 <= i < len(entries) else None


def normalize_default_source(entries: list[DirEntry]) -> None:
    enabled_sources = [e for e in entries if e.kind == "source" and e.enabled]
    if not enabled_sources:
        return

    defaults = [e for e in enabled_sources if e.is_default]
    if len(defaults) == 0:
        enabled_sources[0].is_default = True
    elif len(defaults) > 1:
        first = defaults[0]
        for e in enabled_sources:
            e.is_default = (e is first)


def edit_menu(entries: list[DirEntry]) -> None:
    while True:
        list_entries(entries)
        print("Edit menu:")
        print("  1) Edit name/path")
        print("  2) Toggle enable")
        print("  3) Set default source")
        print("  4) Add entry")
        print("  5) Remove entry")
        print("  6) Save & exit")
        print("  7) Reload from disk")
        print("  8) Quit without saving")
        choice = input("> ").strip()

        if choice == "1":
            idx = pick_index("Index to edit: ", entries)
            if idx is None:
                continue
            e = entries[idx]
            e.name = input(f"Name [{e.name}]: ").strip() or e.name
            e.path = input(f"Path [{e.path}]: ").strip() or e.path

        elif choice == "2":
            idx = pick_index("Index to toggle: ", entries)
            if idx is None:
                continue

            entries[idx].enabled = not entries[idx].enabled

            if entries[idx].kind == "source" and not entries[idx].enabled:
                entries[idx].is_default = False

            normalize_default_source(entries)

        elif choice == "3":
            idx = pick_index("Source index to set default: ", entries)
            if idx is None or entries[idx].kind != "source":
                print("❌ Not a source entry.")
                continue
            for e in entries:
                if e.kind == "source":
                    e.is_default = False
            entries[idx].is_default = True
            entries[idx].enabled = True

        elif choice == "4":
            kind = input("Kind (source/dest): ").strip().lower()
            if kind not in ("source", "dest"):
                print("❌ Invalid kind.")
                continue

            name = input("Name: ").strip()
            path = input("Path: ").strip()
            if not path:
                print("❌ Path is required.")
                continue

            entries.append(
                DirEntry(
                    kind=kind,
                    name=name or Path(path).name,
                    path=path,
                    is_default=(kind == "source" and not any(e.kind == "source" and e.enabled for e in entries)),
                    enabled=True,
                )
            )
            normalize_default_source(entries)

        elif choice == "5":
            idx = pick_index("Index to remove: ", entries)
            if idx is None:
                continue
            victim = entries[idx]
            confirm = input(f"Delete [{idx}] {victim.kind}:{victim.name}? (y/N): ").strip().lower()
            if confirm == "y":
                entries.pop(idx)
                normalize_default_source(entries)

        elif choice == "6":
            normalize_default_source(entries)
            write_entries(entries)
            print("✅ Saved.")
            return

        elif choice == "7":
            entries[:] = read_entries()
            print("↩️ Reloaded.")

        elif choice == "8":
            print("Exiting without saving.")
            return


# =======================
# Archive helpers
# =======================
def build_archive_name() -> str:
    today = datetime.now().strftime("%Y-%m-%d")
    return f"scr-{today}.tar.gz"


def find_latest_archive(source_dir: Path) -> Path | None:
    try:
        archives = sorted(
            [p for p in source_dir.iterdir() if p.is_file() and p.name.lower().endswith(".tar.gz")],
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
    except Exception:
        return None

    return archives[0] if archives else None


def create_archive(source_dir: Path, archive_path: Path, dry_run: bool = False, silent: bool = False) -> Path | None:
    vprint(f"Archiving: {source_dir}", silent=silent)

    if dry_run:
        vprint(f"DRY RUN: would create {archive_path}", silent=silent)
        return archive_path

    try:
        items = list(source_dir.iterdir())
    except Exception as ex:
        print(f"❌ Failed to read source directory {source_dir}: {ex}")
        return None

    total = len(items)

    try:
        with tarfile.open(archive_path, "w:gz") as tar:
            for idx, item in enumerate(items, start=1):
                try:
                    if item.resolve() == archive_path.resolve():
                        if not silent:
                            print_progress(idx, total, prefix="Archiving")
                        continue
                except Exception:
                    pass

                try:
                    tar.add(item, arcname=item.name)
                except Exception as ex:
                    print(f"⚠️ Failed to archive {item}: {ex}")

                if not silent:
                    print_progress(idx, total, prefix="Archiving")
    except Exception as ex:
        print(f"❌ Failed to create archive {archive_path}: {ex}")
        return None

    vprint(f"✅ Created archive: {archive_path}", silent=silent)
    return archive_path


def spread_archive(archive_path: Path, dests: list[DirEntry], dry_run: bool = False, silent: bool = False) -> None:
    if archive_path is None:
        print("❌ No archive available to spread.")
        return

    if not dry_run and not archive_path.exists():
        print(f"❌ Archive does not exist: {archive_path}")
        return

    for d in dests:
        base = Path(d.path)

        if not mount_root_ok(base):
            print(f"⚠️ {d.name}: mount root not present for {base} (e.g. /mnt/i missing). Skipping.")
            continue

        if not is_accessible_dir(base):
            if dry_run:
                vprint(f"DRY RUN: would create destination root: {base}", silent=silent)
            else:
                if not ensure_dest_root(base, d.name, silent=silent):
                    print(f"⚠️ {d.name}: still not accessible after create attempt: {base}")
                    continue

        swap = base / "swap"
        new_archives = base / "new-archives"

        if dry_run:
            vprint(f"DRY RUN: would ensure {swap} and {new_archives}", silent=silent)
        else:
            safe_mkdir(swap)
            safe_mkdir(new_archives)

        rotate_swap_tarballs(swap, new_archives, dry_run=dry_run, label=d.name, silent=silent)

        swap_file = swap / archive_path.name

        if dry_run:
            vprint(f"DRY RUN: would copy {archive_path} -> {swap_file}", silent=silent)
        else:
            try:
                shutil.copy2(archive_path, swap_file)
                vprint(f"➡️  {d.name}: copied -> {swap_file}", silent=silent)
            except Exception as ex:
                print(f"⚠️ {d.name}: copy failed: {ex}")


# =======================
# Backup logic
# =======================
def run_backup(
    entries: list[DirEntry],
    dry_run: bool = False,
    silent: bool = False,
    zip_only: bool = False,
    spread_only: bool = False,
) -> None:
    if zip_only and spread_only:
        print("❌ Cannot use --zip-only and --spread-only together.")
        return

    sources = [e for e in entries if e.kind == "source" and e.enabled]
    dests = [e for e in entries if e.kind == "dest" and e.enabled]

    src = next((e for e in sources if e.is_default), None)
    if not src:
        print("❌ No default source.")
        return

    source_dir = Path(src.path)
    if not is_accessible_dir(source_dir):
        print(f"❌ Source not accessible: {source_dir}")
        return

    archive_name = build_archive_name()
    archive_path = source_dir / archive_name

    if spread_only:
        latest = find_latest_archive(source_dir)
        if latest is None:
            print(f"❌ No existing .tar.gz archive found in source directory: {source_dir}")
            return

        vprint(f"📦 Using existing archive for spread-only mode: {latest}", silent=silent)
        spread_archive(latest, dests, dry_run=dry_run, silent=silent)
        vprint("✅ Spread complete.", silent=silent)
        return

    created_archive = create_archive(
        source_dir=source_dir,
        archive_path=archive_path,
        dry_run=dry_run,
        silent=silent,
    )

    if created_archive is None:
        return

    if zip_only:
        vprint("✅ Zip-only complete.", silent=silent)
        return

    spread_archive(created_archive, dests, dry_run=dry_run, silent=silent)
    vprint("✅ Backup complete.", silent=silent)


# =======================
# CLI
# =======================
def main():
    p = argparse.ArgumentParser(
        prog="zipandspreadscr",
        description=(
            "Archive a source /scr into scr-YYYY-MM-DD.tar.gz, "
            "stage to each dest /mnt/c/scr/swap, and rotate old swap into "
            "/mnt/c/scr/new-archives with a/b/.../aa suffixes."
        )
    )
    p.add_argument("-l", "--list", action="store_true", help="List config entries")
    p.add_argument("-e", "--edit", action="store_true", help="Edit config entries")
    p.add_argument("-n", "--dry-run", action="store_true", help="Show what would happen without writing files")
    p.add_argument("--silent", action="store_true", help="Suppress normal output; only show errors")
    p.add_argument("--zip-only", action="store_true", help="Only create/update the archive in the source directory")
    p.add_argument("--spread-only", action="store_true", help="Only spread the newest existing archive to destinations")
    args = p.parse_args()

    entries = read_entries()

    if args.list:
        list_entries(entries)
    elif args.edit:
        edit_menu(entries)
    else:
        run_backup(
            entries,
            dry_run=args.dry_run,
            silent=args.silent,
            zip_only=args.zip_only,
            spread_only=args.spread_only,
        )


if __name__ == "__main__":
    main()
