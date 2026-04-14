#!/usr/bin/env python3
# Script Name: bookmaker-1.9.py
# ID: SCR-ID-20260329040925-BMLMK5SIAL
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: bookmaker-1.9

"""
Bookmaker 1.9+ — Automated PDF book builder
- Drop your PDFs in a folder (optionally with subfolders)
- Script will auto-detect, order, insert illustrations, and merge
- Output: single PDF, manifest.txt, and clipboard copy of result path

Enhancements:
- Dependency check for pypdf
- Clearer prompts and error messages
- Option to open output folder after build (Windows/WSL/Linux/Mac)
- Usage: Run and follow prompts
"""

import os, re, sys, shutil, subprocess
from pathlib import Path
from string import ascii_uppercase

def copy_to_clipboard(text: str):
    try:
        if os.path.isdir("/mnt/c"):
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
        else:
            clip = shutil.which("clip") or "clip"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
        print("📋 Copied to clipboard!")
    except Exception as e:
        print(f"⚠️ Clipboard failed: {e}")

def gather_pdfs(root: Path, recurse: bool):
    return sorted(root.rglob("*.pdf") if recurse else root.glob("*.pdf"))

# ---------- Categorization rules ----------
TOC_RE = re.compile(r"(table\s*of\s*contents|^toc\b)", re.I)
FRONT_RE = re.compile(r"(preface|foreword|introduction|title\s*page|purpose|how\s*to\s*read|prologue)", re.I)
MID_RE = re.compile(r"(formal\s*conclusion|author.?s\s*reflection|scope\s*and\s*limitation|scope\s*&\s*limitations?)", re.I)
CLOSING_RE = re.compile(r"(version\s*history|dedication|acknowledg)", re.I)

CHAPTER_RE = re.compile(r"^chapter\s*(\d+)\.pdf$", re.I)
APP_RE = re.compile(r"^appendix\s*([A-Z])\.pdf$", re.I)

# Auto illustration inserts:
ILL_CH_RE = re.compile(r"(illustrations?|figures?)\s*[-_ ]*\s*(?:ch|chapter)\s*0*(\d+)\.pdf$", re.I)
ILL_APP_RE = re.compile(r"(illustrations?|figures?)\s*[-_ ]*\s*(?:app|appendix)\s*([A-Z])\.pdf$", re.I)

def sort_key(name: str):
    base = name
    # 1) TOC
    if TOC_RE.search(base):
        return (0, 0, base.casefold())
    # 2) Front matter
    if FRONT_RE.search(base):
        return (1, 0, base.casefold())
    # 3) Chapters
    m = CHAPTER_RE.match(base)
    if m:
        return (2, int(m.group(1)), base.casefold())
    # 4) Mid / analysis
    if MID_RE.search(base):
        return (3, 0, base.casefold())
    # 5) Appendices
    m = APP_RE.match(base)
    if m:
        return (4, ascii_uppercase.index(m.group(1).upper()), base.casefold())
    # 6) Closing
    if CLOSING_RE.search(base):
        return (5, 0, base.casefold())
    # 7) Other (go last)
    return (9, 0, base.casefold())

def merge_pdfs(paths: list[Path], output: Path):
    try:
        from pypdf import PdfReader, PdfWriter
    except Exception as e:
        print("❌ Install dependency: pip install -U pypdf")
        print("Error:", e)
        sys.exit(1)

    writer = PdfWriter()
    for p in paths:
        reader = PdfReader(str(p))
        for page in reader.pages:
            writer.add_page(page)
    with open(output, "wb") as f:
        writer.write(f)

def check_dependency():
    try:
        import pypdf
    except ImportError:
        print("\n[ERROR] Missing dependency: pypdf\nInstall with: pip install -U pypdf\n")
        sys.exit(1)

def main():
    check_dependency()
    print("=== BOOKMAKER AUTO — Detect + Order + Auto-Insert Illustrations + Merge ===")
    print("Drop your PDFs in a folder, then enter the path below.")
    raw_dir = input("Directory containing PDFs: ").strip().strip('"').strip("'")
    if not raw_dir:
        sys.exit("❌ No directory provided.")

    root = Path(raw_dir)
    if not root.exists() or not root.is_dir():
        sys.exit(f"❌ Not a valid directory: {root}")

    recurse = input("Include subdirectories? [Y/n]: ").strip().lower()
    recurse = False if recurse in ("n", "no") else True

    files = gather_pdfs(root, recurse)
    if not files:
        sys.exit("❌ No PDFs found.")

    # Build illustration maps
    ill_after_ch = {}  # chapter_num -> [Path...]
    ill_after_app = {} # letter -> [Path...]

    for p in files:
        nm = p.name
        mch = ILL_CH_RE.match(nm)
        if mch:
            n = int(mch.group(2))
            ill_after_ch.setdefault(n, []).append(p)
            continue
        mapx = ILL_APP_RE.match(nm)
        if mapx:
            L = mapx.group(2).upper()
            ill_after_app.setdefault(L, []).append(p)
            continue

    # Base ordered list
    base = sorted(files, key=lambda p: sort_key(p.name))

    # Apply inserts (after matching chapter/appendix)
    final = []
    for p in base:
        final.append(p)

        mch = CHAPTER_RE.match(p.name)
        if mch:
            n = int(mch.group(1))
            for ins in sorted(ill_after_ch.get(n, []), key=lambda x: x.name.casefold()):
                final.append(ins)

        mapx = APP_RE.match(p.name)
        if mapx:
            L = mapx.group(1).upper()
            for ins in sorted(ill_after_app.get(L, []), key=lambda x: x.name.casefold()):
                final.append(ins)

    # Remove duplicates if an illustration PDF also got included in base
    seen = set()
    deduped = []
    for p in final:
        if p.resolve() in seen:
            continue
        seen.add(p.resolve())
        deduped.append(p)

    # Write manifest
    manifest = root / "manifest.txt"
    with open(manifest, "w", encoding="utf-8") as f:
        for p in deduped:
            f.write(str(p) + "\n")
    print(f"🧾 Manifest written: {manifest}")

    # Merge
    out_name = input("Output filename [FINAL_BOOK.pdf]: ").strip()
    out_name = out_name or "FINAL_BOOK.pdf"
    if not out_name.lower().endswith(".pdf"):
        out_name += ".pdf"
    out_path = root / out_name

    print("\n=== Merging order ===")
    for p in deduped:
        print(" +", p.name)

    merge_pdfs(deduped, out_path)
    print("\n✅ BUILD COMPLETE:", out_path)
    copy_to_clipboard(str(out_path))

    # Optionally open output folder
    open_choice = input("Open output folder? [Y/n]: ").strip().lower()
    if open_choice not in ("n", "no"):
        folder = str(out_path.parent)
        if sys.platform.startswith("win") or os.path.isdir("/mnt/c"):
            os.startfile(folder)
        elif sys.platform == "darwin":
            subprocess.run(["open", folder])
        else:
            subprocess.run(["xdg-open", folder])

if __name__ == "__main__":
    main()
