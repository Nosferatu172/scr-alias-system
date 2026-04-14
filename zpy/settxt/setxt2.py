#!/usr/bin/env python3
# Script Name: setxt2.py
# ID: SCR-ID-20260329031419-XIRSPIIXNC
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: setxt2

"""
setxt_allinone.py

ONE script, two modes:

A) Tabs mode (default, no path args):
   - Finds itself, creates ./logs/
   - Creates/loads defaults config (source dir + archive dir)
   - Ensures source + archive directories exist (mkdir -p)
   - Rename first .txt in source dir -> exported-tabs.txt (if needed)
   - Clean exported-tabs.txt: remove '&list=...&start_radio=1' from YouTube URLs
   - Optional .bak with --bak
   - Archive to <archive_dir>/<timestamp>_<tag>.txt
   - Ctrl+C safe exit

B) Path-converter mode (if a path arg is provided):
   - Convert Windows <-> WSL path
   - Optional clipboard copy flags or interactive prompt

New flags:
  -f / --f               Process ALL .txt files in source_dir in one shot:
                         - Clean each file
                         - Create archive folder per file:
                           <archive_dir>/<timestamp>_<original_basename>/
                         - Copy cleaned file into that folder as:
                           <timestamp>_<original_basename>.txt

  --edit-archive         Interactive: change default archive directory (saved in logs/config.json)
  --set-archive PATH     Non-interactive: set default archive directory
  --edit-source          Interactive: change default source directory
  --set-source PATH      Non-interactive: set default source directory
  --show-config          Print current config and exit

Examples:
  ./setxt_allinone.py
  ./setxt_allinone.py --tag yt
  ./setxt_allinone.py --bak --tag radiofix
  ./setxt_allinone.py -f
  ./setxt_allinone.py -f --bak
  ./setxt_allinone.py --set-source "/mnt/c/Users/tyler/Documents/brave" -f
  ./setxt_allinone.py "C:\\Users\\tyler\\Documents"
"""

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# uncomment if it is set in aliases.
# WINPROFILE = ENV["WINPROFILE"]

# -----------------------
# Ctrl+C handler
# -----------------------
def handle_sigint(sig, frame):
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    sys.exit(130)


signal.signal(signal.SIGINT, handle_sigint)


