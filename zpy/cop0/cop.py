#!/usr/bin/env python3
# Script Name: cop.py
# ID: SCR-ID-20260329040951-5G9017NN33
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: cop

import argparse
import os
import re
import shutil
import signal
import subprocess
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


def get_wsl_distro_name() -> str | None:
    name = os.environ.get("WSL_DISTRO_NAME")
    if name:
        return name

    try:
        txt = Path("/etc/os-release").read_text(errors="ignore")
        m = re.search(r'^NAME="([^"]+)"', txt, re.M)
        if m:
            return m.group(1)
    except Exception:
        pass

    return None


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


def wsl_to_windows_drive(p: str) -> str | None:
    p = p.strip().strip('"').strip("'")
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", p)
    if not m:
        return None
    drive = m.group(1).upper()
    rest = m.group(2).replace("/", "\\")
    return f"{drive}:\\{rest}"


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


def wsl_posix_to_windows_unc(wsl_path: str) -> str | None:
    if not is_wsl():
        return None

    distro = get_wsl_distro_name() or "WSL"
    p = normalize_posix_path(wsl_path)
    rest = p.lstrip("/").replace("/", "\\")
    return f"\\\\wsl$\\{distro}\\{rest}"


# -----------------------
# Auto-normalizer
# -----------------------
def auto_normalize_input(raw: str, debug: bool = False) -> str:
    s = raw.strip()
    s = s.strip().strip('"').strip("'").strip()

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
            elif rest.startswith("Users\\") or rest.startswith("Program Files\\") or rest.startswith("Windows\\"):
                s = f"{drive}:\\{rest}"
                if debug:
                    print(f"[debug] normalized drive colon segment -> {s}")

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
            print("   Your shell likely ate the backslashes (WSL bash/zsh treats \\ as escape).")
            print("")
            print("   Use one of these instead:")
            print(r"     cop -l 'C:\Users\tyler\Music\mine\Active\moments'")
            print(r"     cop -l C:/Users/tyler/Music/mine/Active/moments")
            print(r"     cop -l C:\\Users\\tyler\\Music\\mine\\Active\\moments")
            print("")


def convert_paths(input_path: str) -> dict | None:
    raw = input_path.strip()

    wsl = windows_to_wsl_drive(raw)
    if wsl:
        return {"windows": raw.replace("/", "\\"), "wsl": wsl, "kind": "drive"}

    wsl2 = windows_unc_to_wsl(raw)
    if wsl2:
        return {"windows": raw.replace("/", "\\"), "wsl": wsl2, "kind": "unc"}

    win = wsl_to_windows_drive(raw)
    if win:
        wsl_norm = normalize_posix_path(raw)
        return {"windows": win, "wsl": wsl_norm, "kind": "drive"}

    if raw.startswith("/") or raw.startswith("~") or raw.startswith("./") or raw.startswith("../"):
        wsl_norm = normalize_posix_path(raw)
        if is_wsl():
            win_unc = wsl_posix_to_windows_unc(wsl_norm)
            return {"windows": win_unc, "wsl": wsl_norm, "kind": "posix"}
        else:
            return {"windows": None, "wsl": wsl_norm, "kind": "posix"}

    return None


# -----------------------
# Clipboard helper
# -----------------------
def _run_clip_cmd(cmd: list[str], text_bytes: bytes) -> bool:
    try:
        subprocess.run(cmd, input=text_bytes, check=True)
        return True
    except Exception:
        return False


