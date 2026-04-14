#!/usr/bin/env python3
# Script Name: dcimrenamer.py
# ID: SCR-ID-20260317130642-D9IC161YY6
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dcimrenamer

import argparse
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import uuid
from pathlib import Path


# -----------------------
# Ctrl+C handler
# -----------------------
def _sigint_handler(sig, frame):
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    raise SystemExit(130)


signal.signal(signal.SIGINT, _sigint_handler)


# -----------------------
# Environment + path helpers
# -----------------------
def is_wsl() -> bool:
    if os.environ.get("WSL_INTEROP") or os.environ.get("WSL_DISTRO_NAME") or os.environ.get("WSLENV"):
        return True

    for p in ("/proc/sys/kernel/osrelease", "/proc/version"):
        try:
            s = Path(p).read_text(errors="ignore").lower()
            if "microsoft" in s or "wsl" in s:
                return True
        except Exception:
            pass

    return False


def normalize_posix_path(p: str) -> str:
    p = p.strip().strip('"').strip("'")
    p = os.path.expandvars(p)
    p = os.path.expanduser(p)

    pp = Path(p)
    if not pp.is_absolute():
        pp = Path.cwd() / pp

    try:
        return str(pp.resolve(strict=False))
    except Exception:
        return str(pp)


def windows_to_wsl_drive(p: str) -> str | None:
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", p)
    if not m:
        return None
    drive = m.group(1).lower()
    rest = m.group(2).replace("\\", "/")
    return f"/mnt/{drive}/{rest}"


def windows_unc_to_wsl(p: str) -> str | None:
    p = p.strip().strip('"').strip("'")
    m = re.match(
        r"^(?:\\\\wsl\$\\|\\\\wsl\.localhost\\|//wsl\$/|//wsl\.localhost/)([^\\\/]+)[\\\/](.*)$",
        p,
        re.IGNORECASE,
    )
    if not m:
        return None
    rest = m.group(2).replace("\\", "/")
    return f"/{rest}".replace("//", "/")


def auto_normalize_input(raw: str, debug: bool = False) -> str:
    s = raw.strip().strip('"').strip("'").strip()

    if re.match(r"^[A-Za-z]:", s):
        s = s.replace("/", "\\")

        m = re.match(r"^([A-Za-z]):(?![\\/])(.*)$", s)
        if m:
            drive = m.group(1)
            rest = m.group(2)
            if "\\" in rest:
                s = f"{drive}:\\{rest}"
                if debug:
                    print(f"[debug] normalized missing slash after colon -> {s}")

        if re.match(r"^[A-Za-z]:\\$", s):
            return s
        if s.endswith("\\") and not s.endswith("\\\\"):
            s = s.rstrip("\\")
            if debug:
                print(f"[debug] stripped trailing backslash -> {s}")

        return s

    if s.startswith("//wsl$/") or s.startswith("//wsl.localhost/"):
        s = s.replace("/", "\\")
        if debug:
            print(f"[debug] normalized forward-slash UNC -> {s}")
        return s

    return s


def warn_if_backslashes_were_eaten(raw: str):
    if re.match(r"^[A-Za-z]:", raw) and ("\\" not in raw) and ("/" not in raw):
        if os.name != "nt":
            print("⚠️ That looks like a Windows drive path, but it has no slashes.")
            print("   Your shell likely ate the backslashes.")
            print("   Use one of these instead:")
            print(r"     massrename -p 'C:\Users\you\Pictures'")
            print(r"     massrename -p C:/Users/you/Pictures")
            print(r"     massrename -p C:\\Users\\you\\Pictures")


def resolve_input_directory(input_path: str, debug: bool = False) -> Path:
    raw = auto_normalize_input(input_path, debug=debug)
    warn_if_backslashes_were_eaten(raw)

    wsl_drive = windows_to_wsl_drive(raw)
    if wsl_drive:
        return Path(normalize_posix_path(wsl_drive))

    wsl_unc = windows_unc_to_wsl(raw)
    if wsl_unc:
        return Path(normalize_posix_path(wsl_unc))

    return Path(normalize_posix_path(raw))


