#!/usr/bin/env python3
# Script Name: divfolder.py
# ID: SCR-ID-20260320190500-XK7P4M2Q8D
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: divfolder

import argparse
import csv
import os
import re
import shutil
import signal
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def _sigint_handler(sig, frame):
    print("\n⛔ Cancelled (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
LOG_DIR = SCRIPT_DIR / "logs"
DEFAULTS_CSV = LOG_DIR / "defaults.csv"
TRANSFER_LOG_CSV = LOG_DIR / "transfer_log.csv"

_WIN_RE = re.compile(r"^([a-zA-Z]):[\\/](.*)$")
_WSL_RE = re.compile(r"^/mnt/([a-zA-Z])/(.*)$")
_NUMERIC_DIR_RE = re.compile(r"^\d+$")


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
        with DEFAULTS_CSV.open("r", encoding="utf-8", newline="") as f:
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
            with DEFAULTS_CSV.open("r", encoding="utf-8", newline="") as f:
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
# Transfer log helpers
# --------------------------------------------------
LOG_FIELDS = [
    "run_id",
    "timestamp",
    "script",
    "mode",
    "action",
    "status",
    "source_root",
    "parent_root",
    "src_path",
    "dst_path",
    "folder_name",
    "files_per_folder",
    "recursive",
    "extensions",
    "pad_width",
    "start_at",
    "message",
]


def ensure_transfer_log():
    ensure_logs()
    if not TRANSFER_LOG_CSV.exists():
        with TRANSFER_LOG_CSV.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=LOG_FIELDS)
            w.writeheader()


def clear_transfer_log():
    ensure_logs()
    with TRANSFER_LOG_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=LOG_FIELDS)
        w.writeheader()


def append_log_row(row: dict):
    ensure_transfer_log()
    normalized = {k: row.get(k, "") for k in LOG_FIELDS}
    with TRANSFER_LOG_CSV.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=LOG_FIELDS)
        w.writerow(normalized)


def read_transfer_log_rows() -> list[dict]:
    if not TRANSFER_LOG_CSV.exists():
        return []
    try:
        with TRANSFER_LOG_CSV.open("r", newline="", encoding="utf-8") as f:
            return list(csv.DictReader(f))
    except Exception:
        return []


