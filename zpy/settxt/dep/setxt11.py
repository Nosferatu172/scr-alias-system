#!/usr/bin/env python3
# setxt_dirs.py
# Clean CSV Directory Manager

import csv
import argparse
from pathlib import Path

# -----------------------
# PATH
# -----------------------
def get_csv_path():
    base = Path(__file__).resolve().parent
    cfg_dir = base / "logs"
    cfg_dir.mkdir(exist_ok=True)
    return cfg_dir / "setxt_dirs.csv"


# -----------------------
# DEFAULT CSV
# -----------------------
def create_default(csv_path):
    if csv_path.exists():
        return

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["name", "type", "path", "enabled", "priority", "notes"])

        w.writerow(["main_tabs", "root", "/mnt/c/scr/keys/tabs", "1", "1", "primary"])
        w.writerow(["msys_tabs", "root", "/c/scr/keys/tabs", "1", "2", "msys"])
        w.writerow(["linux_docs", "root", str(Path.home()), "0", "3", "linux"])
        w.writerow(["output_default", "output", "", "1", "0", "default output"])


# -----------------------
# LOAD
# -----------------------
def load_csv(csv_path):
    rows = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append(r)
    return rows


# -----------------------
# SAVE
# -----------------------
def save_csv(csv_path, rows):
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["name", "type", "path", "enabled", "priority", "notes"]
        )
        writer.writeheader()
        writer.writerows(rows)


# -----------------------
# DISPLAY
# -----------------------
def show(rows):
    print("\n📂 Directory Config:\n")
    for i, r in enumerate(rows, 1):
        status = "ON " if r["enabled"] == "1" else "OFF"
        print(f"[{i}] {status} {r['name']} ({r['type']})")
        print(f"     path: {r['path']}")
        print(f"     prio: {r['priority']} | notes: {r['notes']}")
    print()


# -----------------------
# INTERACTIVE
# -----------------------
def interactive(rows):
    while True:
        show(rows)

        print("Options:")
        print("[1] Add")
        print("[2] Edit")
        print("[3] Toggle enable")
        print("[4] Remove")
        print("[0] Exit")

        c = input("Choice: ").strip()

        if c == "1":
            name = input("Name: ")
            typ = input("Type (root/input/output): ")
            path = input("Path: ")
            rows.append({
                "name": name,
                "type": typ,
                "path": path,
                "enabled": "1",
                "priority": "0",
                "notes": ""
            })

        elif c == "2":
            idx = int(input("Index: ")) - 1
            if 0 <= idx < len(rows):
                r = rows[idx]
                r["path"] = input(f"Path [{r['path']}]: ") or r["path"]
                r["notes"] = input(f"Notes [{r['notes']}]: ") or r["notes"]

        elif c == "3":
            idx = int(input("Index: ")) - 1
            if 0 <= idx < len(rows):
                rows[idx]["enabled"] = "0" if rows[idx]["enabled"] == "1" else "1"

        elif c == "4":
            idx = int(input("Remove index: ")) - 1
            if 0 <= idx < len(rows):
                rows.pop(idx)

        elif c == "0":
            return rows


# -----------------------
# MAIN
# -----------------------
def main():
    parser = argparse.ArgumentParser(description="Manage setxt directory CSV config")
    parser.add_argument("-i", action="store_true", help="Interactive mode")
    parser.add_argument("-l", action="store_true", help="List config")

    args = parser.parse_args()

    csv_path = get_csv_path()
    create_default(csv_path)

    rows = load_csv(csv_path)

    if args.l:
        show(rows)
        return

    if args.i:
        rows = interactive(rows)
        save_csv(csv_path, rows)
        print("💾 Saved.")
        return

    print(f"📄 Config file: {csv_path}")


if __name__ == "__main__":
    main()
