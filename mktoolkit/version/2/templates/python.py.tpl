#!/usr/bin/env python3

# ============================================
# Script Name: __SCRIPT_NAME__
# Purpose: __PURPOSE__
# Created: __DATE__
# Path: __FULL_PATH__
# ============================================

from __future__ import annotations

import sys
import argparse
from pathlib import Path


# ==================================================
# PATHS
# ==================================================

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
SCRIPT_NAME = SCRIPT_PATH.name


# ==================================================
# COLORS (OPTIONAL UI LAYER)
# ==================================================

CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"


def info(msg: str): print(f"{CYAN}[+] {msg}{RESET}")
def success(msg: str): print(f"{GREEN}[✔] {msg}{RESET}")
def warn(msg: str): print(f"{YELLOW}[!] {msg}{RESET}")
def error(msg: str): print(f"{RED}[✖] {msg}{RESET}")


# ==================================================
# HELP SYSTEM (MULTI-ENTRY SUPPORT)
# ==================================================

def show_help():
    print(f"""
{SCRIPT_NAME}

Usage:
  python {SCRIPT_NAME} [options]

Help:
  -h, --h, --help, help     Show this help

Options:
  -v, --verbose             Verbose output
  --debug                   Debug mode
  -q, --quiet               Minimal output
""")
    sys.exit(0)


def handle_help_flags(args: list[str]):
    if not args:
        return

    if any(x in args for x in ["-h", "--h", "--help", "help"]):
        show_help()


# ==================================================
# ENV HOOK SYSTEM (YOUR VPY INTEGRATION)
# ==================================================

def pre_run_env():
    """
    Hook: runs BEFORE main logic
    Used for venv activation or dependency setup
    """
    try:
        import os

        # optional: your system hook
        os.system("vpy on")

    except Exception:
        pass


def post_run_env():
    """
    Hook: runs AFTER main logic
    """
    try:
        import os
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

    parser.add_argument("-h", "--h", "--help", action="store_true")

    return parser


# ==================================================
# MAIN LOGIC
# ==================================================

def run(args):
    if args.verbose:
        info(f"Running {SCRIPT_NAME}")
        info(f"Directory: {SCRIPT_DIR}")

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

    # manual help override system
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