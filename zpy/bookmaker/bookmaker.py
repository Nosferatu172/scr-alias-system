#!/usr/bin/env python3
# Script Name: bookmaker.py
# ID: SCR-ID-20260329040931-LWT4CXBSJQ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: bookmaker

"""
Bookmaker 2.0 — Automated PDF book builder

Features:
- Scan a folder for PDFs
- Optional recursion into subfolders
- Auto-sort by:
    TOC -> Front Matter -> Chapters -> Mid Matter -> Appendices -> Closing -> Other
- Auto-insert illustration/figure PDFs after matching chapters/appendices
- Ask where to save:
    - manifest.txt
    - output merged PDF
- Copy output path to clipboard when possible
- Optionally open the output folder after build

Supported illustration filename examples:
- Illustrations Chapter 1.pdf
- Figures - Ch 02.pdf
- Illustrations Appendix A.pdf
- Figures App B.pdf

Supported chapter filename examples:
- Chapter 1.pdf
- Chapter 01 - Intro.pdf
- chapter 2 revised.pdf

Supported appendix filename examples:
- Appendix A.pdf
- Appendix B Notes.pdf
"""

from __future__ import annotations

import os
import re
import sys
import shutil
import subprocess
from pathlib import Path
from string import ascii_uppercase


# =========================================================
# Clipboard
# =========================================================
def copy_to_clipboard(text: str) -> None:
    try:
        if sys.platform.startswith("win"):
            clip = shutil.which("clip") or shutil.which("clip.exe")
            if not clip:
                raise RuntimeError("clip.exe not found")
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)

        elif "microsoft" in os.uname().release.lower() if hasattr(os, "uname") else False:
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            if not Path(clip).exists() and not shutil.which("clip.exe"):
                raise RuntimeError("clip.exe not available from WSL")
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)

        elif sys.platform == "darwin":
            if not shutil.which("pbcopy"):
                raise RuntimeError("pbcopy not found")
            subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)

        else:
            if shutil.which("wl-copy"):
                subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True)
            elif shutil.which("xclip"):
                subprocess.run(
                    ["xclip", "-selection", "clipboard"],
                    input=text.encode("utf-8"),
                    check=True,
                )
            elif shutil.which("xsel"):
                subprocess.run(
                    ["xsel", "--clipboard", "--input"],
                    input=text.encode("utf-8"),
                    check=True,
                )
            else:
                raise RuntimeError("no clipboard utility found")

        print("📋 Copied output path to clipboard.")

    except Exception as e:
        print(f"⚠️ Clipboard copy skipped: {e}")


# =========================================================
# PDF gathering
# =========================================================
def gather_pdfs(root: Path, recurse: bool) -> list[Path]:
    pdfs = root.rglob("*.pdf") if recurse else root.glob("*.pdf")
    return sorted(p.resolve() for p in pdfs if p.is_file())


# =========================================================
# Regex rules
# =========================================================
TOC_RE = re.compile(r"(table\s*of\s*contents|^toc\b)", re.I)
FRONT_RE = re.compile(
    r"(preface|foreword|introduction|title\s*page|purpose|how\s*to\s*read|prologue)",
    re.I,
)
MID_RE = re.compile(
    r"(formal\s*conclusion|author.?s\s*reflection|scope\s*and\s*limitation|scope\s*&\s*limitations?)",
    re.I,
)
CLOSING_RE = re.compile(r"(version\s*history|dedication|acknowledg)", re.I)

CHAPTER_RE = re.compile(r"^chapter\s*0*(\d+)\b.*\.pdf$", re.I)
APP_RE = re.compile(r"^appendix\s*([A-Z])\b.*\.pdf$", re.I)

ILL_CH_RE = re.compile(
    r"(illustrations?|figures?)\s*[-_ ]*\s*(?:ch|chapter)\s*0*(\d+)\b.*\.pdf$",
    re.I,
)
ILL_APP_RE = re.compile(
    r"(illustrations?|figures?)\s*[-_ ]*\s*(?:app|appendix)\s*([A-Z])\b.*\.pdf$",
    re.I,
)


