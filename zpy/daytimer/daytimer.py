#!/usr/bin/env python3
# Script Name: daytimer.py
# ID: SCR-ID-20260404035043-N1J3E8IPI6
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: daytimer

import argparse
import csv
import os
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

PAST_FILE = os.path.join(BASE_DIR, "past_tense.csv")
FUTURE_FILE = os.path.join(BASE_DIR, "days_remaining.csv")


# ---------- Helpers ----------
def parse_date(date_str):
    formats = [
        "%m-%d-%Y",
        "%B %d, %Y",
        "%m-%d-%Y %I:%M%p",
        "%m-%d-%Y %I:%M %p",
        "%B %d, %Y %I:%M%p",
        "%B %d, %Y %I:%M %p",
        "%I:%M%p",
        "%I:%M %p",
    ]

    for fmt in formats:
        try:
            dt = datetime.strptime(date_str, fmt)

            # If only time provided → attach today's date
            if "%Y" not in fmt:
                today = datetime.now()
                dt = dt.replace(year=today.year, month=today.month, day=today.day)

            return dt

        except ValueError:
            continue

    raise ValueError(
        "Invalid format. Use 'MM-DD-YYYY', 'Month DD, YYYY', "
        "optionally with time like '3:45PM'."
    )


def save_date(file_path, date_obj):
    with open(file_path, mode="w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow([date_obj.strftime("%Y-%m-%d %H:%M:%S")])


def load_date(file_path):
    if not os.path.exists(file_path):
        return None

    with open(file_path, mode="r") as file:
        reader = csv.reader(file)
        for row in reader:
            return datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S")
    return None


def calculate_status(target_date):
    now = datetime.now()
    delta = target_date - now

    total_seconds = int(abs(delta.total_seconds()))

    days = total_seconds // 86400
    hours = (total_seconds % 86400) // 3600
    minutes = (total_seconds % 3600) // 60

    if delta.total_seconds() > 0:
        return "future", days, hours, minutes
    elif delta.total_seconds() < 0:
        return "past", days, hours, minutes
    else:
        return "now", 0, 0, 0


# ---------- Setup ----------
def prompt_for_date(label, file_path):
    print(f"No {label} date stored yet.")
    while True:
        user_input = input(
            f"Enter {label} date (MM-DD-YYYY or 'Month DD, YYYY' with optional time): "
        )
        try:
            date_obj = parse_date(user_input)
            save_date(file_path, date_obj)
            print(f"Saved {label} date: {date_obj.strftime('%B %d, %Y %I:%M %p')}")
            return date_obj
        except ValueError as e:
            print(f"Error: {e}")


# ---------- Display ----------
def display(file_path, label, detailed=False):
    date_obj = load_date(file_path)

    if not date_obj:
        return None

    status, days, hours, minutes = calculate_status(date_obj)

    if detailed:
        print(f"{label} date: {date_obj.strftime('%B %d, %Y %I:%M %p')}")

    if status == "future":
        print(f"{label}: {days}d {hours}h {minutes}m remaining")
    elif status == "past":
        print(f"{label}: {days}d {hours}h {minutes}m ago")
    else:
        print(f"{label}: Right now.")

    return True


# ---------- CLI ----------
def main():
    parser = argparse.ArgumentParser(
        description="Track past and future dates (with optional time)."
    )

    parser.add_argument("-p", action="store_true", help="Show past only")
    parser.add_argument("-r", action="store_true", help="Show remaining only")

    # Allow multi-word input without quotes
    parser.add_argument("-ep", nargs="+", help="Set past date")
    parser.add_argument("-er", nargs="+", help="Set remaining date")

    parser.add_argument("-lp", action="store_true", help="Detailed past view")
    parser.add_argument("-lr", action="store_true", help="Detailed remaining view")

    args = parser.parse_args()

    # ----- Set Dates -----
    if args.ep:
        try:
            date_input = " ".join(args.ep)
            d = parse_date(date_input)
            save_date(PAST_FILE, d)
            print(f"Saved past date: {d.strftime('%B %d, %Y %I:%M %p')}")
        except ValueError as e:
            print(e)
        return

    if args.er:
        try:
            date_input = " ".join(args.er)
            d = parse_date(date_input)
            save_date(FUTURE_FILE, d)
            print(f"Saved remaining date: {d.strftime('%B %d, %Y %I:%M %p')}")
        except ValueError as e:
            print(e)
        return

    # ----- Load or Prompt -----
    past_date = load_date(PAST_FILE)
    future_date = load_date(FUTURE_FILE)

    if (args.p or not args.r) and not past_date:
        past_date = prompt_for_date("Past", PAST_FILE)

    if (args.r or not args.p) and not future_date:
        future_date = prompt_for_date("Remaining", FUTURE_FILE)

    # ----- Display Logic -----
    if args.p:
        display(PAST_FILE, "Past", detailed=args.lp)
        return

    if args.r:
        display(FUTURE_FILE, "Remaining", detailed=args.lr)
        return

    # Default → show both
    shown_any = False

    if past_date:
        display(PAST_FILE, "Past", detailed=args.lp)
        shown_any = True

    if future_date:
        display(FUTURE_FILE, "Remaining", detailed=args.lr)
        shown_any = True

    if not shown_any:
        print("No dates stored yet.")


if __name__ == "__main__":
    main()
