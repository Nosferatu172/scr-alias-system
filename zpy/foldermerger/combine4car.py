#!/usr/bin/env python3
# Script Name: combine4car.py
# ID: SCR-ID-20260317130650-TXJ51BY2VC
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: combine4cary

import argparse
import csv
import glob
import os
import re
import shutil
import signal
import sys
import time
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
# Progress helpers
# --------------------------------------------------
def format_bytes(num: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB", "PB"]
    n = float(num)
    for unit in units:
        if n < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(n)}{unit}"
            return f"{n:.1f}{unit}"
        n /= 1024.0
    return f"{num}B"


def make_progress_bar(done: int, total: int, width: int = 20) -> str:
    if total <= 0:
        return "[" + ("-" * width) + "]"
    ratio = min(max(done / total, 0.0), 1.0)
    filled = int(width * ratio)
    return "[" + ("#" * filled) + ("-" * (width - filled)) + "]"


class ProgressTracker:
    def __init__(self, total_bytes: int, enabled: bool = True):
        self.total_bytes = max(total_bytes, 0)
        self.done_bytes = 0
        self.enabled = enabled and sys.stdout.isatty()
        self.start_time = time.time()
        self.last_render = 0.0
        self.current_label = ""

    def set_label(self, file_label: str = ""):
        self.current_label = file_label or ""

    def clear_line(self):
        if self.enabled:
            try:
                term_width = shutil.get_terminal_size((80, 20)).columns
            except Exception:
                term_width = 80
            print("\r" + (" " * term_width) + "\r", end="", flush=True)

    def advance(self, amount: int):
        self.done_bytes += max(amount, 0)
        if not self.enabled:
            return

        now = time.time()
        if now - self.last_render < 0.05 and self.done_bytes < self.total_bytes:
            return
        self.last_render = now

        try:
            term_width = shutil.get_terminal_size((80, 20)).columns
        except Exception:
            term_width = 80

        elapsed = max(now - self.start_time, 0.001)
        speed = self.done_bytes / elapsed
        pct = (self.done_bytes / self.total_bytes * 100.0) if self.total_bytes > 0 else 100.0

        right = (
            f"{pct:5.1f}% "
            f"{format_bytes(self.done_bytes)}/{format_bytes(self.total_bytes)} "
            f"@ {format_bytes(int(speed))}/s"
        )

        label = self.current_label
        max_label = max(10, int(term_width * 0.25))
        if len(label) > max_label:
            label = "..." + label[-(max_label - 3):]

        if label:
            right += f" | {label}"

        left_prefix_plain = "PROGRESS "
        bar_space = term_width - len(left_prefix_plain) - len(right) - 3
        if bar_space < 10:
            bar_space = 10

        bar = make_progress_bar(self.done_bytes, self.total_bytes, width=bar_space)
        line_plain = f"PROGRESS {bar} {right}"

        if len(line_plain) > term_width:
            overflow = len(line_plain) - term_width
            if label and overflow > 0:
                keep = max(0, len(label) - overflow - 3)
                if keep > 0:
                    label = label[:keep] + "..."
                    right = (
                        f"{pct:5.1f}% "
                        f"{format_bytes(self.done_bytes)}/{format_bytes(self.total_bytes)} "
                        f"@ {format_bytes(int(speed))}/s | {label}"
                    )
                else:
                    right = (
                        f"{pct:5.1f}% "
                        f"{format_bytes(self.done_bytes)}/{format_bytes(self.total_bytes)} "
                        f"@ {format_bytes(int(speed))}/s"
                    )

                bar_space = term_width - len(left_prefix_plain) - len(right) - 3
                if bar_space < 10:
                    bar_space = 10
                bar = make_progress_bar(self.done_bytes, self.total_bytes, width=bar_space)

        line = f"\r{colorize('PROGRESS', BLUE)} {bar} {right}"
        visible_len = len(f"PROGRESS {bar} {right}")
        if visible_len < term_width:
            line += " " * (term_width - visible_len)

        print(line, end="", flush=True)

    def finish(self):
        if self.enabled:
            self.advance(0)
            print()


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
# Defaults CSV
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
# Parsing helpers
# --------------------------------------------------
def extract_source_tokens(argv: list[str]) -> tuple[list[str], list[str]]:
    cleaned = []
    source_tokens = []

    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-s", "--source"):
            i += 1
            while i < len(argv):
                nxt = argv[i]
                if nxt.startswith("-"):
                    break
                source_tokens.append(nxt)
                i += 1
            continue

        cleaned.append(a)
        i += 1

    return cleaned, source_tokens


