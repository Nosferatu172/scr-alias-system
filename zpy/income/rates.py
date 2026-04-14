#!/usr/bin/env python3
# Script Name: rates.py
# ID: SCR-ID-20260317130808-A2PDB58EQ9
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rates

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

def main():
    print("Income and Deduction Calculator")
    annual_income = get_income()
    print(f"Your annual income is: ${annual_income:,.2f}")

    deductions = get_deductions()
    take_home = calculate_take_home(annual_income, deductions)

    print("\nSummary:")
    print(f"Annual Income: ${annual_income:,.2f}")
    print("Deductions:")
    for name, amount in deductions.items():
        print(f"  {name}: ${amount:,.2f}")
    print(f"Take-home Pay: ${take_home:,.2f}")

if __name__ == "__main__":
    main()