def copy_to_clipboard(text: str, debug: bool = False, no_fail: bool = False) -> bool:
    try:
        if is_wsl():
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            if debug:
                print(f"[debug] is_wsl=True, trying clip.exe: {clip}")
            if _run_clip_cmd([clip], text.encode("utf-16le")):
                print("📋 Copied to clipboard!")
                return True

        if os.name == "nt":
            clip = shutil.which("clip") or "clip"
            if debug:
                print(f"[debug] os.name=nt, trying clip: {clip}")
            if _run_clip_cmd([clip], text.encode("utf-16le")):
                print("📋 Copied to clipboard!")
                return True

        wl = shutil.which("wl-copy")
        xc = shutil.which("xclip")
        xs = shutil.which("xsel")
        pb = shutil.which("pbcopy")

        if debug:
            print(f"[debug] wl-copy={wl} xclip={xc} xsel={xs} pbcopy={pb}")

        if wl and _run_clip_cmd([wl], text.encode("utf-8")):
            print("📋 Copied to clipboard!")
            return True
        if xc and _run_clip_cmd([xc, "-selection", "clipboard"], text.encode("utf-8")):
            print("📋 Copied to clipboard!")
            return True
        if xs and _run_clip_cmd([xs, "--clipboard", "--input"], text.encode("utf-8")):
            print("📋 Copied to clipboard!")
            return True
        if pb and _run_clip_cmd([pb], text.encode("utf-8")):
            print("📋 Copied to clipboard!")
            return True

        msg = "No clipboard tool found (clip.exe / Windows clip / wl-copy / xclip / xsel / pbcopy)."
        if no_fail:
            print(f"⚠️ Clipboard unavailable: {msg}")
            return False
        raise RuntimeError(msg)

    except Exception as e:
        if no_fail:
            print(f"⚠️ Clipboard unavailable: {e}")
            return False
        print(f"⚠️ Clipboard failed: {e}")
        return False


def prompt_nonempty(msg: str) -> str:
    while True:
        s = input(msg).strip()
        if s:
            return s
        print("⚠️ Please enter a path (or use -a for current directory).")


# -----------------------
# Open helpers
# -----------------------
def open_windows_explorer_at_wsl_path(wsl_path: str, select: bool = False):
    if not is_wsl():
        print("❌ Not running inside WSL. Windows Explorer open is WSL-only.")
        return

    p = normalize_posix_path(wsl_path)
    win_drive = wsl_to_windows_drive(p)
    target = win_drive if win_drive else (wsl_posix_to_windows_unc(p) or None)

    if not target:
        print(f"❌ Could not convert to Windows path: {p}")
        return

    explorer = shutil.which("explorer.exe") or "/mnt/c/Windows/explorer.exe"
    if not os.path.exists(explorer):
        explorer = "explorer.exe"

    if select:
        subprocess.Popen([explorer, "/select,", target])
    else:
        subprocess.Popen([explorer, target])

    print(f"🪟 Opened Windows Explorer: {target}")


def open_thunar(path: str):
    thunar = shutil.which("thunar")
    if not thunar:
        print("❌ Thunar not found. Install it with: sudo apt install thunar")
        return

    p = normalize_posix_path(path)
    subprocess.Popen([thunar, p])
    print(f"🐧 Opened Thunar: {p}")


# -----------------------
# File rename helpers
# -----------------------
def strip_all_suffixes(filename: str) -> str:
    p = Path(filename)
    while p.suffix:
        p = p.with_suffix("")
    return p.name


def remove_extensions_in_directory(directory: str, remove_all: bool = False) -> int:
    directory = normalize_posix_path(directory)

    if not os.path.isdir(directory):
        print(f"❌ Not a valid directory: {directory}")
        return 2

    renamed_count = 0
    skipped_count = 0

    print(f"📁 Processing directory: {directory}")

    for filename in os.listdir(directory):
        full_path = os.path.join(directory, filename)

        if not os.path.isfile(full_path):
            continue

        if remove_all:
            new_name = strip_all_suffixes(filename)
        else:
            new_name = os.path.splitext(filename)[0]

        if new_name == filename:
            continue

        new_path = os.path.join(directory, new_name)

        if os.path.exists(new_path):
            print(f"⚠️ Skipped (would overwrite): {new_name}")
            skipped_count += 1
            continue

        try:
            os.rename(full_path, new_path)
            print(f"Renamed: {filename} → {new_name}")
            renamed_count += 1
        except Exception as e:
            print(f"⚠️ Failed to rename {filename}: {e}")
            skipped_count += 1

    print(f"\n✅ Done! Renamed {renamed_count} file(s).")
    if skipped_count:
        print(f"⚠️ Skipped {skipped_count} file(s).")

    return 0


def normalize_extension(new_ext: str) -> str:
    new_ext = new_ext.strip()
    if not new_ext:
        return ""
    if new_ext.startswith("."):
        return new_ext
    return "." + new_ext