def expand_source_token(token: str) -> list[Path]:
    token = (token or "").strip()
    if not token:
        return []

    raw = os.path.expandvars(os.path.expanduser(token))
    matches = glob.glob(raw)

    if matches:
        return [normalize_path(m).resolve() for m in matches]

    p = normalize_path(raw)
    try:
        return [p.resolve()]
    except Exception:
        return [p]


def dedupe_paths(paths: list[Path]) -> list[Path]:
    seen = set()
    out = []
    for p in paths:
        k = str(p)
        if k not in seen:
            seen.add(k)
            out.append(p)
    return out


# --------------------------------------------------
# Transfer helpers
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


def should_include_file(path: Path, exts: set[str]) -> bool:
    if not exts:
        return True
    return path.suffix.lower().lstrip(".") in exts


def resolve_conflict_dest(
    dst: Path,
    overwrite: bool,
    rename_on_conflict: bool,
) -> Path | None:
    if not dst.exists():
        return dst

    if overwrite:
        if dst.is_file() or dst.is_symlink():
            dst.unlink()
        else:
            shutil.rmtree(dst)
        return dst

    if rename_on_conflict:
        return unique_dest(dst)

    print(colorize(f"SKIP (exists): {dst}", RED))
    return None


def iter_transfer_candidates(sources: list[Path], exts: set[str]):
    for src in sources:
        if not src.exists():
            continue

        if src.is_file():
            if should_include_file(src, exts):
                yield src
        elif src.is_dir():
            for root, _, files in os.walk(src):
                root_p = Path(root)
                for fname in files:
                    p = root_p / fname
                    if should_include_file(p, exts):
                        yield p


def calculate_total_bytes(sources: list[Path], exts: set[str]) -> int:
    total = 0
    for p in iter_transfer_candidates(sources, exts):
        try:
            total += p.stat().st_size
        except Exception:
            pass
    return total


def copy_file_with_progress(
    src: Path,
    dst: Path,
    tracker: ProgressTracker | None,
    chunk_size: int = 8 * 1024 * 1024,
):
    dst.parent.mkdir(parents=True, exist_ok=True)

    if tracker:
        tracker.set_label(src.name)

    with src.open("rb") as fsrc, dst.open("wb") as fdst:
        while True:
            chunk = fsrc.read(chunk_size)
            if not chunk:
                break
            fdst.write(chunk)
            if tracker:
                tracker.advance(len(chunk))

    shutil.copystat(src, dst)


def move_file_with_progress(
    src: Path,
    dst: Path,
    tracker: ProgressTracker | None,
    chunk_size: int = 8 * 1024 * 1024,
):
    dst.parent.mkdir(parents=True, exist_ok=True)

    if tracker:
        tracker.set_label(src.name)

    try:
        src.rename(dst)
        try:
            moved_size = dst.stat().st_size
        except Exception:
            moved_size = 0
        if tracker and moved_size > 0:
            tracker.advance(moved_size)
        return
    except OSError:
        pass

    copy_file_with_progress(src, dst, tracker, chunk_size=chunk_size)
    src.unlink()


