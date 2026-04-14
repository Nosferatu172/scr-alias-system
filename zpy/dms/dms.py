#!/usr/bin/env python3
# Script Name: dms.py
# ID: SCR-ID-20260317130757-N0N8CQ36N3
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dms

import argparse
from datetime import datetime

def decimal_to_dms(decimal_degree):
    degrees = int(decimal_degree)
    minutes_full = abs((decimal_degree - degrees) * 60)
    minutes = int(minutes_full)
    seconds = round((minutes_full - minutes) * 60, 2)
    sign = "-" if decimal_degree < 0 else ""
    return f"{sign}{abs(degrees)}° {minutes}′ {seconds}″"

def dms_to_decimal(degrees, minutes, seconds):
    sign = -1 if degrees < 0 else 1
    return sign * (abs(degrees) + (minutes / 60) + (seconds / 3600))

def unit_to_decimal(value, unit):
    unit = unit.lower()
    if unit.startswith("h"):
        return value
    elif unit.startswith("m"):
        return value / 60
    elif unit.startswith("s"):
        return value / 3600
    else:
        raise ValueError("Invalid unit type. Use hours, minutes, or seconds.")

def apply_math_operation(decimal_val, op, op_val):
    if op == '+':
        return decimal_val + op_val
    elif op == '-':
        return decimal_val - op_val
    elif op == '*':
        return decimal_val * op_val
    elif op == '/':
        if op_val == 0:
            raise ValueError("Cannot divide by zero")
        return decimal_val / op_val
    else:
        raise ValueError("Invalid operation. Use + - * /")

def format_decimal(val):
    return round(val, 2)

def main():
    parser = argparse.ArgumentParser(description="DMS/Decimal Converter CLI")
    parser.add_argument("--mode", choices=["manual", "file"], default="manual", help="Mode of operation")
    parser.add_argument("--type", choices=["decimal", "dms", "unit"], required=True, help="Input type")
    parser.add_argument("--decimal", type=float, help="Decimal degrees input")
    parser.add_argument("--deg", type=float, help="Degrees for DMS")
    parser.add_argument("--min", type=float, default=0, help="Minutes for DMS")
    parser.add_argument("--sec", type=float, default=0, help="Seconds for DMS")
    parser.add_argument("--value", type=float, help="Value for hours/minutes/seconds mode")
    parser.add_argument("--unit", choices=["h", "m", "s"], help="Unit type for value")
    parser.add_argument("--op", choices=["+", "-", "*", "/"], help="Math operation")
    parser.add_argument("--op_val", type=float, help="Value for math operation")

    args = parser.parse_args()

    # Determine decimal value
    if args.type == "decimal":
        if args.decimal is None:
            raise ValueError("Decimal value required")
        decimal_val = args.decimal
    elif args.type == "dms":
        if args.deg is None:
            raise ValueError("Degrees required for DMS input")
        decimal_val = dms_to_decimal(args.deg, args.min, args.sec)
    elif args.type == "unit":
        if args.value is None or args.unit is None:
            raise ValueError("Value and unit required for unit mode")
        decimal_val = unit_to_decimal(args.value, args.unit)

    original_dms = decimal_to_dms(decimal_val)

    # Apply math if provided
    if args.op and args.op_val is not None:
        modified_val = apply_math_operation(decimal_val, args.op, args.op_val)
        modified_dms = decimal_to_dms(modified_val)
    else:
        modified_val = None
        modified_dms = None

    # Display results
    print("\n--- Results ---")
    if args.type == "unit":
        print(f"Original Input: {args.value} {args.unit}")
    elif args.type == "dms":
        print(f"Original DMS: {args.deg}° {args.min}′ {args.sec}″")
    print(f"Decimal Degrees: {format_decimal(decimal_val)}")
    print(f"DMS: {original_dms}")

    if modified_val is not None:
        print(f"\nModified (operation: {args.op} {args.op_val}):")
        print(f"Decimal Degrees: {format_decimal(modified_val)}")
        print(f"DMS: {modified_dms}")

if __name__ == "__main__":
    main()