def make_run_id() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def group_rows_by_run(rows: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        run_id = row.get("run_id", "").strip()
        if run_id:
            grouped[run_id].append(row)
    return dict(grouped)


def summarize_runs(rows: list[dict]) -> list[dict]:
    grouped = group_rows_by_run(rows)
    out = []

    for run_id, run_rows in grouped.items():
        file_rows = [r for r in run_rows if r.get("action") in ("move", "copy", "plan")]
        if not file_rows:
            file_rows = run_rows

        first = run_rows[0]
        timestamp = min((r.get("timestamp", "") for r in run_rows if r.get("timestamp")), default="")
        mode = first.get("mode", "")
        source_root = first.get("source_root", "")
        parent_root = first.get("parent_root", "")
        ok_count = sum(1 for r in file_rows if r.get("status") == "ok")
        fail_count = sum(1 for r in file_rows if r.get("status") not in ("", "ok"))
        out.append(
            {
                "run_id": run_id,
                "timestamp": timestamp,
                "mode": mode,
                "source_root": source_root,
                "parent_root": parent_root,
                "entries": len(file_rows),
                "ok": ok_count,
                "fail": fail_count,
            }
        )

    out.sort(key=lambda x: x["timestamp"])
    return out


def list_runs():
    rows = read_transfer_log_rows()
    if not rows:
        print(colorize("❌ No transfer log history found.", RED))
        return 2

    runs = summarize_runs(rows)
    if not runs:
        print(colorize("❌ No runs found in log.", RED))
        return 2

    print("\n=== Run History ===")
    for r in runs:
        print(
            f"{r['run_id']} | {r['timestamp']} | "
            f"mode={r['mode']} | entries={r['entries']} | ok={r['ok']} | fail={r['fail']}"
        )
        print(f"  source: {r['source_root']}")
        print(f"  parent: {r['parent_root']}")
    return 0


def get_latest_run_ids(rows: list[dict], count: int) -> list[str]:
    runs = summarize_runs(rows)
    if not runs:
        return []
    runs_sorted = sorted(runs, key=lambda x: x["timestamp"])
    return [r["run_id"] for r in runs_sorted[-count:]]


def remove_empty_dirs_bottom_up(root: Path):
    if not root.exists() or not root.is_dir():
        return
    for dirpath, dirnames, _ in os.walk(root, topdown=False):
        for d in dirnames:
            p = Path(dirpath) / d
            try:
                p.rmdir()
                print(colorize(f"RMDIR: {p}", BLUE))
            except OSError:
                pass


# --------------------------------------------------
# File helpers
# --------------------------------------------------
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


def should_include_file(path: Path, exts: set[str], include_hidden: bool) -> bool:
    if not include_hidden and path.name.startswith("."):
        return False
    if not exts:
        return True
    return path.suffix.lower().lstrip(".") in exts


def collect_files(src: Path, recursive: bool, exts: set[str], include_hidden: bool) -> list[Path]:
    out: list[Path] = []

    if recursive:
        for root, dirnames, filenames in os.walk(src):
            if not include_hidden:
                dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            base = Path(root)
            for name in filenames:
                p = (base / name).resolve()
                if should_include_file(p, exts, include_hidden):
                    out.append(p)
    else:
        for p in src.iterdir():
            if p.is_file():
                rp = p.resolve()
                if should_include_file(rp, exts, include_hidden):
                    out.append(rp)

    out.sort(key=lambda x: str(x).lower())
    return out


def split_into_chunks(items: list[Path], chunk_size: int) -> list[list[Path]]:
    return [items[i:i + chunk_size] for i in range(0, len(items), chunk_size)]


# --------------------------------------------------
# Numeric folder helpers
# --------------------------------------------------
def list_numeric_sibling_dirs(parent: Path, exclude: Path | None = None) -> list[Path]:
    out = []
    for child in parent.iterdir():
        try:
            if exclude is not None and child.resolve() == exclude.resolve():
                continue
            if child.is_dir() and _NUMERIC_DIR_RE.match(child.name):
                out.append(child.resolve())
        except Exception:
            continue
    out.sort(key=lambda p: int(p.name))
    return out


def format_numeric_name(n: int, pad_width: int) -> str:
    if pad_width > 0:
        return str(n).zfill(pad_width)
    return str(n)


def build_used_numeric_values(parent: Path) -> set[int]:
    used: set[int] = set()
    for child in parent.iterdir():
        try:
            if child.is_dir() and _NUMERIC_DIR_RE.match(child.name):
                used.add(int(child.name))
        except Exception:
            continue
    return used


def next_available_number(parent: Path, used_numbers: set[int], start_at: int | None) -> int:
    n = start_at if start_at is not None else 0
    while n in used_numbers or (parent / str(n)).exists():
        n += 1
    return n


# --------------------------------------------------
# Transfer helpers
# --------------------------------------------------
def copy_or_move_file(src_file: Path, dst_file: Path, mode: str):
    if mode == "copy":
        shutil.copy2(src_file, dst_file)
    else:
        shutil.move(str(src_file), str(dst_file))


def plan_and_execute(
    src: Path,
    files: list[Path],
    files_per_folder: int,
    mode: str,
    recursive: bool,
    pad_width: int,
    start_at: int | None,
    do_action: bool,
    exts: set[str],
    run_id: str,
) -> tuple[int, int]:
    parent = src.parent
    used_numbers = build_used_numeric_values(parent)
    next_n = next_available_number(parent, used_numbers, start_at)

    groups = split_into_chunks(files, files_per_folder)
    folder_count = 0
    file_count = 0
    ext_text = ",".join(sorted(exts)) if exts else "ALL"

    for group in groups:
        while (
            next_n in used_numbers
            or (parent / str(next_n)).exists()
            or (parent / format_numeric_name(next_n, pad_width)).exists()
        ):
            next_n += 1

        folder_name = format_numeric_name(next_n, pad_width)
        dst_dir = parent / folder_name
        used_numbers.add(next_n)
        next_n += 1
        folder_count += 1

        print(colorize(f"\n📁 Folder: {dst_dir}", BLUE))
        print(f"Files: {len(group)}")

        if do_action:
            dst_dir.mkdir(parents=True, exist_ok=False)

        for src_file in group:
            dst_file = dst_dir / src_file.name
            final_dst = unique_dest(dst_file) if do_action else dst_file

            line = (
                f"{mode.upper()}: {src_file} -> {final_dst}"
                if do_action else
                f"PLAN: {src_file} -> {final_dst}"
            )
            print(colorize(line, DEEP_GREEN if do_action else YELLOW))

            status = "ok"
            message = ""

            if do_action:
                try:
                    final_dst.parent.mkdir(parents=True, exist_ok=True)
                    copy_or_move_file(src_file, final_dst, mode)
                except Exception as e:
                    status = "fail"
                    message = str(e)
                    print(colorize(f"FAIL: {src_file} -> {final_dst} -> {e}", RED))
            else:
                final_dst = dst_file

            append_log_row(
                {
                    "run_id": run_id,
                    "timestamp": datetime.now().isoformat(timespec="seconds"),
                    "script": SCRIPT_PATH.name,
                    "mode": mode if do_action else "dry-run",
                    "action": mode if do_action else "plan",
                    "status": status,
                    "source_root": str(src),
                    "parent_root": str(parent),
                    "src_path": str(src_file),
                    "dst_path": str(final_dst),
                    "folder_name": folder_name,
                    "files_per_folder": str(files_per_folder),
                    "recursive": str(recursive),
                    "extensions": ext_text,
                    "pad_width": str(pad_width),
                    "start_at": "" if start_at is None else str(start_at),
                    "message": message,
                }
            )

            file_count += 1

    return folder_count, file_count


# --------------------------------------------------
# Undo helpers
# --------------------------------------------------
def build_undo_targets(rows: list[dict], run_id: str) -> list[dict]:
    targets = []
    for row in rows:
        if row.get("run_id") != run_id:
            continue
        if row.get("status") != "ok":
            continue
        action = row.get("action")
        if action not in ("move", "copy"):
            continue
        targets.append(row)
    return targets


def preview_undo_rows(rows: list[dict], run_id: str):
    targets = build_undo_targets(rows, run_id)
    if not targets:
        print(colorize(f"❌ No undoable entries found for run_id: {run_id}", RED))
        return 2

    print(f"\n=== Undo Preview: {run_id} ===")
    print(f"Entries: {len(targets)}")
    for row in reversed(targets[:50]):
        action = row.get("action", "")
        src = row.get("src_path", "")
        dst = row.get("dst_path", "")
        if action == "move":
            print(f"UNDO MOVE: {dst} -> {src}")
        elif action == "copy":
            print(f"UNDO COPY: delete {dst}")
    if len(targets) > 50:
        print(f"... and {len(targets) - 50} more")
    return 0


def undo_single_run(rows: list[dict], run_id: str, dry_run: bool) -> int:
    targets = build_undo_targets(rows, run_id)

    if not targets:
        print(colorize(f"❌ No undoable entries found for run_id: {run_id}", RED))
        return 2

    first = targets[0]
    source_root = Path(first.get("source_root", "")) if first.get("source_root") else None
    parent_root = Path(first.get("parent_root", "")) if first.get("parent_root") else None

    print(colorize(f"\n🔁 Undoing run: {run_id}", YELLOW))
    print(f"Entries: {len(targets)}")
    print(f"Mode:    {'DRY-RUN' if dry_run else 'LIVE'}")

    restored = 0
    removed = 0
    failed = 0
    skipped = 0

    for row in reversed(targets):
        action = row.get("action", "")
        src = Path(row.get("src_path", ""))
        dst = Path(row.get("dst_path", ""))

        try:
            if action == "move":
                if not dst.exists():
                    print(colorize(f"SKIP (missing dst): {dst}", RED))
                    skipped += 1
                    continue
                if src.exists():
                    print(colorize(f"SKIP (src exists): {src}", RED))
                    skipped += 1
                    continue

                print(colorize(f"UNDO MOVE: {dst} -> {src}", DEEP_GREEN if not dry_run else YELLOW))
                if not dry_run:
                    src.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(dst), str(src))
                restored += 1

            elif action == "copy":
                if not dst.exists():
                    print(colorize(f"SKIP (missing copy): {dst}", RED))
                    skipped += 1
                    continue

                print(colorize(f"UNDO COPY: delete {dst}", DEEP_GREEN if not dry_run else YELLOW))
                if not dry_run:
                    dst.unlink()
                removed += 1

        except Exception as e:
            print(colorize(f"FAIL: {dst} -> {e}", RED))
            failed += 1

    if not dry_run:
        if source_root and source_root.exists():
            remove_empty_dirs_bottom_up(source_root)
        if parent_root and parent_root.exists():
            remove_empty_dirs_bottom_up(parent_root)

    print(colorize("\n✅ Undo complete.", CYAN))
    print(f"Restored: {restored}")
    print(f"Removed:  {removed}")
    print(f"Skipped:  {skipped}")
    print(f"Failed:   {failed}")
    return 0