# -----------------------
# Clipboard helpers
# -----------------------
def read_clipboard(debug: bool = False) -> str | None:
    try:
        if is_wsl():
            powershell = shutil.which("powershell.exe") or "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
            if os.path.exists(powershell):
                result = subprocess.run(
                    [powershell, "-NoProfile", "-Command", "Get-Clipboard"],
                    capture_output=True,
                    text=True,
                    check=True
                )
                text = result.stdout.strip()
                if debug:
                    print(f"[debug] clipboard via powershell.exe: {text!r}")
                return text if text else None

        if os.name == "nt":
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", "Get-Clipboard"],
                capture_output=True,
                text=True,
                check=True
            )
            text = result.stdout.strip()
            if debug:
                print(f"[debug] clipboard via powershell: {text!r}")
            return text if text else None

        for cmd in (
            ["wl-paste", "-n"],
            ["xclip", "-selection", "clipboard", "-o"],
            ["xsel", "--clipboard", "--output"],
            ["pbpaste"],
        ):
            if shutil.which(cmd[0]):
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                text = result.stdout.strip()
                if debug:
                    print(f"[debug] clipboard via {cmd[0]}: {text!r}")
                return text if text else None

    except Exception as e:
        if debug:
            print(f"[debug] clipboard read failed: {e}")

    return None


# -----------------------
# General helpers
# -----------------------
INVALID_WIN_CHARS = r'<>:"/\|?*'


def sanitize_name(name: str) -> str:
    name = name.strip()
    name = re.sub(r"\s+", " ", name)
    name = "".join("_" if c in INVALID_WIN_CHARS else c for c in name)
    name = name.rstrip(". ")
    return name or "file"


def natural_key(s: str):
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", s)]


def match_extensions(path: Path, wanted: list[str] | None) -> bool:
    if not wanted:
        return True

    suffixes = [s.lower().lstrip(".") for s in path.suffixes]
    last_suffix = path.suffix.lower().lstrip(".")

    wanted_set = {w.lower().lstrip(".") for w in wanted}

    if last_suffix in wanted_set:
        return True

    # allow tar.gz style full matching
    full_chain = ".".join(suffixes)
    if full_chain in wanted_set:
        return True

    return False


def collect_targets(
    folder: Path,
    recursive: bool = False,
    include_hidden: bool = False,
    include_files: bool = True,
    include_folders: bool = False,
    extensions: list[str] | None = None,
) -> list[Path]:
    iterator = folder.rglob("*") if recursive else folder.iterdir()
    items = []

    for p in iterator:
        if not include_hidden and p.name.startswith("."):
            continue

        if p.is_file() and include_files:
            if match_extensions(p, extensions):
                items.append(p)
        elif p.is_dir() and include_folders:
            items.append(p)

    return items


def sort_targets(items: list[Path], mode: str, natural: bool = False, reverse: bool = False) -> list[Path]:
    if mode == "name":
        key_func = (lambda p: natural_key(p.name) if natural else p.name.lower())
    elif mode == "mtime":
        key_func = lambda p: (p.stat().st_mtime, natural_key(p.name) if natural else p.name.lower())
    elif mode == "ctime":
        key_func = lambda p: (p.stat().st_ctime, natural_key(p.name) if natural else p.name.lower())
    elif mode == "size":
        key_func = lambda p: (p.stat().st_size, natural_key(p.name) if natural else p.name.lower())
    elif mode == "random":
        out = items[:]
        random.shuffle(out)
        if reverse:
            out.reverse()
        return out
    else:
        raise ValueError(f"Unsupported sort mode: {mode}")

    return sorted(items, key=key_func, reverse=reverse)


def format_number(n: int, digits: int | None) -> str:
    if digits is None or digits <= 0:
        return str(n)
    return str(n).zfill(digits)


def choose_suffix(path: Path, mode: str) -> str:
    if path.is_dir():
        return ""

    if mode == "keep":
        return "".join(path.suffixes)
    if mode == "last":
        return path.suffix
    if mode == "none":
        return ""
    raise ValueError(f"Unsupported extension mode: {mode}")


def get_separator(mode: str, custom: str | None) -> str:
    if custom is not None:
        return custom

    mapping = {
        "space": " ",
        "dash": "-",
        "dash-space": " - ",
        "underscore": "_",
        "none": "",
    }
    return mapping[mode]


def build_new_name(prefix: str, number: int, digits: int | None, suffix: str, separator: str) -> str:
    num = format_number(number, digits)

    if prefix:
        return f"{prefix}{separator}{num}{suffix}"
    return f"{num}{suffix}"