# =========================================================
# Sort helpers
# =========================================================
def natural_key(text: str):
    return [
        int(part) if part.isdigit() else part.casefold()
        for part in re.split(r"(\d+)", text)
    ]


def sort_key(name: str):
    base = name

    if TOC_RE.search(base):
        return (0, 0, natural_key(base))

    if FRONT_RE.search(base):
        return (1, 0, natural_key(base))

    m = CHAPTER_RE.match(base)
    if m:
        return (2, int(m.group(1)), natural_key(base))

    if MID_RE.search(base):
        return (3, 0, natural_key(base))

    m = APP_RE.match(base)
    if m:
        return (4, ascii_uppercase.index(m.group(1).upper()), natural_key(base))

    if CLOSING_RE.search(base):
        return (5, 0, natural_key(base))

    return (9, 0, natural_key(base))


# =========================================================
# Prompts
# =========================================================
def prompt_path(prompt_text: str, default: Path | None = None) -> Path:
    if default:
        raw = input(f"{prompt_text} [{default}]: ").strip().strip('"').strip("'")
        return Path(raw).expanduser().resolve() if raw else default.resolve()
    raw = input(f"{prompt_text}: ").strip().strip('"').strip("'")
    if not raw:
        raise ValueError("No path provided")
    return Path(raw).expanduser().resolve()


def prompt_yes_no(prompt_text: str, default_yes: bool = True) -> bool:
    suffix = "[Y/n]" if default_yes else "[y/N]"
    raw = input(f"{prompt_text} {suffix}: ").strip().lower()
    if not raw:
        return default_yes
    return raw in ("y", "yes")


# =========================================================
# Dependency
# =========================================================
def require_pypdf():
    try:
        from pypdf import PdfReader, PdfWriter
        return PdfReader, PdfWriter
    except Exception as e:
        print("\n❌ Missing dependency: pypdf")
        print("Install with:")
        print("   pip install -U pypdf\n")
        print(f"Reason: {e}")
        sys.exit(1)


# =========================================================
# Merge
# =========================================================
def merge_pdfs(paths: list[Path], output: Path) -> None:
    PdfReader, PdfWriter = require_pypdf()
    writer = PdfWriter()

    for p in paths:
        try:
            reader = PdfReader(str(p))
            if reader.is_encrypted:
                try:
                    reader.decrypt("")
                except Exception:
                    raise RuntimeError("PDF is encrypted and could not be opened")

            for page in reader.pages:
                writer.add_page(page)

        except Exception as e:
            print(f"❌ Failed while reading: {p}")
            print(f"   Reason: {e}")
            sys.exit(1)

    try:
        output.parent.mkdir(parents=True, exist_ok=True)
        with open(output, "wb") as f:
            writer.write(f)
    except Exception as e:
        print(f"❌ Failed while writing output PDF: {output}")
        print(f"   Reason: {e}")
        sys.exit(1)


# =========================================================
# Folder opener
# =========================================================
def open_folder(folder: Path) -> None:
    try:
        if sys.platform.startswith("win"):
            os.startfile(str(folder))

        elif "microsoft" in os.uname().release.lower() if hasattr(os, "uname") else False:
            subprocess.run(["explorer.exe", str(folder)], check=False)

        elif sys.platform == "darwin":
            subprocess.run(["open", str(folder)], check=False)

        else:
            subprocess.run(["xdg-open", str(folder)], check=False)

    except Exception as e:
        print(f"⚠️ Could not open folder: {e}")


