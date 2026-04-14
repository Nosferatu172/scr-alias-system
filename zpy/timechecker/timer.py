#!/usr/bin/env python3
# Script Name: timer.py
# ID: SCR-ID-20260317130908-PS2EAST7H8
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: timer

import os
import json
from datetime import datetime, timedelta

# Config paths
BASE_DIR = "/mnt/c/scr/zpy/timer"
LOG_DIR = os.path.join(BASE_DIR, "logs")
CONFIG_FILE = os.path.join(BASE_DIR, "config.json")

# Ensure folders exist
os.makedirs(LOG_DIR, exist_ok=True)

def save_config(target_date):
    """Save the target date to config.json"""
    with open(CONFIG_FILE, "w") as f:
        json.dump({"target_date": target_date.strftime("%m/%d/%Y")}, f)

def load_config():
    """Load the target date from config.json"""
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            data = json.load(f)
            return datetime.strptime(data["target_date"], "%m/%d/%Y")
    return None

def get_time_remaining(target_date):
    """Return a timedelta until the target date"""
    return target_date - datetime.now()

def set_new_date():
    """Prompt user for new target date"""
    while True:
        try:
            new_date = input("Enter new target date (MM/DD/YYYY): ").strip()
            target_date = datetime.strptime(new_date, "%m/%d/%Y")
            save_config(target_date)
            print(f"Target date set to {target_date.strftime('%B %d, %Y')}")
            return target_date
        except ValueError:
            print("Invalid format. Please use MM/DD/YYYY.")

def main():
    print("=== Countdown Timer ===")

    target_date = load_config()
    if target_date is None:
        print("No target date found.")
        target_date = set_new_date()
    else:
        print(f"Current target date: {target_date.strftime('%B %d, %Y')}")

    while True:
        print("\nOptions:")
        print("1. Show time remaining")
        print("2. Reset target date")
        print("3. Exit")
        choice = input("> ").strip()

        if choice == "1":
            remaining = get_time_remaining(target_date)
            if remaining.total_seconds() > 0:
                days, seconds = divmod(int(remaining.total_seconds()), 86400)
                hours, seconds = divmod(seconds, 3600)
                minutes, seconds = divmod(seconds, 60)
                print(f"Time remaining: {days}d {hours}h {minutes}m {seconds}s")
            else:
                print("The target date has passed.")
        elif choice == "2":
            target_date = set_new_date()
        elif choice == "3":
            print("Exiting timer.")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    main()
