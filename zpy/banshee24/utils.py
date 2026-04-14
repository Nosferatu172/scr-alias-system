#!/usr/bin/env python3
# Script Name: utils.py
# ID: SCR-ID-20260328150001-O4UEK13UK6
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: utils

import sys
from datetime import datetime
from pathlib import Path

LOG_DIR = Path(__file__).resolve().parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

def log_message(msg, file="script.log"):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_DIR / file, "a") as f:
        f.write(f"[{ts}] {msg}\n")


def prompt_choice(title, prompt="> ", allow_back=True, allow_exit=True):
    print(title)
    ans = input(prompt)

    if ans is None:
        return "exit"

    ans = ans.strip()

    if allow_back and ans.lower() == "b":
        return "back"

    if allow_exit and ans.lower() == "e":
        return "exit"

    return ans


def show_header():
    print("banshee22")
    print(f"[run] banshee22 -> {sys.argv[0]}")
