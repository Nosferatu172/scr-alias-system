#!/usr/bin/env python3
# Script Name: alias_scan.py
# ID: SCR-ID-20260329040915-3CRRXVO2DC
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: alias_scan

import os
import re
from pathlib import Path

# -----------------------------------------
# Prompt for directory
# -----------------------------------------
try:
    target = input("Directory to scan for aliases: ").strip()
except KeyboardInterrupt:
    print("\nCancelled.")
    exit(1)

scan_dir = Path(target).expanduser().resolve()

if not scan_dir.exists() or not scan_dir.is_dir():
    print("Invalid directory.")
    exit(1)

# -----------------------------------------
# Output file (one directory above)
# -----------------------------------------
log_path = scan_dir.parent / "log.txt"

# -----------------------------------------
# Regex for alias detection
# -----------------------------------------
alias_pattern = re.compile(r'^\s*alias\s+([A-Za-z0-9_\-]+)=')

aliases = set()

# -----------------------------------------
# Scan files
# -----------------------------------------
for root, dirs, files in os.walk(scan_dir):

    for file in files:

        filepath = Path(root) / file

        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:

                    stripped = line.strip()

                    # Skip commented lines
                    if stripped.startswith("#"):
                        continue

                    match = alias_pattern.search(line)

                    if match:
                        aliases.add(match.group(1))

        except Exception:
            pass

# -----------------------------------------
# Write log
# -----------------------------------------
with open(log_path, "w") as log:
    for a in sorted(aliases):
        log.write(a + "\n")

print(f"\n✔ Found {len(aliases)} aliases")
print(f"✔ Log written to: {log_path}")
