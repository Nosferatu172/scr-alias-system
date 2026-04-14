#!/usr/bin/env bash
# Script Name: numcheck.sh
# ID: SCR-ID-20260412153257-3DMLVSTA0Z
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: numcheck

set -euo pipefail

# --------------------------------------------
# setup-numcheck.sh
# Installs numcheck as /usr/local/bin/numcheck
# Script lives in /usr/local/lib/numcheck/numcheck.py
# Logs live in /usr/local/lib/numcheck/logs/
# --------------------------------------------

INSTALL_DIR="/usr/local/lib/numcheck"
BIN_PATH="/usr/local/bin/numcheck"
PY_PATH="${INSTALL_DIR}/numcheck.py"

echo "==============================================="
echo "   NUMCHECK SETUP (WSL Kali / Debian-based)"
echo "==============================================="

# 1) Dependencies
echo "[1/5] Installing system dependencies..."
sudo apt update
sudo apt install -y python3 python3-pip

echo "[2/5] Installing Python dependency: phonenumbers..."
python3 -m pip install --upgrade pip
python3 -m pip install phonenumbers

# 2) Install directory
echo "[3/5] Creating install directory: ${INSTALL_DIR}"
sudo mkdir -p "${INSTALL_DIR}"
sudo chmod 755 "${INSTALL_DIR}"

# 3) Write the Python script
echo "[4/5] Writing numcheck.py to ${PY_PATH}"
sudo tee "${PY_PATH}" >/dev/null <<'PYEOF'
#!/usr/bin/env python3
import sys
import os
import csv
import argparse
from datetime import datetime, timezone

import phonenumbers
from phonenumbers import geocoder, carrier, number_type, PhoneNumberType

# -----------------------
# Paths (logs next to script)
# -----------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

def now_utc_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def type_name(t: int) -> str:
    mapping = {
        PhoneNumberType.FIXED_LINE: "landline",
        PhoneNumberType.MOBILE: "mobile",
        PhoneNumberType.FIXED_LINE_OR_MOBILE: "landline_or_mobile",
        PhoneNumberType.TOLL_FREE: "toll_free",
        PhoneNumberType.PREMIUM_RATE: "premium_rate",
        PhoneNumberType.SHARED_COST: "shared_cost",
        PhoneNumberType.VOIP: "voip",
        PhoneNumberType.PERSONAL_NUMBER: "personal_number",
        PhoneNumberType.PAGER: "pager",
        PhoneNumberType.UAN: "uan",
        PhoneNumberType.VOICEMAIL: "voicemail",
        PhoneNumberType.UNKNOWN: "unknown",
    }
    return mapping.get(t, f"unknown({t})")

def colorize(s: str, color: str, enable: bool) -> str:
    if not enable:
        return s
    codes = {"red": "31", "yellow": "33", "green": "32", "cyan": "36", "dim": "2"}
    code = codes.get(color)
    if not code:
        return s
    return f"\033[{code}m{s}\033[0m"

def risk_score(valid: bool, possible: bool, t_label: str, car: str, region: str) -> tuple[int, str, list[str]]:
    """
    Conservative, legality-safe "risk" is only about telecom plausibility.
    It is NOT identity, intent, or wrongdoing.
    """
    score = 0
    notes = []

    if not possible:
        score += 60
        notes.append("Not even 'possible' format/length for that region.")
    if possible and not valid:
        score += 35
        notes.append("Possible but not validated as a real assigned number.")
    if t_label == "voip":
        score += 20
        notes.append("VOIP numbers are easier to rotate/obtain than SIM numbers.")
    if t_label == "unknown":
        score += 10
        notes.append("Line type unknown (common with ported numbers).")
    if car in ("", "(unknown)"):
        score += 8
        notes.append("Carrier not available (normal sometimes).")
    if region in ("", "(unknown)"):
        score += 8
        notes.append("Region description not available (normal sometimes).")

    # Clamp
    score = max(0, min(score, 100))

    if score >= 60:
        level = "HIGH"
    elif score >= 30:
        level = "MEDIUM"
    else:
        level = "LOW"

    return score, level, notes

def parse_one(raw: str, default_region: str | None):
    raw = raw.strip()
    if not raw:
        return None

    try:
        num = phonenumbers.parse(raw, default_region or None)
    except phonenumbers.NumberParseException as e:
        return {
            "input": raw,
            "error": f"parse_error: {e}",
        }

    valid = phonenumbers.is_valid_number(num)
    possible = phonenumbers.is_possible_number(num)
    e164 = phonenumbers.format_number(num, phonenumbers.PhoneNumberFormat.E164)

    region_desc = geocoder.description_for_number(num, "en") or "(unknown)"
    car = carrier.name_for_number(num, "en") or "(unknown)"

    t = number_type(num)
    t_label = type_name(t)
    is_voip = (t == PhoneNumberType.VOIP)

    score, level, notes = risk_score(valid, possible, t_label, car, region_desc)

    return {
        "input": raw,
        "e164": e164,
        "valid": valid,
        "possible": possible,
        "region": region_desc,
        "carrier": car,
        "type": t_label,
        "voip": is_voip,
        "risk_score": score,
        "risk_level": level,
        "notes": "; ".join(notes) if notes else "",
    }

