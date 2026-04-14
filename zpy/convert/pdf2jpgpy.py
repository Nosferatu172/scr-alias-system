#!/usr/bin/env python3
# Script Name: pdf2jpg.py
# ID: SCR-ID-20260330000100-PDFJPGX03
# Created by: Tyler Jensen

import os
import csv
import argparse
from pathlib import Path
from pdf2image import convert_from_path

# ------------------------
# CONFIG
# ------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = SCRIPT_DIR / "pdf2jpg_config.csv"

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
PDF → JPG Converter

Example Usage:
  Convert PDFs in current folder:
      python3 pdf2jpg.py -a

  Convert PDFs recursively and delete originals:
      python3 pdf2jpg.py -a -r --delete

  Convert PDFs in custom folder:
      python3 pdf2jpg.py -i /path/to/pdfs -o /path/to/output
"""

parser = argparse.ArgumentParser(
    description=help_text,
    formatter_class=argparse.RawTextHelpFormatter
)

parser.add_argument("-i", "--input", help="PDF file or directory", default=config.get("default_input"))
parser.add_argument("-o", "--output", help="Output folder", default=None)
parser.add_argument("-d", "--dpi", type=int, default=300, help="Render DPI (default: 300)")
parser.add_argument("-a", "--active", action="store_true", help="Use current directory for input AND output")
parser.add_argument("-r", "--recursive", action="store_true", help="Search PDFs recursively")
parser.add_argument("--delete", action="store_true", help="Delete source PDFs after successful conversion")
parser.add_argument("--flat", action="store_true", help="Do not create subfolder per PDF")
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
output_dir = Path(args.output).expanduser().resolve() if args.output else (input_path / "pdf_images")

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
    print(f"DPI:    {args.dpi}")
    exit(0)

# ------------------------
# COLLECT PDFs
# ------------------------
def collect_pdfs(path: Path):
    if path.is_file() and path.suffix.lower() == ".pdf":
        return [path]
    return sorted(path.rglob("*.pdf") if args.recursive else path.glob("*.pdf"))

pdfs = collect_pdfs(input_path)
print(f"Input:  {input_path}")
print(f"Output: {output_dir}")
print(f"PDFs:   {len(pdfs)}\n")

if not pdfs:
    print("❌ No PDFs found")
    exit(1)

# ------------------------
# CONVERT FUNCTION
# ------------------------
def convert_pdf(pdf_file: Path):
    try:
        pages = convert_from_path(str(pdf_file), dpi=args.dpi, poppler_path="/usr/bin")
        out_folder = output_dir if args.flat else (output_dir / pdf_file.stem)
        out_folder.mkdir(parents=True, exist_ok=True)

        for i, page in enumerate(pages, start=1):
            out_file = out_folder / f"{pdf_file.stem}_page_{i}.jpg"
            page.save(out_file, "JPEG", quality=95)
            print(f"[WRITE] {out_file}")

        print(f"✔ Converted: {pdf_file.name} ({len(pages)} pages)")

        if args.delete:
            pdf_file.unlink()
            print(f"🗑 Deleted: {pdf_file}")

    except Exception as e:
        print(f"❌ Failed: {pdf_file}")
        print(f"   {e}")

# ------------------------
# RUN
# ------------------------
for pdf in pdfs:
    convert_pdf(pdf)

print("\n✔ Done")