def rename_files_with_new_extension(directory: str, new_ext: str) -> int:
    directory = normalize_posix_path(directory)
    new_ext = normalize_extension(new_ext)

    if not os.path.isdir(directory):
        print(f"❌ Not a valid directory: {directory}")
        return 2

    if not new_ext:
        print("❌ No extension provided.")
        return 2

    renamed_count = 0
    skipped_count = 0

    print(f"📁 Processing directory: {directory}")
    print(f"🧩 New extension: {new_ext}")

    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)

        if not os.path.isfile(filepath):
            continue

        base = os.path.splitext(filename)[0]
        new_filename = base + new_ext
        new_filepath = os.path.join(directory, new_filename)

        if filename == new_filename:
            continue

        if os.path.exists(new_filepath):
            print(f"⚠️ Skipped (would overwrite): {new_filename}")
            skipped_count += 1
            continue

        try:
            os.rename(filepath, new_filepath)
            print(f"Renamed: {filename} -> {new_filename}")
            renamed_count += 1
        except Exception as e:
            print(f"⚠️ Failed to rename {filename}: {e}")
            skipped_count += 1

    print(f"\n✅ Done! Renamed {renamed_count} file(s).")
    if skipped_count:
        print(f"⚠️ Skipped {skipped_count} file(s).")

    return 0


# -----------------------
# Main
# -----------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cop",
        description="Convert paths, copy them, open Explorer/Thunar, remove extensions, or set a new extension on files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=r"""
Examples:
  cop -l 'C:\Users\tyler\Music\mine\Active\moments'
      Convert Windows path to WSL and copy POSIX path.

  cop -E
      Open Windows Explorer at current directory.

  cop -R /mnt/c/testfolder
      Remove only the last extension from files.

  cop --remove-extensions-all /mnt/c/testfolder
      Remove all extensions from files.
      archive.tar.gz -> archive

  cop -X py /mnt/c/testfolder
      Change all regular files in that directory to .py

  cop --set-extension-active sh
      Change all regular files in current directory to .sh
