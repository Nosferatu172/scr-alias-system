#!/usr/bin/env python3
# Script Name: netweb-1.5.py
# ID: SCR-ID-20260317130840-DQICDP417X
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: netweb-1.5
# netweb_massive_pdf.py
#
# Massive webpage -> multi-page PDF archiver (citation-ready)
# - Interactive prompts (URL + output dir)
# - Accepts Windows or WSL paths for output
# - Auto-scroll for lazy load / infinite-ish content
# - Optional resource blocking for speed
# - Forces pagination (fixes "everything became 1 page" issues)
# - Footer: URL + UTC timestamp + page/total pages
# - Batch mode with max workers (threads) for multiple URLs
#
# Requirements:
#   pip install playwright tqdm
#   playwright install chromium

import os
import re
import sys
import time
import shutil
import argparse
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from tqdm import tqdm
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeoutError


# -----------------------
# Ctrl+C clean exit
# -----------------------
def die_interrupt():
    print("\n⛔ Interrupted (Ctrl+C). Exiting cleanly.")
    raise KeyboardInterrupt


# -----------------------
# Clipboard
# -----------------------
def copy_to_clipboard(text: str) -> bool:
    try:
        # WSL -> Windows clipboard
        if os.path.isdir("/mnt/c"):
            clip = shutil.which("clip.exe") or "/mnt/c/Windows/System32/clip.exe"
            subprocess.run([clip], input=text.encode("utf-16le"), check=True)
            return True

        # Linux fallbacks
        if shutil.which("wl-copy"):
            subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True)
            return True
        if shutil.which("xclip"):
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode("utf-8"), check=True)
            return True
        if shutil.which("xsel"):
            subprocess.run(["xsel", "--clipboard", "--input"], input=text.encode("utf-8"), check=True)
            return True

        return False
    except Exception:
        return False


# -----------------------
# Path conversion (Windows <-> WSL)
# -----------------------
@dataclass
class ConvertedPath:
    windows: str
    wsl: str


def convert_paths(path: str) -> ConvertedPath | None:
    p = path.strip()

    # WSL -> Windows: /mnt/c/Users/... -> C:\Users\...
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)", p)
    if m:
        drive = m.group(1).upper()
        rest = m.group(2).replace("/", "\\")
        return ConvertedPath(windows=f"{drive}:\\{rest}", wsl=p)

    # Windows -> WSL: C:\Users\... OR C:/Users/... -> /mnt/c/Users/...
    m = re.match(r"^([a-zA-Z]):[\\/](.*)", p)
    if m:
        drive = m.group(1).lower()
        rest_win = m.group(2).replace("/", "\\")
        rest_wsl = m.group(2).replace("\\", "/")
        return ConvertedPath(windows=f"{m.group(1).upper()}:\\{rest_win}", wsl=f"/mnt/{drive}/{rest_wsl}")

    return None


def resolve_output_dir(raw: str) -> Path:
    raw = raw.strip()
    if raw == "" or raw == ".":
        return Path.cwd()

    conv = convert_paths(raw)
    if conv:
        return Path(conv.wsl)

    p = Path(raw)
    if not p.is_absolute():
        p = (Path.cwd() / p).resolve()
    return p


# -----------------------
# URL + filename helpers
# -----------------------
def safe_name_from_url(url: str) -> str:
    parsed = urlparse(url)
    host = (parsed.netloc or "site").replace("www.", "")
    host = re.sub(r"[^a-zA-Z0-9._-]+", "_", host).replace(".", "_")

    path = parsed.path.strip("/")
    path = re.sub(r"[^a-zA-Z0-9._-]+", "_", path.replace("/", "_"))

    base = host if not path else f"{host}_{path}"
    base = base.strip("_")[:120] or "page"
    return base


def prompt_url() -> str:
    print("\n🌐 Massive Webpage → PDF (multi-page, citation-ready)")
    print("Paste the URL below and press Enter.\n")
    while True:
        url = input("URL: ").strip()
        if url.startswith("http://") or url.startswith("https://"):
            return url
        print("❌ Invalid URL. Must start with http:// or https://")


