#!/usr/bin/env python3
# Script Name: password-generator-2.2.py
# ID: SCR-ID-20260317130851-WAGE6PX98G
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: password-generator-2.2

import os
import csv
import json
import random
import argparse
from pathlib import Path
from datetime import datetime

# -------------------------
# Defaults
# -------------------------
DEFAULT_SEPARATORS = ["!!", "@@", "##", "%%", "::", "--", "__", "==", "++", "**"]
DEFAULT_UNICODE = ["★", "☆", "☠", "☯", "☢", "⚡", "✪", "✧", "☾", "♠", "♣", "♦", "♥"]

DEFAULT_POOL_DATA = {
    "demons": [
        "Beelzebul","Lucifer","Asmodeus","Belial","Leviathan","Azazel","Samael","Shax",
        "Baalzebub","Iblis","Marid","Ifrit","Qareeb","Andhaka","Typhon","Geryon",
        "Cerberus","Oni","Tengu","Fenrir","Loki","Hel","Nidhoggr","Wyvern","Harbinger"
    ],
    "military": [
        "Alpha","Bravo","Charlie","Delta","Echo","Fox","Golf","Hex","Kilo","Lima",
        "Max","Nixon","Oscar","Papa","Quebec","Romeo","Sierra","Talon",
        "Whiskey","Xray","Yahtzee","Zulu"
    ],
    "dragons": [
        "Fafnir","Smaug","Tiamat","Jormungandr","Ryujin","Quetzalcoatl","Apep",
        "Hydra","Drakon","Wyrm","Drake","Bahamut","Vritra","Ladon","Tarasque",
        "Shenlong","Yinglong"
    ],
    "viking": [
        "Odin","Thor","Tyr","Freya","Frigg","Heimdall","Baldr","Vidar","Skadi",
        "Njord","Aegir","Sif","Yggdrasil","Valhalla","Bifrost","Ragnarok","Berserker"
    ],
    "chinese": [
        "Huangdi","XiWangmu","Nezha","Nuwa","Fuxi","Pangu","SunWukong","ErlangShen",
        "Guanyin","JadeEmperor","YanWang","AoGuang","LongWang","Qilin","Pixiu","Taotie"
    ]
}

# -------------------------
# Portable paths (relative to script)
# -------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
POOLDIR_DEFAULT = SCRIPT_DIR / "pools"
LOGDIR = SCRIPT_DIR / "logs"
OUTDIR_DEFAULT = SCRIPT_DIR / "output"
CONFIG_FILE = LOGDIR / "config.json"

# -------------------------
# Config handling
# -------------------------
def load_config():
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def save_config(cfg: dict):
    LOGDIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(cfg, indent=2), encoding="utf-8")

def interactive_first_run_setup():
    cfg = load_config()
    if cfg.get("outdir"):
        return cfg

    print("========================================")
    print("🛠️  First run setup")
    print("Where should generated password lists be saved?")
    print(f"Press Enter for default: {OUTDIR_DEFAULT}")
    print("Or type a full path (ex: /mnt/f/mnt/c/scr/key/passwords)")
    print("========================================")
    choice = input("> ").strip()

    outdir = Path(choice).expanduser() if choice else OUTDIR_DEFAULT
    outdir = outdir.resolve() if outdir.is_absolute() else (SCRIPT_DIR / outdir).resolve()

    cfg["outdir"] = str(outdir)
    save_config(cfg)

    print(f"\n✅ Saved default output directory: {outdir}")
    return cfg

# -------------------------
# Logging
# -------------------------
def log_run(text: str):
    LOGDIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    logfile = LOGDIR / f"run_{ts}.log"
    logfile.write_text(text, encoding="utf-8")
    return logfile

# -------------------------
# CSV helpers
# -------------------------
def read_csv_words(path: Path):
    words = []
    if not path.exists():
        return words
    with path.open("r", newline="", encoding="utf-8", errors="ignore") as f:
        reader = csv.reader(f)
        for row in reader:
            if row and row[0].strip():
                words.append(row[0].strip())
    return words

def write_csv_words(path: Path, words):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for w in words:
            writer.writerow([w])