# -----------------------
# Clipboard (WSL + Windows)
# -----------------------
def copy_to_clipboard(text: str):
    try:
        # WSL
        if os.path.isdir("/mnt/c"):
            clip = subprocess.run(
                ["which", "clip.exe"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            ).stdout.strip()
            if not clip:
                clip = "/mnt/c/Windows/System32/clip.exe"

            p = subprocess.Popen(clip, stdin=subprocess.PIPE)
            p.communicate(text.encode("utf-16le"))
        # Native Windows / others
        else:
            p = subprocess.Popen("clip", stdin=subprocess.PIPE, shell=True)
            p.communicate(text.encode())
    except Exception as e:
        print(f"⚠️ Clipboard copy failed: {e}", file=sys.stderr)


# -----------------------
# Path conversion (Windows <-> WSL)
# -----------------------
def convert_paths(path: str):
    path = path.strip()

    # WSL → Windows
    m = re.match(r"^/mnt/([a-zA-Z])/", path)
    if m:
        drive = m.group(1).upper()
        win_path = re.sub(r"^/mnt/[a-zA-Z]/", f"{drive}:/", path).replace("/", "\\")
        return {"windows": win_path, "wsl": path}

    # Windows → WSL
    m = re.match(r"^([a-zA-Z]):[\\/]", path)
    if m:
        drive = m.group(1).lower()
        norm = path.replace("/", "\\")
        wsl_path = re.sub(r"^.:\\", f"/mnt/{drive}/", norm).replace("\\", "/")
        return {"windows": norm, "wsl": wsl_path}

    return None


def run_path_converter(input_path: str, copy_mode: str | None, quiet: bool):
    converted = convert_paths(input_path)
    if not converted:
        print("❌ Unrecognized path format.", file=sys.stderr)
        sys.exit(2)

    if not quiet:
        print(f"Windows: {converted['windows']}")
        print(f"WSL:     {converted['wsl']}")

    if copy_mode == "w":
        copy_to_clipboard(converted["windows"])
        if not quiet:
            print("✅ Windows copied.")
    elif copy_mode == "l":
        copy_to_clipboard(converted["wsl"])
        if not quiet:
            print("✅ WSL copied.")
    elif copy_mode == "b":
        copy_to_clipboard(f"Windows: {converted['windows']}\nWSL:     {converted['wsl']}\n")
        if not quiet:
            print("✅ Both copied.")
    else:
        choice = input("Copy which? (w = Windows, l = WSL, b = both, Enter = none): ").strip().lower()
        if choice == "w":
            copy_to_clipboard(converted["windows"])
            if not quiet:
                print("✅ Windows copied.")
        elif choice == "l":
            copy_to_clipboard(converted["wsl"])
            if not quiet:
                print("✅ WSL copied.")
        elif choice == "b":
            copy_to_clipboard(f"Windows: {converted['windows']}\nWSL:     {converted['wsl']}\n")
            if not quiet:
                print("✅ Both copied.")
        else:
            if not quiet:
                print("ℹ️ Nothing copied.")


# -----------------------
# WIN_USER detection (robust)
# -----------------------
def run_quiet(cmd_list):
    try:
        out = subprocess.run(
            cmd_list,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        ).stdout.strip()
        return out or None
    except Exception:
        return None


def valid_win_user_name(name: str) -> bool:
    if not name:
        return False
    n = name.strip()
    if not n:
        return False
    bad = {"public", "default", "default user", "all users", "desktop.ini"}
    return n.lower() not in bad


def scan_windows_users(prefer_subpath="Documents/brave"):
    users_root = Path("/mnt/c/Users")
    if not users_root.is_dir():
        return []

    candidates = [
        child.name
        for child in users_root.iterdir()
        if child.is_dir() and valid_win_user_name(child.name)
    ]

    preferred = [u for u in candidates if (users_root / u / prefer_subpath).is_dir()]
    if preferred:
        return preferred

    with_docs = [u for u in candidates if (users_root / u / "Documents").is_dir()]
    return with_docs if with_docs else candidates


def pick_from_list(items, prompt):
    if len(items) == 1:
        return items[0]

    print(prompt)
    for i, item in enumerate(items, start=1):
        print(f"  {i}) {item}")

    ans = input("Select number (or 'q' to quit): ").strip()
    if not ans or ans.lower() == "q":
        sys.exit(0)

    try:
        n = int(ans)
    except ValueError:
        print("❌ Invalid selection.")
        sys.exit(1)

    if n < 1 or n > len(items):
        print("❌ Invalid selection.")
        sys.exit(1)

    return items[n - 1]


def detect_windows_user():
    # 1) Environment
    env_user = os.environ.get("WIN_USER") or os.environ.get("USERNAME")
    if valid_win_user_name(env_user):
        return env_user.strip()

    # 2) cmd.exe
    cmd_path = Path("/mnt/c/Windows/System32/cmd.exe")
    if cmd_path.exists():
        u = run_quiet([str(cmd_path), "/c", "echo", "%USERNAME%"])
        if valid_win_user_name(u):
            return u.strip()

    # 3) powershell.exe
    ps_path = Path("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
    if ps_path.exists():
        u = run_quiet([str(ps_path), "-NoProfile", "-Command", "[Environment]::UserName"])
        if valid_win_user_name(u):
            return u.strip()

    # 4) Scan /mnt/c/Users
    candidates = scan_windows_users(prefer_subpath="Documents/brave")
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    return pick_from_list(candidates, "Multiple Windows profiles found:")


# -----------------------
# Script-local config (logs/config.json)
# -----------------------
def script_paths():
    script_path = Path(__file__).resolve()
    script_dir = script_path.parent
    logs_dir = script_dir / "logs"
    config_path = logs_dir / "config.json"
    return script_dir, logs_dir, config_path


def _norm_dir_string(p: str) -> str:
    p = (p or "").strip().strip('"').strip("'")
    if not p:
        return p
    # accept windows/WSL paths; convert if needed
    converted = convert_paths(p)
    if converted:
        return converted["wsl"]
    return p


def build_default_config(win_user: str | None):
    if win_user:
        source = f"/mnt/c/Users/{win_user}/Documents/brave"
        archive = f"/mnt/f/Wyvern/mnt/c/scr/tabs"
    else:
        source = "/mnt/c/Users/<WIN_USER>/Documents/brave"
        archive = "/mnt/f/Wyvern/mnt/c/scr/tabs"

    return {
        "win_user": win_user or "",
        "source_dir": source,
        "archive_dir": archive,
    }


def load_or_init_config(win_user_override: str | None):
    _, logs_dir, config_path = script_paths()
    logs_dir.mkdir(parents=True, exist_ok=True)

    if config_path.exists():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                raise ValueError("config is not a dict")
        except Exception:
            data = {}
    else:
        data = {}

    win_user = (win_user_override or data.get("win_user") or detect_windows_user() or "").strip()

    if not data.get("source_dir") or not data.get("archive_dir"):
        seeded = build_default_config(win_user if win_user else None)
        for k, v in seeded.items():
            data.setdefault(k, v)

    if win_user:
        data["win_user"] = win_user

    data["source_dir"] = _norm_dir_string(str(data.get("source_dir", "")).strip())
    data["archive_dir"] = _norm_dir_string(str(data.get("archive_dir", "")).strip())

    config_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


def save_config(cfg: dict):
    _, logs_dir, config_path = script_paths()
    logs_dir.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")


def edit_dir_interactive(label: str, current_value: str) -> str:
    print(f"{label} (current): {current_value}")
    new_val = input(f"Enter new {label} (blank = keep current): ").strip()
    if not new_val:
        print("ℹ️ Keeping current.")
        return current_value
    new_val = _norm_dir_string(new_val)
    print(f"✅ Set {label} -> {new_val}")
    return new_val


# -----------------------
# Cleaner: remove &list=...&start_radio=1
# -----------------------
URL_LINE_RE = re.compile(r"^\s*https?://\S+\s*$", re.IGNORECASE)
LIST_START_RADIO_RE = re.compile(r"&list=[^&\s]+&start_radio=1\b", re.IGNORECASE)


def clean_exported_tabs_file(path: Path, make_backup: bool) -> bool:
    if not path.is_file():
        print(f"❌ .txt not found: {path}")
        return False

    original = path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)

    changed = False
    cleaned = []

    for line in original:
        if not URL_LINE_RE.match(line):
            cleaned.append(line)
            continue

        new_line = LIST_START_RADIO_RE.sub("", line)
        if new_line != line:
            changed = True
        cleaned.append(new_line)

    if not changed:
        print(f"ℹ️  No '&list=...&start_radio=1' patterns found in: {path}")
        return False

    if make_backup:
        backup_path = path.with_suffix(path.suffix + ".bak")
        backup_path.write_text("".join(original), encoding="utf-8")
        print(f"🧷 Backup created → {backup_path}")

    path.write_text("".join(cleaned), encoding="utf-8")
    print(f"🧼 Cleaned in place → {path}")
    return True


def _safe_name(s: str) -> str:
    s = s.strip()
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"[^A-Za-z0-9._-]+", "_", s)
    return s.strip("._-") or "file"


