#!/usr/bin/env python3
# Script Name: jpg2pdf.py
# ID: SCR-ID-20260330000200-JPGPDFX01
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scr jpg2pdf

import os
import csv
import argparse
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from PIL import Image

# =========================================================
# SCRIPT-LOCAL CONFIG (portable)
# =========================================================

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = SCRIPT_DIR / "jpg2pdf_config.csv"

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

# =========================================================
# WINPROFILE fallback (WSL)
# =========================================================

def scan_winprofile():
    root = Path("/mnt/c/Users")
    if not root.exists():
        return None

    candidates = [
        u for u in root.iterdir()
        if u.is_dir() and u.name.lower() not in [
            "public", "default", "all users", "default user"
        ]
    ]

    for u in candidates:
        if (u / "Documents").exists():
            return str(u)

    return str(candidates[0]) if candidates else None

WINPROFILE = os.environ.get("WINPROFILE") or scan_winprofile()

# =========================================================
# DEFAULTS
# =========================================================

DEFAULT_INPUT = (
    config.get("default_input")
    or (f"{WINPROFILE}/Documents/czur/scans" if WINPROFILE else str(Path.cwd()))
)

DEFAULT_OUTPUT = (
    config.get("default_output")
    or (f"{WINPROFILE}/Documents/czur/output.pdf" if WINPROFILE else str(Path.cwd() / "output.pdf"))
)

# =========================================================
# CLI
# =========================================================

parser = argparse.ArgumentParser(description="JPG → PDF converter")

parser.add_argument("-e", "--set-default", help="Set input directory as default")
parser.add_argument("-o", "--output", help="Output PDF file", default=DEFAULT_OUTPUT)
parser.add_argument("-a", "--active", action="store_true", help="Use current directory")
parser.add_argument("-l", "--show", action="store_true", help="Show resolved paths")

args = parser.parse_args()

# =========================================================
# INPUT RESOLUTION
# =========================================================

input_dir = Path(args.set_default or DEFAULT_INPUT).expanduser()

if args.set_default:
    config["default_input"] = str(input_dir)
    save_config(config)
    print(f"💾 Saved default input directory → {input_dir}")
    exit(0)

if args.active:
    input_dir = Path.cwd()

output_pdf = Path(args.output).expanduser()

# =========================================================
# DEBUG
# =========================================================

if args.show:
    print(f"Input:   {input_dir}")
    print(f"Output:  {output_pdf}")
    print(f"WINPROFILE: {WINPROFILE}")
    print(f"Config:  {CONFIG_FILE}")
    exit(0)

# =========================================================
# IMAGE COLLECTION
# =========================================================

def collect_images(folder: Path):
    exts = ("*.jpg", "*.jpeg", "*.JPG", "*.JPEG")
    images = []
    for ext in exts:
        images.extend(folder.glob(ext))
    return sorted(images)

images = collect_images(input_dir)

print(f"Input:  {input_dir}")
print(f"Output: {output_pdf}")
print(f"Images: {len(images)}\n")

# =========================================================
# PDF BUILD
# =========================================================

def build_pdf(images, output_file):
    if not images:
        print("❌ No images found")
        exit(1)

    output_file.parent.mkdir(parents=True, exist_ok=True)

    c = canvas.Canvas(str(output_file), pagesize=letter)
    page_w, page_h = letter

    for img_path in images:
        try:
            # Header text (like your Ruby script)
            c.setFont("Helvetica-Bold", 10)
            c.drawString(18, page_h - 18, img_path.name)

            # Load image
            img = Image.open(img_path)
            img_w, img_h = img.size

            # Fit image into page
            max_w = page_w - 36
            max_h = page_h - 50

            scale = min(max_w / img_w, max_h / img_h)
            draw_w = img_w * scale
            draw_h = img_h * scale

            x = (page_w - draw_w) / 2
            y = (page_h - draw_h) / 2 - 10

            c.drawImage(str(img_path), x, y, width=draw_w, height=draw_h)

        except Exception as e:
            c.setFont("Helvetica", 9)
            c.setFillColorRGB(1, 0, 0)
            c.drawString(18, page_h - 40, f"Failed: {img_path.name}")
            c.drawString(18, page_h - 55, str(e))

        c.showPage()

    c.save()
    print(f"✔ PDF saved: {output_file}")

# =========================================================
# RUN
# =========================================================

build_pdf(images, output_pdf)
