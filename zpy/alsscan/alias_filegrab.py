#!/usr/bin/env python3
# Script Name: alias_filegrab.py
# ID: SCR-ID-20260329040907-EI9AMGX2F2
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alias_filegrab

import os
import re
import shlex
from pathlib import Path

# -----------------------------------------
# Prompt for directory
# -----------------------------------------
try:
    target = input("Directory to scan: ").strip()
except KeyboardInterrupt:
    print("\nCancelled.")
    raise SystemExit(1)

scan_dir = Path(target).expanduser().resolve()

if not scan_dir.is_dir():
    print("Invalid directory.")
    raise SystemExit(1)

# -----------------------------------------
# Output file one level above scan dir
# -----------------------------------------
log_path = scan_dir.parent / "log.txt"

# -----------------------------------------
# Match alias lines
# -----------------------------------------
alias_pattern = re.compile(
    r"""^\s*alias\s+[A-Za-z0-9_-]+\s*=\s*(['"])(.*?)\1"""
)

results = []

# -----------------------------------------
# Helper: clean tokens like ; && ||
# -----------------------------------------
def clean_token(token: str) -> str:
    return token.strip().strip(";").strip("&").strip("|").strip("'").strip('"')

# -----------------------------------------
# Walk files
# -----------------------------------------
for root, _, files in os.walk(scan_dir):
    for file in files:
        filepath = Path(root) / file

        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    stripped = line.strip()

                    if not stripped or stripped.startswith("#"):
                        continue

                    match = alias_pattern.match(line)
                    if not match:
                        continue

                    alias_value = match.group(2).strip()

                    try:
                        parts = shlex.split(alias_value)
                    except Exception:
                        continue

                    # Find every token that looks like a path
                    path_tokens = []
                    for part in parts:
                        token = clean_token(part)
                        if "/" in token or token.startswith("~"):
                            path_tokens.append(token)

                    if not path_tokens:
                        continue

                    # Use the last path-like token in the alias
                    chosen = path_tokens[-1]

                    # Expand ~ if present
                    if chosen.startswith("~"):
                        chosen = str(Path(chosen).expanduser())

                    # Remove trailing slash before basename
                    chosen = chosen.rstrip("/")

                    if not chosen:
                        continue

                    basename = os.path.basename(chosen)

                    if basename:
                        results.append(basename)

        except Exception as e:
            print(f"Skipping {filepath}: {e}")

# -----------------------------------------
# Write log
# -----------------------------------------
with open(log_path, "w", encoding="utf-8") as log:
    for item in results:
        log.write(item + "\n")

print(f"\nWrote {len(results)} entries to:")
print(log_path)