def ensure_no_duplicate_targets(plan: list[tuple[Path, Path]]):
    seen = set()
    for _src, dst in plan:
        key = (dst.parent.resolve(), dst.name.lower())
        if key in seen:
            raise RuntimeError(f"Duplicate target name generated: {dst}")
        seen.add(key)


def make_plan(
    items: list[Path],
    prefix: str,
    start: int,
    digits: int | None,
    ext_mode: str,
    separator: str,
) -> list[tuple[Path, Path]]:
    plan = []
    for i, src in enumerate(items, start=start):
        suffix = choose_suffix(src, ext_mode)
        new_name = build_new_name(prefix, i, digits, suffix, separator)
        dst = src.with_name(new_name)
        plan.append((src, dst))
    return plan


def print_plan(plan: list[tuple[Path, Path]], limit: int | None = None):
    total = len(plan)
    show = plan if limit is None else plan[:limit]

    for src, dst in show:
        kind = "DIR " if src.is_dir() else "FILE"
        print(f"[{kind}] {src.name}  ->  {dst.name}")

    if limit is not None and total > limit:
        print(f"... and {total - limit} more")


def execute_plan(plan: list[tuple[Path, Path]], verbose: bool = True):
    temp_pairs: list[tuple[Path, Path]] = []

    # deepest first helps when folders are involved
    plan_ordered = sorted(plan, key=lambda pair: len(pair[0].parts), reverse=True)

    for src, _dst in plan_ordered:
        temp_name = f".__massrename_tmp__{uuid.uuid4().hex}__{src.name}"
        tmp = src.with_name(temp_name)
        src.rename(tmp)
        temp_pairs.append((tmp, _dst))
        if verbose:
            print(f"[tmp] {src.name} -> {tmp.name}")

    for tmp, dst in temp_pairs:
        dst.parent.mkdir(parents=True, exist_ok=True)
        tmp.rename(dst)
        if verbose:
            print(f"[ok ] {tmp.name} -> {dst.name}")


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="massrename",
        description="Rename files and/or folders in the active or given directory into a numbered sequence.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=r"""
Examples:
  massrename -a -i "Walker pictures" -n 0
  massrename -a -i "Walker pictures" -n 0 --sep dash
  massrename -a -i "Walker pictures" -n 0 --sep dash-space
  massrename -a -i "Walker pictures" -n 0 --sep underscore
  massrename -a -i "Walker pictures" -n 0 --sep-custom "__"
  massrename -a -i "Walker pictures" -n 0 -x jpg png mp4
  massrename -a -i "Walker pictures" -n 0 --folders
  massrename -a -i "Walker pictures" -n 0 --natural
  massrename -a -i "Walker pictures" -n 0 --reverse
  massrename -a --from-clipboard -n 0
  massrename -p 'C:\Users\you\Pictures' -i "Walker pictures" -n 0 --dry-run

Separator modes:
  --sep space        -> Walker pictures 0.jpg
  --sep dash         -> Walker pictures-0.jpg
  --sep dash-space   -> Walker pictures - 0.jpg
  --sep underscore   -> Walker pictures_0.jpg
  --sep none         -> Walker pictures0.jpg
  --sep-custom "__"  -> Walker pictures__0.jpg
