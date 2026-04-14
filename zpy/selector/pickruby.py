#!/usr/bin/env python3

import curses
import subprocess
import sys
import argparse


# ----------------------------
# core helpers
# ----------------------------

def run(cmd):
    return subprocess.check_output(cmd, text=True).strip()


def try_run(cmd):
    try:
        return run(cmd)
    except subprocess.CalledProcessError:
        return None


# ----------------------------
# rbenv data
# ----------------------------

def get_versions():
    out = run(["rbenv", "versions", "--bare"])
    return [v.strip() for v in out.splitlines() if v.strip()]


def get_active():
    return run(["rbenv", "version"]).split()[0]


def get_gems():
    out = try_run(["gem", "list"])
    return out if out else "No gems found."


# ----------------------------
# TUI selector
# ----------------------------

def menu(stdscr, versions, active):
    curses.curs_set(0)
    selected = 0

    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, "🧠 Ruby Version Selector")
        stdscr.addstr(1, 0, "↑ ↓ move | Enter select | q quit")
        stdscr.addstr(2, 0, f"Active: {active}")
        stdscr.addstr(3, 0, "-----------------------------------")

        for i, v in enumerate(versions):
            prefix = "👉" if i == selected else "  "
            marker = " (active)" if v == active else ""
            line = f"{prefix} {v}{marker}"

            if i == selected:
                stdscr.addstr(i + 5, 0, line, curses.A_REVERSE)
            else:
                stdscr.addstr(i + 5, 0, line)

        key = stdscr.getch()

        if key == curses.KEY_UP:
            selected = (selected - 1) % len(versions)
        elif key == curses.KEY_DOWN:
            selected = (selected + 1) % len(versions)
        elif key in (10, 13):
            return versions[selected]
        elif key == ord('q'):
            return None


# ----------------------------
# actions
# ----------------------------

def set_version(version, mode):
    if mode == "local":
        subprocess.run(["rbenv", "local", version], check=True)
    else:
        subprocess.run(["rbenv", "global", version], check=True)

    subprocess.run(["rbenv", "rehash"], check=True)


# ----------------------------
# CLI
# ----------------------------

def main():
    parser = argparse.ArgumentParser(description="rbenv picker tool")

    parser.add_argument("-l", "--list", action="store_true", help="list installed versions")
    parser.add_argument("-a", "--active", action="store_true", help="show active version")
    parser.add_argument("-g", "--gems", action="store_true", help="list gems for active version")

    # new flags
    parser.add_argument("-loc", action="store_true", help="set local version")
    parser.add_argument("-glo", action="store_true", help="set global version")

    # compatibility
    parser.add_argument("--local", action="store_true", help="set local version (long form)")

    args = parser.parse_args()

    # determine mode
    mode = "global"
    if args.loc or args.local:
        mode = "local"
    elif args.glo:
        mode = "global"

    # flags
    if args.list:
        for v in get_versions():
            print(v)
        return

    if args.active:
        print(get_active())
        return

    if args.gems:
        print(get_gems())
        return

    # interactive mode
    versions = get_versions()
    if not versions:
        print("❌ No Ruby versions installed.")
        sys.exit(1)

    active = get_active()
    choice = curses.wrapper(menu, versions, active)

    if not choice:
        print("Cancelled.")
        return

    print(f"\n✅ Selected: {choice} ({mode})")

    set_version(choice, mode)

    print(f"👉 Now using: {run(['ruby', '-v'])}")


if __name__ == "__main__":
    main()
