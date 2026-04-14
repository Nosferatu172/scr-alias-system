#!/usr/bin/env python3
# Script Name: png2jpg.py
# ID: SCR-ID-20260329040946-SN3J6K86BW-EXT
# Created by: Tyler Jensen

import os
import csv
import argparse
from pathlib import Path
from PIL import Image

# ------------------------
# CONFIG
# ------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = SCRIPT_DIR / "png2jpg_config.csv"

def load_config():
    if not CONFIG_FILE.exists():
        return {}
    config = {}
    with open(CONFIG_FILE, newline="") as f:
        for row in csv.reader(f):
            if len(row) >= 2:
                config[row[0]] = row[1]
    return config

def save_config(config):
    with open(CONFIG_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        for k, v in config.items():
            writer.writerow([k, v])

config = load_config()

# ------------------------
# ARGPARSE
# ------------------------
help_text = """
PNG → JPG Converter

Example Usage:
  Convert PNGs in current folder:
      python3 png2jpg.py -a

  Convert PNGs recursively and delete originals:
      python3 png2jpg.py -a -r --delete

  Convert PNGs in custom folder:
      python3 png2jpg.py -i /path/to/pngs -o /path/to/output
"""

parser = argparse.ArgumentParser(
    description=help_text,
    formatter_class=argparse.RawTextHelpFormatter
)

parser.add_argument("-i", "--input", help="Directory or file to process", default=config.get("default_input"))
parser.add_argument("-o", "--output", help="Output directory", default=None)
parser.add_argument("-a", "--active", action="store_true", help="Use current directory for input AND output")
parser.add_argument("-r", "--recursive", action="store_true", help="Process subdirectories recursively")
parser.add_argument("--delete", action="store_true", help="Delete source PNGs after conversion")
parser.add_argument("--flat", action="store_true", help="Do not create subfolder per PNG")
parser.add_argument("--show", action="store_true", help="Show resolved paths and exit")
parser.add_argument("--set-default", action="store_true", help="Save current input as default")

args = parser.parse_args()

# ------------------------
# ACTIVE MODE
# ------------------------
if args.active:
    cwd = Path.cwd()
    args.input = str(cwd)
    if args.output is None:
        args.output = str(cwd)

input_path = Path(args.input).expanduser().resolve()
output_dir = Path(args.output).expanduser().resolve() if args.output else (input_path / "converted_jpgs")

# ------------------------
# SAVE DEFAULT
# ------------------------
if args.set_default:
    config["default_input"] = str(input_path)
    save_config(config)
    print(f"💾 Saved default input → {input_path}")

# ------------------------
# SHOW MODE
# ------------------------
if args.show:
    print(f"Input:  {input_path}")
    print(f"Output: {output_dir}")
    exit(0)

# ------------------------
# COLLECT PNGs
# ------------------------
def collect_pngs(path: Path):
    if path.is_file() and path.suffix.lower() == ".png":
        return [path]
    return sorted(path.rglob("*.png") if args.recursive else path.glob("*.png"))

png_files = collect_pngs(input_path)
print(f"Input: {input_path}")
print(f"Output: {output_dir}")
print(f"PNGs found: {len(png_files)}\n")

if not png_files:
    print("❌ No PNG files found")
    exit(1)

# ------------------------
# CONVERT FUNCTION
# ------------------------
def convert_png(file_path: Path):
    try:
        out_folder = output_dir if args.flat else (output_dir / file_path.stem)
        out_folder.mkdir(parents=True, exist_ok=True)

        output_file = out_folder / f"{file_path.stem}.jpg"
        with Image.open(file_path) as img:
            img.convert("RGB").save(output_file, "JPEG", quality=95)
            print(f"[WRITE] {output_file}")

        if args.delete:
            file_path.unlink()
            print(f"🗑 Deleted: {file_path}")

    except Exception as e:
        print(f"❌ Failed: {file_path}")
        print(f"   {e}")

# ------------------------
# RUN
# ------------------------
for png in png_files:
    convert_png(png)

print("\n✔ Done")