def transfer_file(
    src_file: Path,
    dst_root: Path,
    mode: str,
    overwrite: bool,
    exts: set[str],
    rename_on_conflict: bool,
    tracker: ProgressTracker | None = None,
):
    if not should_include_file(src_file, exts):
        return

    dst_root.mkdir(parents=True, exist_ok=True)
    dst_file = dst_root / src_file.name
    dst_file = resolve_conflict_dest(dst_file, overwrite, rename_on_conflict)
    if dst_file is None:
        return

    action = "COPY" if mode == "copy" else "MOVE"

    if tracker:
        tracker.clear_line()

    print(colorize(f"{action}: {src_file.name} -> {dst_file}", DEEP_GREEN))

    if mode == "copy":
        copy_file_with_progress(src_file, dst_file, tracker)
    else:
        move_file_with_progress(src_file, dst_file, tracker)


def transfer_dir(
    src_dir: Path,
    dst: Path,
    mode: str,
    overwrite: bool,
    flatten: bool,
    exts: set[str],
    rename_on_conflict: bool,
    tracker: ProgressTracker | None = None,
):
    for root, _, files in os.walk(src_dir):
        root_p = Path(root)
        rel = root_p.relative_to(src_dir)

        dst_root = dst if flatten else (dst / rel)
        dst_root.mkdir(parents=True, exist_ok=True)

        for fname in files:
            src_file = root_p / fname
            transfer_file(
                src_file=src_file,
                dst_root=dst_root,
                mode=mode,
                overwrite=overwrite,
                exts=exts,
                rename_on_conflict=rename_on_conflict,
                tracker=tracker,
            )

    if mode == "move":
        for root, dirs, _ in os.walk(src_dir, topdown=False):
            for d in dirs:
                try:
                    (Path(root) / d).rmdir()
                except OSError:
                    pass
        try:
            src_dir.rmdir()
        except OSError:
            pass


def transfer_sources(
    sources: list[Path],
    dst: Path,
    mode: str,
    overwrite: bool,
    flatten: bool,
    exts: set[str],
    rename_on_conflict: bool,
    tracker: ProgressTracker | None = None,
):
    if not sources:
        raise FileNotFoundError("No source paths resolved.")

    dst.mkdir(parents=True, exist_ok=True)

    for src in sources:
        if not src.exists():
            print(colorize(f"SKIP (missing): {src}", RED))
            continue

        if src.is_file():
            transfer_file(
                src_file=src,
                dst_root=dst,
                mode=mode,
                overwrite=overwrite,
                exts=exts,
                rename_on_conflict=rename_on_conflict,
                tracker=tracker,
            )
        elif src.is_dir():
            transfer_dir(
                src_dir=src,
                dst=dst,
                mode=mode,
                overwrite=overwrite,
                flatten=flatten,
                exts=exts,
                rename_on_conflict=rename_on_conflict,
                tracker=tracker,
            )
        else:
            print(colorize(f"SKIP (unsupported): {src}", RED))


# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    prog = Path(sys.argv[0]).stem

    argv_clean, source_tokens = extract_source_tokens(sys.argv[1:])

    parser = argparse.ArgumentParser(
        prog=prog,
        description=(
            "Safe directory/file transfer (COPY default).\n"
            "Supports folders, files, and globs.\n"
            "Default conflict policy: SKIP existing (no dupes)."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument("-c", "--copy", action="store_true", help="Copy mode (default)")
    parser.add_argument("-m", "--move", action="store_true", help="Move mode (destructive)")
    parser.add_argument("-o", "--overwrite", action="store_true", help="Overwrite existing files")
    parser.add_argument("--rename", action="store_true", help="Rename on conflict: *_1, *_2, etc.")
    parser.add_argument("-d", "--dest", help="Destination directory")
    parser.add_argument("-a", "--active-dir", action="store_true", help="Use active directory as source")
    parser.add_argument("-f", "--flat", "--flatten", action="store_true", help="Flatten all files into destination root")
    parser.add_argument(
        "-e", "--ext",
        action="append",
        help="Only include these extensions (repeatable). Default: ALL file types",
    )
    parser.add_argument(
        "--no-progress",
        action="store_true",
        help="Disable progress bar",
    )
    parser.add_argument(
        "--save-default-source",
        action="store_true",
        help="Save the resolved source path when using a single source directory",
    )
    parser.add_argument(
        "positional",
        nargs="*",
        help="Optional positional SOURCES and DEST. If used, last positional is DEST.",
    )

    if len(sys.argv) == 1:
        parser.print_help()
        return 0

    args = parser.parse_args(argv_clean)

    if args.copy and args.move:
        print(colorize("❌ Choose either copy or move, not both.", RED))
        return 2

    mode = "move" if args.move else "copy"
    exts = {e.lower().lstrip(".") for e in args.ext} if args.ext else set()

    positional = list(args.positional)
    dest_raw = args.dest

    if not dest_raw:
        if source_tokens and len(source_tokens) >= 2:
            dest_raw = source_tokens.pop()
        elif len(positional) >= 2:
            dest_raw = positional.pop()
        elif len(positional) == 1 and not source_tokens and not args.active_dir:
            print(colorize("❌ Need at least one source and one destination.", RED))
            return 2

    if not dest_raw:
        print(colorize("❌ Destination required.", RED))
        return 2

    dst = normalize_path(dest_raw).resolve()

    source_paths: list[Path] = []

    if args.active_dir:
        source_paths = [get_effective_cwd().resolve()]
    elif source_tokens:
        for tok in source_tokens:
            source_paths.extend(expand_source_token(tok))
    elif positional:
        for tok in positional:
            source_paths.extend(expand_source_token(tok))
    else:
        saved = load_default_source()
        if saved:
            source_paths = [normalize_path(saved).resolve()]
        else:
            ensure_logs()
            entered = input("📝 Enter DEFAULT source directory:\n↳ ").strip()
            p = normalize_path(entered)
            if not p.is_dir():
                print(colorize("❌ Invalid directory.", RED))
                return 2
            p = p.resolve()
            save_default_source(str(p))
            source_paths = [p]

    source_paths = dedupe_paths(source_paths)

    if not source_paths:
        print(colorize("❌ No valid source paths resolved.", RED))
        return 2

    if args.save_default_source and len(source_paths) == 1 and source_paths[0].is_dir():
        save_default_source(str(source_paths[0]))

    total_bytes = calculate_total_bytes(source_paths, exts)

    print("\n📂 plan")
    print(f"Mode:      {mode.upper()}")
    print(f"Dest:      {dst}")
    print(f"Flatten:   {'YES' if args.flat else 'NO'}")
    print(f"Overwrite: {'YES' if args.overwrite else 'NO'}")
    print(f"Conflicts: {'RENAME' if args.rename else ('OVERWRITE' if args.overwrite else 'SKIP')}")
    print(f"Filter:    {', '.join(sorted(exts)) if exts else 'ALL'}")
    print(f"Total:     {format_bytes(total_bytes)}")
    print(f"Sources:   {len(source_paths)} item(s)")
    for i, s in enumerate(source_paths[:10], 1):
        print(f"  {i:>2}. {s}")
    if len(source_paths) > 10:
        print(f"  ... and {len(source_paths) - 10} more")
    print()

    if mode == "move":
        if input(colorize("⚠️ MOVE deletes originals. Continue? (y/n): ", YELLOW)).strip().lower() != "y":
            print(colorize("❎ Aborted.", RED))
            return 0

    tracker = ProgressTracker(total_bytes=total_bytes, enabled=not args.no_progress)

    transfer_sources(
        sources=source_paths,
        dst=dst,
        mode=mode,
        overwrite=args.overwrite,
        flatten=args.flat,
        exts=exts,
        rename_on_conflict=args.rename,
        tracker=tracker,
    )

    tracker.finish()
    print(colorize("\n✅ Done.", CYAN))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