# =========================================================
# Main
# =========================================================
def main():
    print("=== BOOKMAKER 2.0 ===")
    print("Auto-detect + order + illustration insert + merge PDFs")
    print()

    try:
        source_dir = prompt_path("Directory containing source PDFs")
    except ValueError:
        sys.exit("❌ No source directory provided.")

    if not source_dir.exists() or not source_dir.is_dir():
        sys.exit(f"❌ Not a valid directory: {source_dir}")

    recurse = prompt_yes_no("Include subdirectories?", default_yes=True)

    default_manifest = source_dir / "manifest.txt"
    default_output = source_dir / "FINAL_BOOK.pdf"

    try:
        manifest_path = prompt_path("Where should manifest.txt be saved", default_manifest)
        output_path = prompt_path("Where should merged PDF be saved", default_output)
    except ValueError:
        sys.exit("❌ Missing save path.")

    if output_path.suffix.lower() != ".pdf":
        output_path = output_path.with_suffix(".pdf")

    if manifest_path.suffix.lower() != ".txt":
        manifest_path = manifest_path.with_suffix(".txt")

    files = gather_pdfs(source_dir, recurse)
    if not files:
        sys.exit("❌ No PDFs found.")

    output_resolved = output_path.resolve()

    # Exclude output file itself if it exists in the source tree
    files = [p for p in files if p.resolve() != output_resolved]

    if not files:
        sys.exit("❌ No usable PDFs found after excluding the output file.")

    # Build illustration maps and base list
    ill_after_ch: dict[int, list[Path]] = {}
    ill_after_app: dict[str, list[Path]] = {}
    base: list[Path] = []

    for p in files:
        nm = p.name

        mch = ILL_CH_RE.match(nm)
        if mch:
            n = int(mch.group(2))
            ill_after_ch.setdefault(n, []).append(p)
            continue

        mapx = ILL_APP_RE.match(nm)
        if mapx:
            letter = mapx.group(2).upper()
            ill_after_app.setdefault(letter, []).append(p)
            continue

        base.append(p)

    base.sort(key=lambda p: sort_key(p.name))

    # Insert illustration files after matching chapter/appendix
    final: list[Path] = []

    for p in base:
        final.append(p)

        mch = CHAPTER_RE.match(p.name)
        if mch:
            n = int(mch.group(1))
            inserts = sorted(ill_after_ch.get(n, []), key=lambda x: natural_key(x.name))
            final.extend(inserts)

        mapx = APP_RE.match(p.name)
        if mapx:
            letter = mapx.group(1).upper()
            inserts = sorted(ill_after_app.get(letter, []), key=lambda x: natural_key(x.name))
            final.extend(inserts)

    # Add unmatched illustration files at the end so they are not silently lost
    matched_insert_set = {p.resolve() for p in final}
    unmatched_illustrations = [
        p for p in files
        if (ILL_CH_RE.match(p.name) or ILL_APP_RE.match(p.name))
        and p.resolve() not in matched_insert_set
    ]
    unmatched_illustrations.sort(key=lambda p: natural_key(p.name))
    final.extend(unmatched_illustrations)

    # Deduplicate by resolved path, preserve order
    seen: set[Path] = set()
    deduped: list[Path] = []

    for p in final:
        rp = p.resolve()
        if rp in seen:
            continue
        seen.add(rp)
        deduped.append(p)

    if not deduped:
        sys.exit("❌ Nothing to merge after ordering.")

    # Preview
    print("\n=== FINAL MERGE ORDER ===")
    for i, p in enumerate(deduped, start=1):
        print(f"{i:03d}. {p}")

    if not prompt_yes_no("Proceed with merge?", default_yes=True):
        print("⛔ Merge cancelled.")
        sys.exit(0)

    # Write manifest
    try:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        with open(manifest_path, "w", encoding="utf-8") as f:
            for p in deduped:
                f.write(str(p) + "\n")
        print(f"\n🧾 Manifest written: {manifest_path}")
    except Exception as e:
        print(f"❌ Failed writing manifest: {manifest_path}")
        print(f"   Reason: {e}")
        sys.exit(1)

    # Merge
    print(f"\n📚 Building merged PDF -> {output_path}")
    merge_pdfs(deduped, output_path)

    print(f"\n✅ BUILD COMPLETE: {output_path}")
    copy_to_clipboard(str(output_path))

    if prompt_yes_no("Open output folder?", default_yes=True):
        open_folder(output_path.parent)


if __name__ == "__main__":
    main()