def handle_undo(args) -> int:
    rows = read_transfer_log_rows()
    if not rows:
        print(colorize("❌ No transfer log history found.", RED))
        return 2

    run_ids: list[str] = []

    if args.undo_run:
        run_ids = [args.undo_run]
    elif args.undo_last is not None:
        if args.undo_last <= 0:
            print(colorize("❌ --undo-last must be greater than 0.", RED))
            return 2
        run_ids = get_latest_run_ids(rows, args.undo_last)
        if not run_ids:
            print(colorize("❌ No runs available to undo.", RED))
            return 2
    elif args.undo:
        latest = get_latest_run_ids(rows, 1)
        if not latest:
            print(colorize("❌ No runs available to undo.", RED))
            return 2
        run_ids = latest
    else:
        print(colorize("❌ No undo action requested.", RED))
        return 2

    print("\nRuns selected for undo:")
    for rid in run_ids:
        print(f"  - {rid}")

    if args.undo_dry_run:
        for rid in run_ids:
            rc = preview_undo_rows(rows, rid)
            if rc != 0:
                return rc
        return 0

    if input(colorize("⚠️ Continue undo? (y/n): ", YELLOW)).strip().lower() != "y":
        print(colorize("❎ Aborted.", RED))
        return 0

    for rid in run_ids:
        rc = undo_single_run(rows, rid, dry_run=False)
        if rc != 0:
            return rc

    return 0


# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    prog = Path(sys.argv[0]).stem

    parser = argparse.ArgumentParser(
        prog=prog,
        description=(
            "Divide files from a source folder into new numbered sibling folders.\n\n"
            "Examples:\n"
            f"  {prog} -s /mnt/d/kep2/00 -n 100\n"
            f"  {prog} -s /mnt/d/kep2/00 -n 100 --move\n"
            f"  {prog} -s /mnt/d/kep2/00 -n 100 --copy --pad-width 2\n"
            f"  {prog} -s /mnt/d/kep2/00 -n 100 -r -e mp4 -e mkv\n"
            f"  {prog} --list-runs\n"
            f"  {prog} --undo\n"
            f"  {prog} --undo-run 20260320_174500\n"
            f"  {prog} --undo-last 3 --undo-dry-run\n\n"
            "Default extension behavior:\n"
            "- No -e/--ext flags: ALL file types\n"
            "- With -e/--ext flags: only those extensions\n\n"
            "Default mode is DRY RUN unless --move or --copy is supplied."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument("-s", "--source", help="Source directory containing files to divide")
    parser.add_argument("-n", "--number", type=int, help="How many files per new folder")
    parser.add_argument("-m", "--move", action="store_true", help="Actually move files")
    parser.add_argument("-c", "--copy", action="store_true", help="Actually copy files")
    parser.add_argument("-r", "--recursive", action="store_true", help="Recursively include files in subfolders")
    parser.add_argument(
        "-e", "--ext",
        action="append",
        help="Only include these extensions (repeatable). Default: ALL file types",
    )
    parser.add_argument("--pad-width", type=int, default=0, help="Zero-pad new numeric folder names, ex: 2 -> 01, 02")
    parser.add_argument("--start-at", type=int, help="Preferred numeric folder to start at; next free number at or above it is used")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files and hidden directories")
    parser.add_argument("--save-default-source", action="store_true", help="Save source directory as default_source in defaults.csv")
    parser.add_argument("--allow-empty-source", action="store_true", help="Do not error if source has no matching files")

    parser.add_argument("--clear-log", action="store_true", help="Clear the single CSV transfer log and exit")
    parser.add_argument("--list-runs", action="store_true", help="List logged runs from the CSV log and exit")

    parser.add_argument("--undo", action="store_true", help="Undo the most recent logged run")
    parser.add_argument("--undo-run", help="Undo a specific logged run_id")
    parser.add_argument("--undo-last", type=int, help="Undo the last N logged runs")
    parser.add_argument("--undo-dry-run", action="store_true", help="Preview what undo would do without changing files")

    if len(sys.argv) == 1:
        parser.print_help()
        return 0

    args = parser.parse_args()

    if args.move and args.copy:
        print(colorize("❌ Choose either --move or --copy, not both.", RED))
        return 2

    undo_flags_used = sum(
        1 for v in [args.undo, bool(args.undo_run), args.undo_last is not None] if v
    )
    if undo_flags_used > 1:
        print(colorize("❌ Use only one of: --undo, --undo-run, --undo-last", RED))
        return 2

    if args.clear_log:
        clear_transfer_log()
        print(colorize(f"✅ Cleared log: {TRANSFER_LOG_CSV}", CYAN))
        return 0

    if args.list_runs:
        return list_runs()

    if undo_flags_used:
        return handle_undo(args)

    action_mode = "dry-run"
    if args.move:
        action_mode = "move"
    elif args.copy:
        action_mode = "copy"

    source_raw = args.source
    if not source_raw:
        saved = load_default_source()
        if saved:
            source_raw = saved
        else:
            ensure_logs()
            entered = input("📝 Enter SOURCE directory:\n↳ ").strip()
            source_raw = entered

    src = normalize_path(source_raw).resolve()
    if not src.is_dir():
        print(colorize(f"❌ Invalid source directory: {src}", RED))
        return 2

    if args.save_default_source:
        save_default_source(str(src))

    files_per_folder = args.number
    if files_per_folder is None:
        try:
            files_per_folder = int(input("📝 How many files per new folder?\n↳ ").strip())
        except Exception:
            print(colorize("❌ Invalid number.", RED))
            return 2

    if files_per_folder <= 0:
        print(colorize("❌ --number must be greater than 0.", RED))
        return 2

    if args.pad_width < 0:
        print(colorize("❌ --pad-width cannot be negative.", RED))
        return 2

    exts = {e.lower().lstrip(".") for e in args.ext} if args.ext else set()

    parent = src.parent
    sibling_numeric_dirs = list_numeric_sibling_dirs(parent, exclude=src)

    files = collect_files(
        src=src,
        recursive=args.recursive,
        exts=exts,
        include_hidden=args.include_hidden,
    )

    if not files:
        if args.allow_empty_source:
            print(colorize("✅ Source has no matching files. Nothing to do.", CYAN))
            return 0
        print(colorize(f"❌ No matching files found in source: {src}", RED))
        return 2

    planned_groups = (len(files) + files_per_folder - 1) // files_per_folder
    run_id = make_run_id()

    print("\n📂 plan")
    print(f"Run ID:        {run_id}")
    print(f"Source:        {src}")
    print(f"Parent:        {parent}")
    print(f"Files found:   {len(files)}")
    print(f"Per folder:    {files_per_folder}")
    print(f"New folders:   {planned_groups}")
    print(f"Mode:          {action_mode.upper()}")
    print(f"Recursive:     {'YES' if args.recursive else 'NO'}")
    print(f"Extensions:    {', '.join(sorted(exts)) if exts else 'ALL'}")
    print(f"Pad width:     {args.pad_width}")
    print(f"Start at:      {args.start_at if args.start_at is not None else 'AUTO'}")
    print(f"Hidden:        {'INCLUDE' if args.include_hidden else 'SKIP'}")
    print(f"Numeric sibs:  {len(sibling_numeric_dirs)}")
    for i, s in enumerate(sibling_numeric_dirs[:12], 1):
        print(f"  {i:>2}. {s}")
    if len(sibling_numeric_dirs) > 12:
        print(f"  ... and {len(sibling_numeric_dirs) - 12} more")
    print(f"Log file:      {TRANSFER_LOG_CSV}")
    print()

    if action_mode in ("move", "copy"):
        prompt = colorize(
            f"⚠️ About to {action_mode.upper()} files into new numbered sibling folders. Continue? (y/n): ",
            YELLOW,
        )
        if input(prompt).strip().lower() != "y":
            print(colorize("❎ Aborted.", RED))
            return 0

    folder_count, file_count = plan_and_execute(
        src=src,
        files=files,
        files_per_folder=files_per_folder,
        mode="copy" if action_mode == "copy" else "move",
        recursive=args.recursive,
        pad_width=args.pad_width,
        start_at=args.start_at,
        do_action=(action_mode in ("move", "copy")),
        exts=exts,
        run_id=run_id,
    )

    verb = "Planned" if action_mode == "dry-run" else ("Copied" if action_mode == "copy" else "Moved")
    print(colorize(f"\n✅ Done. {verb} {file_count} file(s) across {folder_count} folder(s).", CYAN))
    print(f"Run ID: {run_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