def prompt_output_dir() -> Path:
    print("\n📁 Output folder")
    print("Enter a folder path (Windows or WSL).")
    print("Examples:")
    print(r"  Windows: C:\Users\tyler\Documents\refs")
    print("  WSL:     /mnt/c/Users/tyler/Documents/refs")
    print("  (Enter = current directory)\n")

    raw = input("Output dir: ").strip()
    out_dir = resolve_output_dir(raw)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Copy to clipboard (nice QoL)
    conv = convert_paths(str(out_dir))
    copied = False
    if conv:
        # If we are in WSL, copying the Windows path is often more useful
        copied = copy_to_clipboard(conv.windows if os.path.isdir("/mnt/c") else conv.wsl)
    else:
        copied = copy_to_clipboard(str(out_dir))

    if copied:
        print("📋 Output dir copied to clipboard!")
    return out_dir


# -----------------------
# Speed: optional request blocking
# -----------------------
def install_request_blocker(page, block_media: bool):
    """
    Speeds up load on huge pages by optionally blocking heavy resource types.
    For legal-text pages, blocking images/fonts/video often speeds up a lot.
    """
    if not block_media:
        return

    def route_handler(route, request):
        rtype = request.resource_type
        # Keep document/xhr/fetch/script/css; block images/media/fonts
        if rtype in ("image", "media", "font"):
            return route.abort()
        return route.continue_()

    page.route("**/*", route_handler)


# -----------------------
# Massive-page helpers: autoscroll to load lazy content
# -----------------------
def auto_scroll(page, max_seconds: int = 20, settle_ms: int = 750):
    """
    Scrolls down repeatedly to trigger lazy-loaded content.
    Stops when height stops increasing or time limit reached.
    """
    start = time.time()
    last_height = 0

    while True:
        if time.time() - start > max_seconds:
            break

        # Evaluate current doc height
        height = page.evaluate("() => document.documentElement.scrollHeight")
        if height == last_height:
            break
        last_height = height

        # Scroll to bottom
        page.evaluate("() => window.scrollTo(0, document.documentElement.scrollHeight)")
        page.wait_for_timeout(settle_ms)

    # Return to top (optional)
    page.evaluate("() => window.scrollTo(0, 0)")


# -----------------------
# Core: render one URL to PDF
# -----------------------
def render_url_to_pdf(url: str, out_dir: Path, *, paper: str, landscape: bool,
                      timeout_ms: int, wait_ms: int, scroll_seconds: int,
                      block_media: bool, scale: float) -> Path:
    ts = datetime.now(timezone.utc)
    timestamp = ts.strftime("%Y-%m-%d_%H-%M-%S_UTC")
    base = safe_name_from_url(url)
    pdf_path = out_dir / f"{timestamp}_{base}.pdf"

    with sync_playwright() as p:
        # A few chromium flags can help stability on big pages
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--disable-dev-shm-usage",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(
            viewport={"width": 1365, "height": 768},
            device_scale_factor=1,
        )
        page = context.new_page()

        install_request_blocker(page, block_media=block_media)

        # Prefer print rendering for better pagination
        page.emulate_media(media="print")

        # Load
        page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)

        # Let network settle a bit (some legal sites load after DOM ready)
        try:
            page.wait_for_load_state("networkidle", timeout=timeout_ms)
        except PWTimeoutError:
            # Some sites never go fully idle; we proceed anyway.
            pass

        # Trigger lazy content
        if scroll_seconds > 0:
            auto_scroll(page, max_seconds=scroll_seconds, settle_ms=750)

        # Extra wait (animations / late content)
        if wait_ms > 0:
            page.wait_for_timeout(wait_ms)

        # Force multi-page pagination + footer templates (better than DOM footer)
        footer = f"""
        <div style="width:100%; font-size:8px; color:#666; padding:0 8px;">
          <span>Captured from: {url}</span>
          <span style="float:right;">
            UTC: {timestamp} | Page <span class="pageNumber"></span>/<span class="totalPages"></span>
          </span>
        </div>
        """

        page.pdf(
            path=str(pdf_path),
            format=paper,                     # Letter / A4 / etc.
            landscape=landscape,
            print_background=True,
            scale=scale,
            display_header_footer=True,
            header_template="<div></div>",
            footer_template=footer,
            margin={"top": "0.6in", "right": "0.6in", "bottom": "0.85in", "left": "0.6in"},
            prefer_css_page_size=False,        # IMPORTANT: forces pagination vs weird site print CSS
        )

        context.close()
        browser.close()

    return pdf_path


