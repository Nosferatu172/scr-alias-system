#!/usr/bin/env python3
# Script Name: dedupe4car.py
# ID: SCR-ID-20260320153000-DQ8F7L2P1X
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dedupe4cary

import argparse
import csv
import hashlib
import os
import re
import shutil
import signal
import sys
from collections import defaultdict
from pathlib import Path


def _sigint_handler(sig, frame):
    print("\n⛔ Cancelled (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
LOG_DIR = SCRIPT_DIR / "logs"
DEFAULTS_CSV = LOG_DIR / "defaults.csv"

_WIN_RE = re.compile(r"^([a-zA-Z]):[\\/](.*)$")
_WSL_RE = re.compile(r"^/mnt/([a-zA-Z])/(.*)$")


# --------------------------------------------------
# Color helpers
# --------------------------------------------------
def _supports_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    try:
        return sys.stdout.isatty()
    except Exception:
        return False


_COLOR_ON = _supports_color()

RESET = "\033[0m" if _COLOR_ON else ""
DEEP_GREEN = "\033[38;5;22m" if _COLOR_ON else ""
CYAN = "\033[36m" if _COLOR_ON else ""
RED = "\033[31m" if _COLOR_ON else ""
YELLOW = "\033[33m" if _COLOR_ON else ""
BLUE = "\033[34m" if _COLOR_ON else ""


def colorize(text: str, color: str) -> str:
    if not _COLOR_ON or not color:
        return text
    return f"{color}{text}{RESET}"


# --------------------------------------------------
# Environment / path helpers
# --------------------------------------------------
def get_effective_cwd() -> Path:
    caller = os.environ.get("SCR_CALLER_PWD", "").strip()
    if caller and Path(caller).is_dir():
        return Path(caller).resolve()
    return Path.cwd()


def is_wsl() -> bool:
    try:
        return "microsoft" in os.uname().release.lower()
    except Exception:
        return False


def normalize_path(p: str) -> Path:
    p = (p or "").strip().strip('"').strip("'")
    if not p:
        return Path()

    p = os.path.expandvars(os.path.expanduser(p))

    if is_wsl():
        m = _WIN_RE.match(p.replace("/", "\\"))
        if m:
            drive = m.group(1).lower()
            rest = m.group(2).replace("\\", "/")
            return Path(f"/mnt/{drive}/{rest}")
        return Path(p)

    m = _WSL_RE.match(p)
    if m:
        drive = m.group(1).upper()
        rest = m.group(2).replace("/", "\\")
        return Path(f"{drive}:\\{rest}")

    return Path(p)


def ensure_logs():
    LOG_DIR.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------
# Defaults CSV helpers
# --------------------------------------------------
def load_default_source() -> str | None:
    if not DEFAULTS_CSV.exists():
        return None
    try:
        with DEFAULTS_CSV.open("r", encoding="utf-8") as f:
            r = csv.DictReader(f)
            for row in r:
                if row.get("key") == "default_source":
                    return row.get("value")
    except Exception:
        return None
    return None


def save_default_source(path_str: str):
    ensure_logs()
    rows = []

    if DEFAULTS_CSV.exists():
        try:
            with DEFAULTS_CSV.open("r", encoding="utf-8") as f:
                r = csv.DictReader(f)
                rows = list(r)
        except Exception:
            rows = []

    updated = False
    for row in rows:
        if row.get("key") == "default_source":
            row["value"] = path_str
            updated = True

    if not updated:
        rows.append({"key": "default_source", "value": path_str})

    with DEFAULTS_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["key", "value"])
        w.writeheader()
        for row in rows:
            w.writerow(row)


# --------------------------------------------------
# Scan / hash helpers
# --------------------------------------------------
def hash_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def scan_files(root: Path) -> dict[str, list[tuple[Path, int]]]:
    """
    Return:
      {
        "filename.ext": [(full_path, size), ...]
      }
    Key is case-insensitive filename.
    """
    found: dict[str, list[tuple[Path, int]]] = defaultdict(list)

    for dirpath, _, filenames in os.walk(root):
        base = Path(dirpath)
        for name in filenames:
            p = (base / name).resolve()
            try:
                size = p.stat().st_size
            except Exception:
                print(colorize(f"SKIP (stat failed): {p}", RED))
                continue
            found[name.lower()].append((p, size))

    return dict(found)


def build_match_groups(
    items: list[tuple[Path, int]],
    use_hash: bool,
) -> dict[tuple, list[Path]]:
    """
    Group files by:
      - size only, or
      - size + sha256
    """
    grouped: dict[tuple, list[Path]] = defaultdict(list)

    for p, size in items:
        if use_hash:
            try:
                digest = hash_file(p)
            except Exception as e:
                print(colorize(f"SKIP (hash failed): {p} -> {e}", RED))
                continue
            key = (size, digest)
        else:
            key = (size,)

        grouped[key].append(p)

    return dict(grouped)


def find_sibling_dirs(source_dir: Path) -> list[Path]:
    parent = source_dir.parent
    out = []

    for child in parent.iterdir():
        try:
            if child.is_dir() and child.resolve() != source_dir.resolve():
                out.append(child.resolve())
        except Exception:
            continue

    out.sort(key=lambda p: p.name.lower())
    return out


