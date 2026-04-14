#!/usr/bin/env python3
# Script Name: rates_v2.py
# ID: SCR-ID-20260317130812-2CYG4V85PT
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rates_v2

import os
from datetime import datetime

LOG_DIR = "/mnt/c/Users/tyler/Documents/Math/Income-Rates/"

def get_income():
    income = float(input("Enter your income amount: "))
    print("Select income period:")
    print("1. Hourly")
    print("2. Weekly")
    print("3. Bi-Weekly")
    print("4. Monthly")
    print("5. Quarterly")
    print("6. Annually")

    period = input("Enter the number corresponding to your income period: ")

    if period == "1":
        hours_per_week = float(input("Enter hours worked per week: "))
        annual_income = income * hours_per_week * 52
    elif period == "2":
        annual_income = income * 52
    elif period == "3":
        annual_income = income * 26
    elif period == "4":
        annual_income = income * 12
    elif period == "5":
        annual_income = income * 4
    elif period == "6":
        annual_income = income
    else:
        print("Invalid input. Assuming annual income.")
        annual_income = income

    return annual_income

def get_deductions():
    deductions = {}
    while True:
        name = input("Enter deduction name (or 'done' to finish): ")
        if name.lower() == 'done':
            break
        amount = float(input(f"Enter amount for {name}: "))
        deductions[name] = amount
    return deductions

def calculate_take_home(annual_income, deductions):
    total_deductions = sum(deductions.values())
    take_home = annual_income - total_deductions
    return take_home

def format_breakdown(take_home):
    monthly = take_home / 12
    biweekly = take_home / 26
    weekly = take_home / 52
    return monthly, biweekly, weekly

def save_to_file(summary_text):
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = os.path.join(LOG_DIR, f"income_log_{timestamp}.txt")
    with open(file_path, "w") as f:
        f.write(summary_text)
    print(f"\nSummary saved to {file_path}")

def main():
    print("Income and Deduction Calculator")
    annual_income = get_income()
    print(f"Your annual income is: ${annual_income:,.2f}")

    deductions = get_deductions()
    take_home = calculate_take_home(annual_income, deductions)
    monthly, biweekly, weekly = format_breakdown(take_home)

    summary_text = f"Income Summary - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    summary_text += f"Annual Income: ${annual_income:,.2f}\n"
    summary_text += "Deductions:\n"
    for name, amount in deductions.items():
        summary_text += f"  {name}: ${amount:,.2f}\n"
    summary_text += f"Take-home Pay:\n"
    summary_text += f"  Annual: ${take_home:,.2f}\n"
    summary_text += f"  Monthly: ${monthly:,.2f}\n"
    summary_text += f"  Bi-Weekly: ${biweekly:,.2f}\n"
    summary_text += f"  Weekly: ${weekly:,.2f}\n"

    print("\n" + summary_text)
    save_to_file(summary_text)

if __name__ == "__main__":
    main()