def read_inputs(args) -> list[str]:
    nums = []

    # From CLI args
    if args.number:
        nums.extend(args.number)

    # From file
    if args.file:
        with open(args.file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line:
                    nums.append(line)

    # From stdin
    if not sys.stdin.isatty():
        for line in sys.stdin:
            line = line.strip()
            if line:
                nums.append(line)

    # Dedup while keeping order
    seen = set()
    out = []
    for n in nums:
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out

def write_log(line: str, logfile: str):
    path = os.path.join(LOG_DIR, logfile)
    with open(path, "a", encoding="utf-8") as f:
        f.write(line.rstrip("\n") + "\n")

def main():
    p = argparse.ArgumentParser(prog="numcheck", description="Legal telecom plausibility checks (offline).")
    p.add_argument("number", nargs="*", help="Number(s) like +13035551234 or 3035551234")
    p.add_argument("-r", "--region", help="Default region for numbers without +country (e.g., US)", default=None)
    p.add_argument("-f", "--file", help="Read numbers from a text file (one per line).", default=None)
    p.add_argument("--csv", help="Write results to CSV path.", default=None)
    p.add_argument("--no-color", help="Disable colored output.", action="store_true")
    p.add_argument("--log", help="Log filename (stored in logs/ next to script).", default="numcheck.log")

    args = p.parse_args()
    color_on = (not args.no_color) and sys.stdout.isatty()

    inputs = read_inputs(args)
    if not inputs:
        print("Usage: numcheck [+number]...  (or pipe in / use -f file)\n"
              "Examples:\n"
              "  numcheck +13035551234\n"
              "  numcheck 3035551234 -r US\n"
              "  cat numbers.txt | numcheck -r US\n"
              "  numcheck -f numbers.txt -r US --csv out.csv")
        sys.exit(1)

    rows = []
    header = ["timestamp_utc","input","e164","valid","possible","region","carrier","type","voip","risk_level","risk_score","notes","error"]

    for raw in inputs:
        ts = now_utc_iso()
        info = parse_one(raw, args.region)

        # Prepare row
        row = {k: "" for k in header}
        row["timestamp_utc"] = ts
        row["input"] = raw

        if info is None:
            continue

        if "error" in info:
            row["error"] = info["error"]
            rows.append(row)

            msg = f"[{ts}] {raw} -> ERROR: {info['error']}"
            print(colorize(msg, "red", color_on))
            write_log(msg, args.log)
            continue

        row.update({
            "e164": info["e164"],
            "valid": str(info["valid"]),
            "possible": str(info["possible"]),
            "region": info["region"],
            "carrier": info["carrier"],
            "type": info["type"],
            "voip": str(info["voip"]),
            "risk_level": info["risk_level"],
            "risk_score": str(info["risk_score"]),
            "notes": info["notes"],
        })
        rows.append(row)

        # Pretty output
        level = info["risk_level"]
        lvl_color = "green" if level == "LOW" else "yellow" if level == "MEDIUM" else "red"

        print(colorize(f"\nNumber:   {info['input']}", "cyan", color_on))
        print(f"E164:     {info['e164']}")
        print(f"Valid:    {info['valid']}")
        print(f"Possible: {info['possible']}")
        print(f"Region:   {info['region']}")
        print(f"Carrier:  {info['carrier']}")
        print(f"Type:     {info['type']}")
        print(f"VOIP:     {info['voip']}")
        print(colorize(f"Risk:     {level} ({info['risk_score']}/100)", lvl_color, color_on))
        if info["notes"]:
            print(colorize(f"Notes:    {info['notes']}", "dim", color_on))

        logline = (f"[{ts}] input={raw} e164={info['e164']} valid={info['valid']} possible={info['possible']} "
                   f"region='{info['region']}' carrier='{info['carrier']}' type={info['type']} voip={info['voip']} "
                   f"risk={level}({info['risk_score']}) notes='{info['notes']}'")
        write_log(logline, args.log)

    # CSV output
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=header)
            w.writeheader()
            for r in rows:
                w.writerow(r)
        print(colorize(f"\nCSV written: {args.csv}", "cyan", color_on))
        print(colorize(f"Log file:    {os.path.join(LOG_DIR, args.log)}", "cyan", color_on))
    else:
        print(colorize(f"\nLog file: {os.path.join(LOG_DIR, args.log)}", "cyan", color_on))

    # Safety note (kept short)
    print(colorize("Note: This tool checks telecom metadata only—no owner/business identity.", "dim", color_on))

if __name__ == "__main__":
    main()
PYEOF

sudo chmod +x "${PY_PATH}"

# 4) Wrapper command
echo "[5/5] Creating wrapper command at ${BIN_PATH}"
sudo tee "${BIN_PATH}" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec /usr/local/lib/numcheck/numcheck.py "$@"
EOF
sudo chmod +x "${BIN_PATH}"

echo
echo "✅ Installed!"
echo "   Command: numcheck"
echo "   Script:  ${PY_PATH}"
echo "   Logs:    ${INSTALL_DIR}/logs/"

echo
echo "Quick test (US example):"
echo "  numcheck 3035551234 -r US"
