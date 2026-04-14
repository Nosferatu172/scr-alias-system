#!/usr/bin/env python3

import curses
import subprocess
import os
import sys
import argparse


# ----------------------------
# helpers
# ----------------------------

def run(cmd):
    return subprocess.check_output(cmd, text=True).strip()

def try_run(cmd):
    try:
        return run(cmd)
    except:
        return None


# ----------------------------
# detection
# ----------------------------

def detect_project():
    cwd = os.getcwd()

    while True:
        if os.path.exists(os.path.join(cwd, "requirements.txt")) or os.path.exists(os.path.join(cwd, ".venv")):
            return "py"
        if os.path.exists(os.path.join(cwd, "Gemfile")) or os.path.exists(os.path.join(cwd, ".ruby-env")):
            return "rb"

        parent = os.path.dirname(cwd)
        if parent == cwd:
            break
        cwd = parent

    return None


# ----------------------------
# providers
# ----------------------------

def rb_versions():
    return run(["rbenv", "versions", "--bare"]).splitlines()

def rb_active():
    return run(["rbenv", "version"]).split()[0]

def rb_set(version, mode):
    subprocess.run(["rbenv", mode, version])
    subprocess.run(["rbenv", "rehash"])

def rb_gems():
    return run(["gem", "list"])


def py_versions():
    # show detected envs (simple)
    paths = []
    cwd = os.getcwd()

    while True:
        for name in [".venv", "venv", "env"]:
            p = os.path.join(cwd, name)
            if os.path.exists(os.path.join(p, "bin", "activate")):
                paths.append(p)

        parent = os.path.dirname(cwd)
        if parent == cwd:
            break
        cwd = parent

    # fallback
    home = os.path.expanduser("~/.venv")
    if os.path.exists(os.path.join(home, "bin", "activate")):
        paths.append(home)

    return list(dict.fromkeys(paths))


def py_active():
    return os.environ.get("VIRTUAL_ENV", "none")

def py_set(path, mode):
    print(f"👉 Run manually: vpy on {path}")

def py_gems():
    return run(["pip", "list"])


PROVIDERS = {
    "rb": {
        "list": rb_versions,
        "active": rb_active,
        "set": rb_set,
        "gems": rb_gems,
    },
    "py": {
        "list": py_versions,
        "active": py_active,
        "set": py_set,
        "gems": py_gems,
    }
}


# ----------------------------
# UI
# ----------------------------

def menu(stdscr, items, active):
    curses.curs_set(0)
    selected = 0

    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, "🧠 envic selector")
        stdscr.addstr(1, 0, f"Active: {active}")
        stdscr.addstr(2, 0, "↑ ↓ move | Enter select | q quit")

        for i, item in enumerate(items):
            marker = " (active)" if item == active else ""
            line = f"{item}{marker}"

            if i == selected:
                stdscr.addstr(i + 4, 0, f"👉 {line}", curses.A_REVERSE)
            else:
                stdscr.addstr(i + 4, 0, f"   {line}")

        key = stdscr.getch()

        if key == curses.KEY_UP:
            selected = (selected - 1) % len(items)
        elif key == curses.KEY_DOWN:
            selected = (selected + 1) % len(items)
        elif key in (10, 13):
            return items[selected]
        elif key == ord('q'):
            return None


# ----------------------------
# commands
# ----------------------------

def cmd_pick(provider, mode):
    p = PROVIDERS[provider]
    items = p["list"]()

    if not items:
        print("❌ nothing found")
        return

    active = p["active"]()
    choice = curses.wrapper(menu, items, active)

    if not choice:
        print("cancelled")
        return

    print(f"✅ {provider} → {choice}")

    if provider == "py":
        py_set(choice, mode)
    else:
        p["set"](choice, mode)

    print("👉 done")


def cmd_status():
    print("==== envic status ====")
    print(f"Python: {py_active()}")
    print(f"Ruby  : {rb_active()}")


def cmd_on(provider):
    if provider == "py":
        subprocess.run(["vpy", "on"])
    elif provider == "rb":
        subprocess.run(["vry", "on"])
    else:
        auto = detect_project()
        if auto:
            cmd_on(auto)
        else:
            print("❌ no project detected")


def cmd_off(provider):
    if provider == "py":
        subprocess.run(["vpy", "off"])
    elif provider == "rb":
        subprocess.run(["vry", "off"])
    else:
        subprocess.run(["vpy", "off"])
        subprocess.run(["vry", "off"])


# ----------------------------
# CLI
# ----------------------------

def main():
    parser = argparse.ArgumentParser(description="envic")

    parser.add_argument("command", nargs="?", default="pick")
    parser.add_argument("provider", nargs="?")

    parser.add_argument("-l", action="store_true")
    parser.add_argument("-a", action="store_true")
    parser.add_argument("-g", action="store_true")

    parser.add_argument("-loc", action="store_true")
    parser.add_argument("-glo", action="store_true")

    args = parser.parse_args()

    provider = args.provider or detect_project() or "rb"

    mode = "global"
    if args.loc:
        mode = "local"
    if args.glo:
        mode = "global"

    if args.l:
        print("\n".join(PROVIDERS[provider]["list"]()))
        return

    if args.a:
        print(PROVIDERS[provider]["active"]())
        return

    if args.g:
        print(PROVIDERS[provider]["gems"]())
        return

    if args.command == "pick":
        cmd_pick(provider, mode)
    elif args.command == "on":
        cmd_on(provider)
    elif args.command == "off":
        cmd_off(provider)
    elif args.command == "status":
        cmd_status()
    else:
        print("unknown command")


if __name__ == "__main__":
    main()
