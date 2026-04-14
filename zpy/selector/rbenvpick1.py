#!/usr/bin/env python3

import curses
import subprocess
import sys

def get_versions():
    try:
        output = subprocess.check_output(
            ["rbenv", "versions", "--bare"],
            text=True
        )
        versions = [line.strip() for line in output.splitlines() if line.strip()]
        return versions
    except Exception as e:
        print(f"Error getting versions: {e}")
        sys.exit(1)

def run_command(cmd):
    subprocess.run(cmd, check=True)

def menu(stdscr, versions):
    curses.curs_set(0)  # hide cursor
    selected = 0

    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, "🧠 Select Ruby version (↑ ↓ + Enter)")
        stdscr.addstr(1, 0, "-----------------------------------")

        for i, v in enumerate(versions):
            if i == selected:
                stdscr.addstr(i + 3, 0, f"👉 {v}", curses.A_REVERSE)
            else:
                stdscr.addstr(i + 3, 0, f"   {v}")

        key = stdscr.getch()

        if key == curses.KEY_UP:
            selected = (selected - 1) % len(versions)
        elif key == curses.KEY_DOWN:
            selected = (selected + 1) % len(versions)
        elif key in [curses.KEY_ENTER, 10, 13]:
            return versions[selected]

def main():
    versions = get_versions()

    if not versions:
        print("❌ No Ruby versions installed.")
        sys.exit(1)

    choice = curses.wrapper(menu, versions)

    print(f"\n✅ Selected Ruby: {choice}")

    try:
        run_command(["rbenv", "global", choice])
        run_command(["rbenv", "rehash"])
    except subprocess.CalledProcessError:
        print("❌ Failed to set Ruby version.")
        sys.exit(1)

    ruby_version = subprocess.check_output(["ruby", "-v"], text=True).strip()
    print(f"👉 Now using: {ruby_version}")

if __name__ == "__main__":
    main()