def ensure_pool_files(pooldir: Path):
    pooldir.mkdir(parents=True, exist_ok=True)
    created = []
    for poolname, default_words in DEFAULT_POOL_DATA.items():
        csv_path = pooldir / f"{poolname}.csv"
        if not csv_path.exists():
            write_csv_words(csv_path, default_words)
            created.append(csv_path)
    return created

def load_pools(pooldir: Path, only=None):
    pools = {}
    targets = only if only else list(DEFAULT_POOL_DATA.keys())

    for name in targets:
        csv_path = pooldir / f"{name}.csv"
        words = read_csv_words(csv_path)
        if not words:
            raise SystemExit(f"❌ Pool '{name}' is empty or missing: {csv_path}")
        pools[name] = words

    return pools

# -------------------------
# Output file helpers
# -------------------------
def read_lines_any(path: Path):
    if not path.exists():
        return set()

    if path.suffix.lower() == ".csv":
        out = set()
        with path.open("r", newline="", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            for row in reader:
                if row and row[0].strip():
                    out.add(row[0].strip())
        return out

    out = set()
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            s = line.strip()
            if s:
                out.add(s)
    return out

def write_lines_any(path: Path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix.lower() == ".csv":
        with path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for line in sorted(lines):
                writer.writerow([line])
    else:
        with path.open("w", encoding="utf-8") as f:
            f.write("\n".join(sorted(lines)) + "\n")

def append_unique(path: Path, new_lines):
    existing = read_lines_any(path)
    merged = existing | set(new_lines)
    write_lines_any(path, merged)

def merge_files(files):
    combined = set()
    for f in files:
        combined |= read_lines_any(f)
    for f in files:
        write_lines_any(f, combined)

# -------------------------
# Generator
# -------------------------
class PasswordGenerator:
    def __init__(self, pools_dict, tier="2", allow_unicode=False, case_mode="normal", separators=None):
        self.pools = list(pools_dict.values())
        self.tier = str(tier)
        self.allow_unicode = allow_unicode
        self.case_mode = case_mode
        self.separators = separators or DEFAULT_SEPARATORS

    def _sep(self):
        return random.choice(self.separators)

    def _maybe_unicode(self):
        if not self.allow_unicode:
            return ""
        return random.choice(DEFAULT_UNICODE) if random.random() < 0.5 else ""

    def _case(self, s):
        if self.case_mode == "normal":
            return s
        if self.case_mode == "lower":
            return s.lower()
        if self.case_mode == "upper":
            return s.upper()
        if self.case_mode == "random":
            out = []
            for ch in s:
                if ch.isalpha() and random.random() < 0.5:
                    out.append(ch.lower())
                else:
                    out.append(ch.upper() if ch.isalpha() else ch)
            return "".join(out)
        return s

    def _pick_word(self):
        pool = random.choice(self.pools)
        return self._case(random.choice(pool))

    def generate_password(self):
        if self.tier == "1":
            w1 = self._pick_word()
            w2 = self._pick_word()
            n1 = random.randint(0, 999)
            n2 = random.randint(0, 999)
            return f"{w1}{self._sep()}{n1:03d}{w2}{self._sep()}{n2:03d}"

        if self.tier == "2":
            w = [self._pick_word() for _ in range(3)]
            n1 = random.randint(0, 9999)
            n2 = random.randint(0, 9999)
            uni = self._maybe_unicode()
            return f"{w[0]}{self._sep()}{w[1]}{self._sep()}{uni}{n1:04d}{w[2]}{self._sep()}{n2:04d}"

        if self.tier == "3":
            w = [self._pick_word() for _ in range(4)]
            n1 = random.randint(0, 99999)
            n2 = random.randint(0, 99999)
            n3 = random.randint(0, 99999)
            uni1 = self._maybe_unicode()
            uni2 = self._maybe_unicode()
            return f"{w[0]}{self._sep()}{w[1]}{self._sep()}{uni1}{n1:05d}{w[2]}{self._sep()}{w[3]}{uni2}{self._sep()}{n2:05d}{n3:05d}"

        if self.tier == "4":
            w = [self._pick_word() for _ in range(5)]
            n1 = random.randint(0, 999999)
            n2 = random.randint(0, 999999)
            punct = "".join(random.choice("!@#$%^&*()-_=+[]{}<>?") for _ in range(random.randint(3, 7)))
            uni = self._maybe_unicode()
            return f"{w[0]}{self._sep()}{w[1]}{uni}{self._sep()}{n1:06d}{punct}{w[2]}{self._sep()}{w[3]}{self._sep()}{w[4]}{self._sep()}{n2:06d}"

        raise ValueError("Invalid tier. Use 1-4")

# -------------------------
# Main
# -------------------------
def main():
    ap = argparse.ArgumentParser(
        description="MythPassGen (Portable CSV Pool Edition)\n"
                    "Keeps pools/ and logs/ next to the script for easy USB migration.\n",
        epilog=(
            "Examples:\n"
            "  ./mythpassgen.py --init\n"
            "  ./mythpassgen.py -n 20000 -t 3\n"
            "  ./mythpassgen.py -n 50000 -t 4 --unicode --case random --pools demons,dragons\n"
            "  ./mythpassgen.py -n 10000 -t 2 --outdir /mnt/f/mnt/c/scr/key/passwords\n"
        ),
        formatter_class=argparse.RawTextHelpFormatter
    )

    ap.add_argument("--init", action="store_true", help="Create pool CSV files if missing, then exit")
    ap.add_argument("--pooldir", default=str(POOLDIR_DEFAULT), help="Pool folder (default: script_dir/pools)")
    ap.add_argument("--outdir", default="", help="Override output directory (default saved in logs/config.json)")
    ap.add_argument("--pools", default="", help="Comma pools to use (demons,military,dragons,viking,chinese). Blank=all")
    ap.add_argument("-n", "--count", type=int, default=10000, help="How many passwords to generate")
    ap.add_argument("-t", "--tier", default="2", help="Tier 1-4 (1=light, 4=nuclear)")
    ap.add_argument("--unicode", action="store_true", help="Enable safe unicode symbols")
    ap.add_argument("--case", choices=["normal", "lower", "upper", "random"], default="normal", help="Case mode")
    ap.add_argument("--merge", action="store_true", help="Merge output files first and remove duplicates")
    ap.add_argument("--outfile", default="passwords.csv",
                    help="Output filename inside outdir (default: passwords.csv). Can be .txt or .csv")

    args = ap.parse_args()

    # ensure portable folders exist
    LOGDIR.mkdir(parents=True, exist_ok=True)

    pooldir = Path(args.pooldir).expanduser()
    created = ensure_pool_files(pooldir)
    if created:
        print("[ Pool CSV files created ]")
        for c in created:
            print(f"  + {c}")

    if args.init:
        print("\n[ Init complete. Edit pool CSVs in pools/ ]")
        return

    # config / outdir
    cfg = interactive_first_run_setup()
    outdir = Path(args.outdir).expanduser() if args.outdir else Path(cfg["outdir"]).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)

    outfile = Path(args.outfile)
    outpath = outdir / outfile.name

    # pool selection
    pool_list = [p.strip() for p in args.pools.split(",") if p.strip()] if args.pools else None
    pools = load_pools(pooldir, only=pool_list)

    # merge is only meaningful if file exists already
    if args.merge and outpath.exists():
        existing = read_lines_any(outpath)
        write_lines_any(outpath, existing)
        print("[ Merge complete: duplicates removed in output file ]")

    gen = PasswordGenerator(
        pools_dict=pools,
        tier=args.tier,
        allow_unicode=args.unicode,
        case_mode=args.case
    )

    passwords = [gen.generate_password() for _ in range(args.count)]
    append_unique(outpath, passwords)

    summary = (
        "========================================\n"
        "🔥 MythPassGen COMPLETE\n"
        f"ScriptDir : {SCRIPT_DIR}\n"
        f"Pooldir   : {pooldir}\n"
        f"Outdir    : {outdir}\n"
        f"Outfile   : {outpath}\n"
        f"Pools     : {args.pools if args.pools else 'ALL'}\n"
        f"Tier      : {args.tier}\n"
        f"Count     : {args.count}\n"
        f"Unicode   : {args.unicode}\n"
        f"Case      : {args.case}\n"
        "========================================\n"
    )

    print(summary)
    logfile = log_run(summary)
    print(f"📝 Log saved: {logfile}")

if __name__ == "__main__":
    main()
