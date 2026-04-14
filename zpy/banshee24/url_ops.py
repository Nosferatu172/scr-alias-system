#!/usr/bin/env python3
# Script Name: url_ops.py
# ID: SCR-ID-20260328145953-S5WEIEQKCB
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: url_ops

import os
import csv
from pathlib import Path
from utils import prompt_choice


# -------------------------
# Normalize URL
# -------------------------
def normalize_url(line):
    if line is None:
        return None

    s = str(line).strip()

    if not s or s.startswith("#"):
        return None

    # strip quotes
    s = s.strip('"').strip("'")

    # split on whitespace
    s = s.split()[0].strip()

    if not s.lower().startswith("http"):
        return None

    return s


# -------------------------
# Load TXT
# -------------------------
def load_urls_from_txt(path):
    urls = []

    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            u = normalize_url(line)
            if u:
                urls.append(u)

    return urls


# -------------------------
# Load CSV
# -------------------------
def load_urls_from_csv(path):
    urls = []

    try:
        with open(path, newline="", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)

            for row in reader:
                if not row:
                    continue

                candidate = (
                    row.get("url")
                    or row.get("URL")
                    or row.get("link")
                    or row.get("Link")
                    or row.get("href")
                    or row.get("HREF")
                )

                if not candidate and row:
                    candidate = list(row.values())[0]

                u = normalize_url(candidate)
                if u:
                    urls.append(u)

    except:
        # fallback: no headers
        with open(path, newline="", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            for row in reader:
                if row:
                    u = normalize_url(row[0])
                    if u:
                        urls.append(u)

    return urls


# -------------------------
# Load Any File
# -------------------------
def load_urls_from_file(path):
    ext = Path(path).suffix.lower()

    if ext == ".csv":
        return load_urls_from_csv(path)
    else:
        return load_urls_from_txt(path)


# -------------------------
# Manual Input
# -------------------------
def input_urls_manually():
    urls = []

    print("🎯 Enter URLs one per line (blank line to finish):")

    while True:
        try:
            line = input("> ")
        except EOFError:
            return urls

        if line is None:
            return urls

        line = line.strip()

        if not line:
            break

        u = normalize_url(line)
        if u:
            urls.append(u)

    return urls


# -------------------------
# File Picker
# -------------------------
def select_file_from_directory(directory, exts=(".txt", ".csv")):
    if not os.path.isdir(directory):
        print(f"❌ Directory not found: #{directory}")
        return None

    files = [
        f for f in os.listdir(directory)
        if Path(f).suffix.lower() in exts
    ]

    if not files:
        print(f"⚠️ No {', '.join(exts)} files found in: {directory}")
        return None

    print("\n📂 Select a file from:")
    print(f"   {directory}")

    for i, f in enumerate(files, 1):
        tag = "[CSV]" if f.lower().endswith(".csv") else "[TXT]"
        print(f"  {i}: {tag} {f}")

    ans = prompt_choice("Select number (b=back, e=exit):")

    if ans in ["exit", "back"]:
        return ans

    try:
        idx = int(ans) - 1
        if 0 <= idx < len(files):
            return os.path.join(directory, files[idx])
    except:
        pass

    return None


# -------------------------
# Cookie Helpers
# -------------------------
def list_cookie_files(cookies_dir):
    if not cookies_dir or not os.path.isdir(cookies_dir):
        return []

    return sorted([
        os.path.join(cookies_dir, f)
        for f in os.listdir(cookies_dir)
        if not f.startswith(".") and os.path.isfile(os.path.join(cookies_dir, f))
    ])


def select_cookie_file(cookies_dir):
    files = list_cookie_files(cookies_dir)

    if not files:
        print(f"⚠️ No cookie files found in: {cookies_dir}")
        return None

    print("\n🍪 Select a cookies file from:")
    print(f"   {cookies_dir}")

    for i, f in enumerate(files, 1):
        print(f"  {i}: {os.path.basename(f)}")

    ans = prompt_choice("Select number (b=back, e=exit):")

    if ans in ["exit", "back"]:
        return ans

    try:
        idx = int(ans) - 1
        if 0 <= idx < len(files):
            return files[idx]
    except:
        pass

    return None
