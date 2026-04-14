#!/usr/bin/env python3

# ============================================
# Script Name: __SCRIPT_NAME__
# ID: __SCR_ID__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
# Assigned with: mktool
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: __ALIAS_CALL__
# ============================================

from __future__ import annotations

import sys
import argparse
from pathlib import Path
import platform
import os


# ==================================================
# PATHS
# ==================================================

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
SCRIPT_NAME = SCRIPT_PATH.name


# ==================================================
# COLORS
# ==================================================

CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"


def info(msg): print(f"{CYAN}[+] {msg}{RESET}")
def success(msg): print(f"{GREEN}[✔] {msg}{RESET}")
def warn(msg): print(f"{YELLOW}[!] {msg}{RESET}")
def error(msg): print(f"{RED}[✖] {msg}{RESET}")


# ==================================================
# SCR ENVIRONMENT CORE (SINGLE SOURCE OF TRUTH)
# ==================================================

_scr_env_cache = None


def scr_env():
    global _scr_env_cache

    if _scr_env_cache is None:
        env = {
            "os": "unknown",
            "arch": platform.machine(),
            "distro": None,
            "wsl": False,
            "mode": "native",
        }

        system = platform.system().lower()

        # OS detection
        if system == "linux":
            env["os"] = "linux"

            try:
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if line.startswith("ID="):
                            env["distro"] = line.split("=", 1)[1].strip().strip('"')
                            break
            except Exception:
                pass

        elif system == "darwin":
            env["os"] = "macos"

        elif system == "windows":
            env["os"] = "windows"

        # WSL detection (safe)
        try:
            if (
                "WSL_DISTRO_NAME" in os.environ
                or "WSLENV" in os.environ
                or "WSL_INTEROP" in os.environ
            ):
                env["wsl"] = True
            elif os.path.exists("/mnt/c") and os.path.exists("/proc/version"):
                with open("/proc/version", "r") as f:
                    if "microsoft" in f.read().lower():
                        env["wsl"] = True
        except Exception:
            env["wsl"] = False

        env["mode"] = "wsl" if env["wsl"] else env["os"]

        _scr_env_cache = env

    return _scr_env_cache


# ==================================================
# HELP SYSTEM
# ==================================================

def show_help():
    print(f"""
{SCRIPT_NAME}

Usage:
  python {SCRIPT_NAME} [options]

Options:
  -v, --verbose
  --debug
  -q, --quiet
  -h, --help
""")
    sys.exit(0)


def handle_help_flags(args):
    if any(x in args for x in ["-h", "--h", "--help", "help"]):
        show_help()


# ==================================================
# ENV HOOK SYSTEM
# ==================================================

def pre_run_env():
    try:
        os.system("vpy on")
    except Exception:
        pass


def post_run_env():
    try:
        os.system("vpy off")
    except Exception:
        pass


# ==================================================
# ARG PARSER
# ==================================================

def build_parser():
    parser = argparse.ArgumentParser(add_help=False)

    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("-q", "--quiet", action="store_true")
    parser.add_argument("-h", "--help", action="store_true")

    return parser


# ==================================================
# MAIN LOGIC
# ==================================================

def run(args):
    env = scr_env()

    if args.verbose:
        info(f"Running {SCRIPT_NAME}")
        info(f"Directory: {SCRIPT_DIR}")
        info(f"OS: {env['os']} | WSL: {env['wsl']} | Mode: {env['mode']}")

    if args.debug:
        warn("Debug mode enabled")

    # -----------------------------
    # YOUR LOGIC HERE
    # -----------------------------

    success("Finished successfully")


# ==================================================
# ENTRYPOINT
# ==================================================

def main():
    raw_args = sys.argv[1:]

    handle_help_flags(raw_args)

    parser = build_parser()
    args = parser.parse_args(raw_args)

    pre_run_env()

    try:
        run(args)
        return 0
    except Exception as e:
        error(str(e))
        return 1
    finally:
        post_run_env()


if __name__ == "__main__":
    raise SystemExit(main())