# -----------------------
# Tabs workflow: rename + clean + archive
# -----------------------
def tabs_workflow(
    tag: str | None,
    win_user_override: str | None,
    make_backup: bool,
    edit_archive: bool,
    set_archive: str | None,
    edit_source: bool,
    set_source: str | None,
    show_config: bool,
    full_source: bool,
):
    cfg = load_or_init_config(win_user_override=win_user_override)

    # Apply set/edit flags
    if set_archive:
        cfg["archive_dir"] = _norm_dir_string(set_archive)
        save_config(cfg)
    if set_source:
        cfg["source_dir"] = _norm_dir_string(set_source)
        save_config(cfg)

    if edit_archive:
        cfg["archive_dir"] = edit_dir_interactive("archive_dir", cfg.get("archive_dir", ""))
        save_config(cfg)

    if edit_source:
        cfg["source_dir"] = edit_dir_interactive("source_dir", cfg.get("source_dir", ""))
        save_config(cfg)

    if show_config:
        print(json.dumps(cfg, indent=2))
        return

    win_user = (win_user_override or cfg.get("win_user") or "").strip()
    if not win_user:
        print("❌ Unable to determine Windows username automatically.")
        print("👉 Type it manually (example: shadowwalker)")
        manual = input("Windows username: ").strip()
        if not valid_win_user_name(manual):
            print("❌ Invalid username input.")
            sys.exit(1)
        win_user = manual
        cfg["win_user"] = win_user
        if "<WIN_USER>" in cfg.get("source_dir", "") or "<WIN_USER>" in cfg.get("archive_dir", ""):
            seeded = build_default_config(win_user)
            cfg["source_dir"] = seeded["source_dir"]
            cfg["archive_dir"] = seeded["archive_dir"]
        save_config(cfg)

    source_dir = Path(cfg["source_dir"])
    archive_dir = Path(cfg["archive_dir"])

    # Create the directories (as requested)
    source_dir.mkdir(parents=True, exist_ok=True)
    archive_dir.mkdir(parents=True, exist_ok=True)

    txt_files = sorted([p for p in source_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt"])
    if not txt_files:
        print(f"❌ No .txt files found in {source_dir}")
        print("👉 Export your Brave tabs to .txt into that folder, then re-run.")
        sys.exit(1)

    # -----------------------
    # FULL-SOURCE MODE (-f/--f)
    # -----------------------
    if full_source:
        run_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        print(f"📦 Full-source mode: {len(txt_files)} file(s)")
        print(f"⏱️  Timestamp: {run_ts}")

        ok = 0
        for p in txt_files:
            base = _safe_name(p.stem)
            dest_folder = archive_dir / f"{run_ts}_{base}"
            dest_folder.mkdir(parents=True, exist_ok=True)

            # Clean in place (optional per-file backup)
            clean_exported_tabs_file(p, make_backup=make_backup)

            dest_file = dest_folder / f"{run_ts}_{base}.txt"
            shutil.copy2(p, dest_file)
            print(f"➡️  {p.name}  →  {dest_file}")
            ok += 1

        print(f"✅ Done. Archived {ok}/{len(txt_files)} files into per-file folders under: {archive_dir}")
        return

    # -----------------------
    # ORIGINAL SINGLE-FILE WORKFLOW
    # -----------------------
    target_name = "exported-tabs.txt"
    exported_path = source_dir / target_name

    if exported_path.exists():
        print(f"ℹ️  {target_name} already exists — leaving it as-is.")
    else:
        first_txt = txt_files[0]
        if first_txt.name != target_name:
            first_txt.rename(exported_path)
            print(f"🔁 Renamed: {first_txt.name} → {target_name}")
        else:
            print(f"ℹ️  Using existing {target_name}")

    clean_exported_tabs_file(exported_path, make_backup=make_backup)

    if not tag:
        tag = input("🏷️  Enter a short tag (no spaces): ").strip()
    if not tag:
        print("❌ Tag cannot be empty.")
        sys.exit(1)
    tag = re.sub(r"\s+", "_", tag)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest_path = archive_dir / f"{timestamp}_{tag}.txt"

    shutil.copy2(exported_path, dest_path)
    print(f"📦 Archived → {dest_path}")


# -----------------------
# Main
# -----------------------
def main():
    parser = argparse.ArgumentParser(
        description="All-in-one: rename+clean+archive exported tabs (default) OR convert paths if a path is supplied."
    )
    parser.add_argument("path", nargs="*", help="(Optional) If provided, run path converter on this path")

    # Path mode options
    parser.add_argument("-w", "--copy-windows", action="store_true", help="(Path mode) Copy Windows path")
    parser.add_argument("-l", "--copy-wsl", action="store_true", help="(Path mode) Copy WSL path")
    parser.add_argument("-b", "--copy-both", action="store_true", help="(Path mode) Copy both paths")
    parser.add_argument("-q", "--quiet", action="store_true", help="(Path mode) Suppress output")

    # Tabs mode options
    parser.add_argument("--tag", help="(Tabs mode) Archive tag (no spaces)")
    parser.add_argument("--win-user", help="(Tabs mode) Override Windows username")
    parser.add_argument("--bak", action="store_true", help="(Tabs mode) Create .bak before cleaning (per file in -f mode)")

    # Full-source mode
    parser.add_argument("-f", "--f", dest="full_source", action="store_true",
                        help="(Tabs mode) Process ALL .txt files in source_dir, folder-per-file archive")

    # Config/edit flags
    parser.add_argument("--edit-archive", action="store_true", help="Edit default archive directory (saved in logs/config.json)")
    parser.add_argument("--set-archive", help="Set default archive directory (non-interactive)")
    parser.add_argument("--edit-source", action="store_true", help="Edit default source directory (saved in logs/config.json)")
    parser.add_argument("--set-source", help="Set default source directory (non-interactive)")
    parser.add_argument("--show-config", action="store_true", help="Print current config and exit")

    args = parser.parse_args()

    # If a path is provided -> path converter mode
    if args.path:
        input_path = " ".join(args.path).strip()
        copy_mode = None
        if args.copy_windows:
            copy_mode = "w"
        elif args.copy_wsl:
            copy_mode = "l"
        elif args.copy_both:
            copy_mode = "b"
        run_path_converter(input_path, copy_mode=copy_mode, quiet=args.quiet)
        return

    # Otherwise -> tabs workflow
    tabs_workflow(
        tag=args.tag,
        win_user_override=args.win_user,
        make_backup=args.bak,
        edit_archive=args.edit_archive,
        set_archive=args.set_archive,
        edit_source=args.edit_source,
        set_source=args.set_source,
        show_config=args.show_config,
        full_source=args.full_source,
    )


if __name__ == "__main__":
    main()