""",
    )

    parser.add_argument("path", nargs="*", help="Path to convert or use as target directory.")
    parser.add_argument("-a", "--active", action="store_true", help="Use current working directory.")
    parser.add_argument("-w", "--windows", action="store_true", help="Copy Windows path.")
    parser.add_argument("-l", "--wsl", action="store_true", help="Copy POSIX path.")
    parser.add_argument("-b", "--both", action="store_true", help="Copy both paths.")
    parser.add_argument("-q", "--quiet", action="store_true", help="Suppress output (still copies).")

    parser.add_argument("--debug", action="store_true", help="Print detection info and normalization choices.")
    parser.add_argument(
        "--no-clip-fail",
        action="store_true",
        help="Do not treat missing clipboard tools as an error.",
    )

    parser.add_argument("-e", "--explore", action="store_true", help="Open Windows Explorer at resolved path (WSL only).")
    parser.add_argument("-E", "--explore-active", action="store_true", help="Open Windows Explorer at current working directory.")
    parser.add_argument("--select", action="store_true", help="When opening Explorer, select the file instead of opening folder.")

    parser.add_argument("-t", "--thunar", action="store_true", help="Open Thunar at resolved path.")
    parser.add_argument("-T", "--thunar-active", action="store_true", help="Open Thunar at current working directory.")

    parser.add_argument("-R", "--remove-extensions", action="store_true",
                        help="Remove only the last extension from regular files in the target directory.")
    parser.add_argument("--remove-extensions-active", action="store_true",
                        help="Remove only the last extension from regular files in the current directory.")

    parser.add_argument("--remove-extensions-all", action="store_true",
                        help="Remove all extensions from regular files in the target directory.")
    parser.add_argument("--remove-extensions-all-active", action="store_true",
                        help="Remove all extensions from regular files in the current directory.")

    parser.add_argument("-X", "--set-extension", metavar="EXT",
                        help="Set all regular files in the target directory to the given extension.")
    parser.add_argument("--set-extension-active", metavar="EXT",
                        help="Set all regular files in the current directory to the given extension.")

    args = parser.parse_args()

    special_flags = sum([
        args.explore,
        args.explore_active,
        args.thunar,
        args.thunar_active,
        args.remove_extensions,
        args.remove_extensions_active,
        args.remove_extensions_all,
        args.remove_extensions_all_active,
        bool(args.set_extension),
        bool(args.set_extension_active),
    ])
    if special_flags > 1:
        print("❌ Choose only one special action at a time.")
        return 2

    if args.thunar_active:
        open_thunar(str(Path.cwd()))
        return 0

    if args.explore_active:
        open_windows_explorer_at_wsl_path(str(Path.cwd()), select=False)
        return 0

    if args.remove_extensions_active:
        return remove_extensions_in_directory(str(Path.cwd()), remove_all=False)

    if args.remove_extensions_all_active:
        return remove_extensions_in_directory(str(Path.cwd()), remove_all=True)

    if args.set_extension_active:
        return rename_files_with_new_extension(str(Path.cwd()), args.set_extension_active)

    if args.active:
        input_path = str(Path.cwd())
    else:
        input_path = " ".join(args.path).strip()

    needs_path = any([
        args.explore,
        args.thunar,
        args.remove_extensions,
        args.remove_extensions_all,
        bool(args.set_extension),
    ]) or not input_path

    if not input_path and needs_path:
        input_path = prompt_nonempty("Enter a path: ")

    normalized = auto_normalize_input(input_path, debug=args.debug)

    if args.debug and normalized != input_path:
        print(f"[debug] raw:        {input_path}")
        print(f"[debug] normalized: {normalized}")

    warn_if_backslashes_were_eaten(normalized)

    converted = convert_paths(normalized)
    if not converted:
        print("❌ Unrecognized path format.")
        print(r"   Try: /mnt/x/..., X:\..., \\wsl$\Distro\..., ~/..., /usr/... ")
        return 2

    if args.remove_extensions:
        return remove_extensions_in_directory(converted["wsl"], remove_all=False)

    if args.remove_extensions_all:
        return remove_extensions_in_directory(converted["wsl"], remove_all=True)

    if args.set_extension:
        return rename_files_with_new_extension(converted["wsl"], args.set_extension)

    if args.thunar:
        open_thunar(converted["wsl"])
        return 0

    if args.explore:
        open_windows_explorer_at_wsl_path(converted["wsl"], select=args.select)
        return 0

    if not args.quiet:
        w = converted["windows"] if converted["windows"] else "(n/a)"
        print(f"Windows: {w}")
        print(f"POSIX:   {converted['wsl']}")

    mode_flags = sum([args.windows, args.wsl, args.both])
    if mode_flags > 1:
        print("❌ Choose only one of -w / -l / -b.")
        return 2

    def require_windows_path() -> str | None:
        return converted["windows"] if converted["windows"] else None

    if args.windows:
        winp = require_windows_path()
        if not winp:
            print("❌ No Windows path available for this environment/path (not WSL or not mappable).")
            return 2
        ok = copy_to_clipboard(winp, debug=args.debug, no_fail=args.no_clip_fail)
        return 0 if (ok or args.no_clip_fail) else 2

    if args.wsl:
        ok = copy_to_clipboard(converted["wsl"], debug=args.debug, no_fail=args.no_clip_fail)
        return 0 if (ok or args.no_clip_fail) else 2

    if args.both:
        winp = converted["windows"]
        win_line = f"Windows: {winp}" if winp else "Windows: (n/a)"
        block = f"{win_line}\nPOSIX:   {converted['wsl']}\n"
        ok = copy_to_clipboard(block, debug=args.debug, no_fail=args.no_clip_fail)
        return 0 if (ok or args.no_clip_fail) else 2

    choice = input("Copy which? (w = Windows, l = POSIX, b = both, Enter = none): ").strip().lower()
    if choice == "w":
        winp = require_windows_path()
        if not winp:
            print("❌ No Windows path available for this environment/path.")
            return 2
        copy_to_clipboard(winp, debug=args.debug, no_fail=args.no_clip_fail)
    elif choice == "l":
        copy_to_clipboard(converted["wsl"], debug=args.debug, no_fail=args.no_clip_fail)
    elif choice == "b":
        winp = converted["windows"]
        win_line = f"Windows: {winp}" if winp else "Windows: (n/a)"
        block = f"{win_line}\nPOSIX:   {converted['wsl']}\n"
        copy_to_clipboard(block, debug=args.debug, no_fail=args.no_clip_fail)
    else:
        if not args.quiet:
            print("ℹ️ Nothing copied.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