# -----------------------
# Main
# -----------------------
def main():
    ap = argparse.ArgumentParser(description="Massive webpage -> multi-page PDF archiver")
    ap.add_argument("--paper", default="Letter", help='Paper size: "Letter" or "A4" etc (default: Letter)')
    ap.add_argument("--landscape", action="store_true", help="Landscape orientation")
    ap.add_argument("--timeout-ms", type=int, default=120000, help="Navigation timeout (default: 120000)")
    ap.add_argument("--wait-ms", type=int, default=1500, help="Extra wait after load (default: 1500)")
    ap.add_argument("--scroll-seconds", type=int, default=20, help="Auto-scroll seconds to trigger lazy load (default: 20)")
    ap.add_argument("--block-media", action="store_true", help="Block images/fonts/media to speed up (good for text pages)")
    ap.add_argument("--scale", type=float, default=1.0, help="PDF scale (default: 1.0)")

    # Batch mode (threads) — actually useful for multiple URLs
    ap.add_argument("--batch", action="store_true", help="Batch mode: paste multiple URLs (blank line to start)")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 8, help="Batch workers (default: CPU count)")

    args = ap.parse_args()

    out_dir = prompt_output_dir()

    if not args.batch:
        url = prompt_url()

        steps = [
            "Rendering (browser load)",
            "Scrolling / settling",
            "Printing to multi-page PDF",
            "Finalizing",
        ]

        try:
            with tqdm(total=len(steps), bar_format="{l_bar}{bar} {n_fmt}/{total_fmt}") as bar:
                bar.set_description(steps[0])
                # render_url_to_pdf does all steps; progress bar is "phase based"
                pdf_path = render_url_to_pdf(
                    url, out_dir,
                    paper=args.paper,
                    landscape=args.landscape,
                    timeout_ms=args.timeout_ms,
                    wait_ms=args.wait_ms,
                    scroll_seconds=args.scroll_seconds,
                    block_media=args.block_media,
                    scale=args.scale,
                )
                bar.update(3)
                bar.set_description(steps[3])
                bar.update(1)

            print("\n✅ PDF saved:")
            print(f"   {pdf_path}")

            conv = convert_paths(str(pdf_path))
            if conv:
                print("\n🔁 Paths:")
                print(f"   Windows: {conv.windows}")
                print(f"   WSL:     {conv.wsl}")

        except KeyboardInterrupt:
            die_interrupt()

    else:
        # Batch mode: paste multiple URLs, then process in parallel
        print("\n📦 Batch mode: paste URLs (one per line).")
        print("When done, press Enter on a blank line.\n")

        urls: list[str] = []
        while True:
            try:
                line = input().strip()
            except KeyboardInterrupt:
                die_interrupt()
            if not line:
                break
            if line.startswith("http://") or line.startswith("https://"):
                urls.append(line)
            else:
                print(f"⚠️ Skipping invalid URL: {line}")

        if not urls:
            print("ℹ️ No URLs provided. Exiting.")
            return

        # Threading helps here because each URL is its own browser job
        from concurrent.futures import ThreadPoolExecutor, as_completed

        workers = max(1, int(args.workers))
        print(f"\n🚀 Processing {len(urls)} URLs with {workers} workers...\n")

        results: list[Path] = []
        failures: list[tuple[str, str]] = []

        try:
            with tqdm(total=len(urls), bar_format="{l_bar}{bar} {n_fmt}/{total_fmt}") as bar:
                with ThreadPoolExecutor(max_workers=workers) as ex:
                    futs = {
                        ex.submit(
                            render_url_to_pdf,
                            url, out_dir,
                            paper=args.paper,
                            landscape=args.landscape,
                            timeout_ms=args.timeout_ms,
                            wait_ms=args.wait_ms,
                            scroll_seconds=args.scroll_seconds,
                            block_media=args.block_media,
                            scale=args.scale,
                        ): url
                        for url in urls
                    }

                    for fut in as_completed(futs):
                        url = futs[fut]
                        try:
                            pdfp = fut.result()
                            results.append(pdfp)
                        except Exception as e:
                            failures.append((url, str(e)))
                        bar.update(1)

            print("\n✅ Batch complete.")
            print(f"   Success: {len(results)}")
            print(f"   Failed:  {len(failures)}")

            if failures:
                print("\nFailures:")
                for u, err in failures[:10]:
                    print(f" - {u}\n   {err}")

        except KeyboardInterrupt:
            die_interrupt()


if __name__ == "__main__":
    main()
