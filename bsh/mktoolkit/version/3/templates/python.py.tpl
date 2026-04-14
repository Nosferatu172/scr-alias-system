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
# ENVIRONMENT DETECTION
# ==================================================

import platform
import os

def detect_os():
    system = platform.system().lower()
    if system == "linux":
        try:
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if line.startswith("ID="):
                        return line.split("=")[1].strip().strip('"')
        except:
            pass
        return "linux"
    elif system == "darwin":
        return "macos"
    elif system == "windows":
        return "windows"
    else:
        return "unknown"

def detect_arch():
    return platform.machine()

def detect_env():
    if "WSL_DISTRO_NAME" in os.environ:
        return "wsl"
    elif "TERMUX_VERSION" in os.environ:
        return "termux"
    elif os.path.exists("/mnt/c"):
        return "wsl"
    else:
        return "native"

def detect_wsl():
    # Check for WSL environment variables
    if "WSL_DISTRO_NAME" in os.environ:
        # WSL_DISTRO_NAME exists in both WSL1 and WSL2
        return "wsl"
    elif "WSLENV" in os.environ or "WSL_INTEROP" in os.environ:
        # WSLENV/WSL_INTEROP indicate WSL2 interop
        return "wsl2"
    elif os.path.exists("/mnt/c") and os.path.exists("/proc/version"):
        try:
            with open("/proc/version", "r") as f:
                content = f.read().lower()
                if "microsoft" in content or "wsl" in content:
                    return "wsl"
        except (OSError, IOError):
            pass
    return "false"

def detect_wsl_distro():
    if "WSL_DISTRO_NAME" in os.environ:
        return os.environ["WSL_DISTRO_NAME"]
    elif os.path.exists("/etc/os-release"):
        try:
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME="):
                        return line.split("=", 1)[1].strip().strip('"')
        except:
            pass
    return "unknown"


# ==================================================
# SCR ENVIRONMENT CORE (UNIFIED VIEW)
# ==================================================

_scr_env_cache = None

def scr_env():
    global _scr_env_cache
    if _scr_env_cache is None:
        env = {
            'os': 'unknown',
            'arch': platform.machine(),
            'distro': None,
            'wsl': False,
            'mode': 'native'
        }

        # OS detection
        system = platform.system().lower()
        if system == "linux":
            env['os'] = 'linux'
            if os.path.exists("/etc/os-release"):
                try:
                    with open("/etc/os-release", "r") as f:
                        for line in f:
                            if line.startswith("ID="):
                                env['distro'] = line.split("=", 1)[1].strip().strip('"')
                                break
                except:
                    pass
        elif system == "darwin":
            env['os'] = 'macos'
        elif system == "windows":
            env['os'] = 'windows'

        # WSL detection
        env['wsl'] = (
            "WSL_DISTRO_NAME" in os.environ or
            "WSLENV" in os.environ or
            "WSL_INTEROP" in os.environ or
            (os.path.exists("/mnt/c") and os.path.exists("/proc/version") and
             "microsoft" in open("/proc/version").read().lower())
        )

        # Mode
        env['mode'] = 'wsl' if env['wsl'] else env['os']

        _scr_env_cache = env

    return _scr_env_cache


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