def unique_dest(dst: Path) -> Path:
    if not dst.exists():
        return dst

    stem = dst.stem
    suffix = dst.suffix
    i = 1
    while True:
        cand = dst.with_name(f"{stem}_{i}{suffix}")
        if not cand.exists():
            return cand
        i += 1


def move_to_quarantine(file_path: Path, base_root: Path, quarantine_root: Path) -> Path:
    """
    Preserve relative structure under quarantine_root if possible.
    """
    try:
        rel = file_path.relative_to(base_root)
        dst = quarantine_root / rel
    except Exception:
        dst = quarantine_root / file_path.name

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst = unique_dest(dst)
    shutil.move(str(file_path), str(dst))
    return dst


def remove_empty_dirs_bottom_up(root: Path):
    for dirpath, dirnames, _ in os.walk(root, topdown=False):
        for d in dirnames:
            p = Path(dirpath) / d
            try:
                p.rmdir()
                print(colorize(f"RMDIR: {p}", BLUE))
            except OSError:
                pass


# --------------------------------------------------
# Duplicate detection
# --------------------------------------------------
def find_duplicates_between_source_and_siblings(
    source_dir: Path,
    sibling_dirs: list[Path],
    use_hash: bool,
) -> list[dict]:
    print(colorize("\n🔍 Scanning source...", BLUE))
    source_map = scan_files(source_dir)

    print(colorize("🔍 Scanning siblings...", BLUE))
    combined_sibling_map: dict[str, list[tuple[Path, int]]] = defaultdict(list)
    sibling_origin: dict[str, list[tuple[Path, int, Path]]] = defaultdict(list)

    for sib in sibling_dirs:
        scanned = scan_files(sib)
        for name_key, entries in scanned.items():
            for p, size in entries:
                combined_sibling_map[name_key].append((p, size))
                sibling_origin[name_key].append((p, size, sib))

    duplicates: list[dict] = []

    for name_key, src_entries in source_map.items():
        other_entries = combined_sibling_map.get(name_key, [])
        if not other_entries:
            continue

        src_grouped = build_match_groups(src_entries, use_hash=use_hash)
        other_grouped = build_match_groups(other_entries, use_hash=use_hash)

        for key, src_paths in src_grouped.items():
            other_paths = other_grouped.get(key, [])
            if not other_paths:
                continue

            duplicates.append(
                {
                    "name": name_key,
                    "match_key": key,
                    "source_paths": sorted(src_paths, key=lambda p: str(p).lower()),
                    "other_paths": sorted(other_paths, key=lambda p: str(p).lower()),
                }
            )

    return duplicates


# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    prog = Path(sys.argv[0]).stem

    parser = argparse.ArgumentParser(
        prog=prog,
        description=(
            "Find duplicate filenames between a SOURCE directory and its sibling directories.\n"
            "Matching uses filename + size by default.\n"
            "Use --hash for filename + size + SHA256 verification.\n"
            "Default action is DRY RUN.\n"
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument(
        "-s", "--source",
        help="Source directory to compare against sibling directories",
    )
    parser.add_argument(
        "--hash",
        action="store_true",
        help="Verify duplicates with SHA256 (slower, safer)",
    )
    parser.add_argument(
        "-r", "--remove",
        action="store_true",
        help="Remove matched duplicates from the chosen side",
    )
    parser.add_argument(
        "-o", "--output-dir",
        help="Move matched duplicates to this directory for examination instead of deleting",
    )
    parser.add_argument(
        "--from-source",
        action="store_true",
        help="Act on duplicates found in the SOURCE directory",
    )
    parser.add_argument(
        "--from-others",
        action="store_true",
        help="Act on duplicates found in sibling directories",
    )
    parser.add_argument(
        "--save-default-source",
        action="store_true",
        help="Save the resolved source directory as default_source in defaults.csv",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Show full duplicate listing",
    )

    if len(sys.argv) == 1:
        parser.print_help()
        return 0

    args = parser.parse_args()

    if args.from_source and args.from_others:
        print(colorize("❌ Choose only one: --from-source or --from-others", RED))
        return 2

    if args.remove and args.output_dir:
        print(colorize("❌ Use either -r/--remove or -o/--output-dir, not both.", RED))
        return 2

    source_raw = args.source
    if not source_raw:
        saved = load_default_source()
        if saved:
            source_raw = saved
        else:
            ensure_logs()
            entered = input("📝 Enter SOURCE directory:\n↳ ").strip()
            source_raw = entered

    source_dir = normalize_path(source_raw).resolve()
    if not source_dir.is_dir():
        print(colorize(f"❌ Invalid source directory: {source_dir}", RED))
        return 2

    if args.save_default_source:
        save_default_source(str(source_dir))

    sibling_dirs = find_sibling_dirs(source_dir)
    if not sibling_dirs:
        print(colorize("❌ No sibling directories found next to source.", RED))
        return 2

    mode = "HASH" if args.hash else "SIZE"
    action = "DRY-RUN"
    if args.remove:
        action = "REMOVE"
    elif args.output_dir:
        action = "QUARANTINE"

    side = "SOURCE" if args.from_source else ("OTHERS" if args.from_others else "UNSET")

    print("\n📂 plan")
    print(f"Source:    {source_dir}")
    print(f"Siblings:  {len(sibling_dirs)}")
    for i, s in enumerate(sibling_dirs[:10], 1):
        print(f"  {i:>2}. {s}")
    if len(sibling_dirs) > 10:
        print(f"  ... and {len(sibling_dirs) - 10} more")
    print(f"Match:     filename + size + sha256" if args.hash else f"Match:     filename + size")
    print(f"Action:    {action}")
    print(f"Target:    {side}")
    if args.output_dir:
        print(f"Output:    {normalize_path(args.output_dir).resolve()}")
    print()

    duplicates = find_duplicates_between_source_and_siblings(
        source_dir=source_dir,
        sibling_dirs=sibling_dirs,
        use_hash=args.hash,
    )

    if not duplicates:
        print(colorize("\n✅ No duplicates found.", CYAN))
        return 0

    dup_name_count = len(duplicates)
    source_file_count = sum(len(d["source_paths"]) for d in duplicates)
    other_file_count = sum(len(d["other_paths"]) for d in duplicates)

    print("=== Duplicate Summary ===")
    print(f"Duplicate groups: {dup_name_count}")
    print(f"Source matches:   {source_file_count}")
    print(f"Other matches:    {other_file_count}")

    if args.preview:
        print("\n=== Preview ===")
        for idx, d in enumerate(duplicates, 1):
            print(f"\n[{idx}] {d['name']}")
            print("  SOURCE:")
            for p in d["source_paths"]:
                print(f"    - {p}")
            print("  OTHERS:")
            for p in d["other_paths"]:
                print(f"    - {p}")

    if not args.remove and not args.output_dir:
        print(colorize("\n✅ Dry run complete. No files changed.", CYAN))
        print("Use one of these:")
        print(f"  {prog} -s \"{source_dir}\" --from-source -r")
        print(f"  {prog} -s \"{source_dir}\" --from-others -r")
        print(f"  {prog} -s \"{source_dir}\" --from-source -o /path/to/examine")
        print(f"  {prog} -s \"{source_dir}\" --from-others -o /path/to/examine")
        return 0

    if not args.from_source and not args.from_others:
        print(colorize("❌ Action mode needs one target side: --from-source or --from-others", RED))
        return 2

    targets: list[Path] = []
    if args.from_source:
        for d in duplicates:
            targets.extend(d["source_paths"])
    else:
        for d in duplicates:
            targets.extend(d["other_paths"])

    # Deduplicate target paths
    seen = set()
    unique_targets = []
    for p in targets:
        s = str(p)
        if s not in seen:
            seen.add(s)
            unique_targets.append(p)

    if not unique_targets:
        print(colorize("❌ No target files resolved for action.", RED))
        return 2

    if args.output_dir:
        out_dir = normalize_path(args.output_dir).resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        print(colorize(f"\n⚠️ About to move {len(unique_targets)} file(s) to quarantine.", YELLOW))
        if input(colorize("Continue? (y/n): ", YELLOW)).strip().lower() != "y":
            print(colorize("❎ Aborted.", RED))
            return 0

        moved = 0
        failed = 0

        for p in unique_targets:
            try:
                base_root = source_dir if args.from_source else next(
                    (sib for sib in sibling_dirs if str(p).startswith(str(sib))),
                    p.parent
                )
                dst = move_to_quarantine(
                    file_path=p,
                    base_root=base_root,
                    quarantine_root=out_dir,
                )
                print(colorize(f"MOVE: {p} -> {dst}", DEEP_GREEN))
                moved += 1
            except Exception as e:
                print(colorize(f"FAIL: {p} -> {e}", RED))
                failed += 1

        if args.from_source:
            remove_empty_dirs_bottom_up(source_dir)
        else:
            for sib in sibling_dirs:
                remove_empty_dirs_bottom_up(sib)

        print(colorize(f"\n✅ Done. Moved: {moved}  Failed: {failed}", CYAN))
        return 0

    if args.remove:
        print(colorize(f"\n⚠️ About to delete {len(unique_targets)} file(s).", YELLOW))
        if input(colorize("Continue? (y/n): ", YELLOW)).strip().lower() != "y":
            print(colorize("❎ Aborted.", RED))
            return 0

        deleted = 0
        failed = 0

        for p in unique_targets:
            try:
                p.unlink()
                print(colorize(f"DELETE: {p}", DEEP_GREEN))
                deleted += 1
            except Exception as e:
                print(colorize(f"FAIL: {p} -> {e}", RED))
                failed += 1

        if args.from_source:
            remove_empty_dirs_bottom_up(source_dir)
        else:
            for sib in sibling_dirs:
                remove_empty_dirs_bottom_up(sib)

        print(colorize(f"\n✅ Done. Deleted: {deleted}  Failed: {failed}", CYAN))
        return 0

    print(colorize("❌ No valid action selected.", RED))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