""",
    )

    src_group = parser.add_mutually_exclusive_group()
    src_group.add_argument("-a", "--active", action="store_true", help="Use current working directory.")
    src_group.add_argument("-p", "--path", help="Directory to process.")

    parser.add_argument("-i", "--input", default="", help='Base name/prefix, e.g. "Walker pictures"')
    parser.add_argument("--from-clipboard", action="store_true", help="Use clipboard text as the base name.")
    parser.add_argument("-n", "--start", type=int, default=0, help="Starting number.")
    parser.add_argument("--digits", type=int, default=None, help="Zero-pad numbers to this width.")

    parser.add_argument(
        "-s", "--sort",
        choices=["name", "mtime", "ctime", "size", "random"],
        default="name",
        help="Sort mode before numbering."
    )
    parser.add_argument("--natural", action="store_true", help="Use natural sorting for names, e.g. 2 before 10.")
    parser.add_argument("--reverse", action="store_true", help="Reverse the final order.")

    parser.add_argument(
        "--ext",
        choices=["keep", "last", "none"],
        default="keep",
        help="How to keep extensions for files."
    )
    parser.add_argument(
        "-x", "--extensions",
        nargs="+",
        help="Only include these file extensions, e.g. -x jpg png mp4 tar.gz"
    )

    parser.add_argument("-r", "--recursive", action="store_true", help="Rename recursively.")
    parser.add_argument("--hidden", action="store_true", help="Include hidden files/folders.")

    parser.add_argument("--folders", action="store_true", help="Include folders too.")
    parser.add_argument("--only-folders", action="store_true", help="Rename only folders.")
    parser.add_argument("--only-files", action="store_true", help="Rename only files.")

    parser.add_argument(
        "--sep",
        choices=["space", "dash", "dash-space", "underscore", "none"],
        default="space",
        help="Separator between base name and number."
    )
    parser.add_argument("--sep-custom", help="Custom separator text. Overrides --sep.")

    parser.add_argument("--dry-run", action="store_true", help="Preview only; do not rename.")
    parser.add_argument("--debug", action="store_true", help="Show debug info.")
    parser.add_argument("-y", "--yes", action="store_true", help="Do not ask for confirmation.")
    parser.add_argument("--show", type=int, default=None, help="Limit preview lines shown.")
    parser.add_argument("--verbose", action="store_true", help="Print each rename step.")

    args = parser.parse_args()

    if args.only_files and args.only_folders:
        print("❌ Choose only one of --only-files or --only-folders.")
        return 2

    if args.from_clipboard and args.input:
        print("❌ Choose either -i/--input or --from-clipboard, not both.")
        return 2

    if args.active:
        folder = Path.cwd()
    elif args.path:
        folder = resolve_input_directory(args.path, debug=args.debug)
    else:
        folder = Path.cwd()

    if not folder.exists():
        print(f"❌ Directory does not exist: {folder}")
        return 2

    if not folder.is_dir():
        print(f"❌ Not a directory: {folder}")
        return 2

    prefix_raw = args.input
    if args.from_clipboard:
        clip_text = read_clipboard(debug=args.debug)
        if not clip_text:
            print("❌ Clipboard was empty or unavailable.")
            return 2
        prefix_raw = clip_text

    prefix = sanitize_name(prefix_raw) if prefix_raw else ""
    separator = get_separator(args.sep, args.sep_custom)

    include_files = True
    include_folders = args.folders

    if args.only_folders:
        include_files = False
        include_folders = True
    elif args.only_files:
        include_files = True
        include_folders = False

    items = collect_targets(
        folder=folder,
        recursive=args.recursive,
        include_hidden=args.hidden,
        include_files=include_files,
        include_folders=include_folders,
        extensions=args.extensions,
    )

    if not items:
        print("⚠️ No matching files/folders found to rename.")
        return 0

    items = sort_targets(items, mode=args.sort, natural=args.natural, reverse=args.reverse)

    plan = make_plan(
        items=items,
        prefix=prefix,
        start=args.start,
        digits=args.digits,
        ext_mode=args.ext,
        separator=separator,
    )

    ensure_no_duplicate_targets(plan)

    print(f"📁 Directory: {folder}")
    print(f"📦 Targets found: {len(items)}")
    print(f"🔢 Start number: {args.start}")
    print(f"🏷️ Prefix: {prefix!r}")
    print(f"🔗 Separator: {separator!r}")
    print(f"↕️ Sort mode: {args.sort}")
    print(f"🔢 Natural sort: {'yes' if args.natural else 'no'}")
    print(f"🔁 Reverse: {'yes' if args.reverse else 'no'}")
    print(f"🌲 Recursive: {'yes' if args.recursive else 'no'}")
    print(f"📂 Include folders: {'yes' if include_folders else 'no'}")
    print(f"📄 Include files: {'yes' if include_files else 'no'}")
    print(f"🧩 Extension mode: {args.ext}")
    print(f"🎯 Extension filter: {args.extensions if args.extensions else '(all)'}")
    print("")

    print_plan(plan, limit=args.show)

    if args.dry_run:
        print("\n🧪 Dry run only. No files were renamed.")
        return 0

    if not args.yes:
        ans = input("\nProceed with rename? [y/N]: ").strip().lower()
        if ans not in {"y", "yes"}:
            print("ℹ️ Cancelled.")
            return 0

    try:
        execute_plan(plan, verbose=args.verbose)
    except Exception as e:
        print(f"❌ Rename failed: {e}")
        return 1

    print(f"\n✅ Renamed {len(plan)} target(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
