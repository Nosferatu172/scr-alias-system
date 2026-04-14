#!/usr/bin/env python3
# Script Name: dms-calc.py
# ID: SCR-ID-20260317130753-YCW7480CLH
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dms-calc

import os
from datetime import datetime

DEFAULT_INPUT_DIR = "/mnt/c/Users/tyler/Documents/dms-calc/inputs/"
DEFAULT_OUTPUT_DIR = "/mnt/c/Users/tyler/Documents/dms-calc/results/"

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

def apply_math_operation(decimal_val):
    do_math = input("Apply math operation? (y/n): ").strip().lower()
    if do_math != 'y':
        return None, None, None

    op = input("Enter operation (+, -, *, /): ").strip()
    try:
        value = float(input("Enter value: "))
    except ValueError:
        print("Invalid number. Skipping math operation.")
        return None, None, None

    if op == '+':
        modified = decimal_val + value
    elif op == '-':
        modified = decimal_val - value
    elif op == '*':
        modified = decimal_val * value
    elif op == '/':
        if value == 0:
            print("Cannot divide by zero. Skipping math operation.")
            return None, None, None
        modified = decimal_val / value
    else:
        print("Invalid operation. Skipping math operation.")
        return None, None, None

    return op, value, modified

def format_decimal(decimal_val):
    return round(decimal_val, 2)

def process_file(input_path, conversion_type):
    with open(input_path, "r") as f:
        lines = f.readlines()

    results = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            if conversion_type == "1":  # Decimal → DMS
                value = float(line)
                converted = decimal_to_dms(value)
                results.append(f"Input: {line}")
                results.append(f"Output: {converted}")
                results.append("")
            elif conversion_type == "2":  # DMS → Decimal
                parts = line.replace("°", "").replace("′", "").replace("″", "").split()
                degrees, minutes, seconds = map(float, parts)
                converted = str(dms_to_decimal(degrees, minutes, seconds))
                results.append(f"Input: {line}")
                results.append(f"Output: {converted}")
                results.append("")
        except ValueError:
            results.append(f"Invalid input: {line}")
            results.append("")
    return results

def save_results(results, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = os.path.join(output_dir, f"conversion_results_{timestamp}.txt")
    with open(output_file, "w") as f:
        for result in results:
            f.write(result + "\n")
    print(f"Results saved to: {output_file}")

def choose_file_from_directory(directory):
    if not os.path.isdir(directory):
        print("Directory not found.")
        return None

    txt_files = [f for f in os.listdir(directory) if f.lower().endswith(".txt")]
    if not txt_files:
        print("No .txt files found in this directory.")
        return None

    print("\nAvailable .txt files:")
    for i, file in enumerate(txt_files, start=1):
        print(f"{i}) {file}")

    try:
        choice = int(input("Select a file number: "))
        if 1 <= choice <= len(txt_files):
            return os.path.join(directory, txt_files[choice - 1])
    except ValueError:
        pass

    print("Invalid selection.")
    return None

def manual_decimal_mode():
    val = float(input("Enter decimal degrees: "))
    original_dms = decimal_to_dms(val)
    print(f"Original Decimal: {format_decimal(val)}")
    print(f"Original DMS: {original_dms}")

    op, op_val, modified = apply_math_operation(val)
    if modified is not None:
        modified_dms = decimal_to_dms(modified)
        print(f"Modified Decimal: {format_decimal(modified)}")
        print(f"Modified DMS: {modified_dms}")
        return [
            f"Original Decimal: {format_decimal(val)}",
            f"Original DMS: {original_dms}",
            f"Modified (operation: {op} {op_val}): {format_decimal(modified)}",
            f"Modified DMS: {modified_dms}",
            ""
        ]
    else:
        return [
            f"Original Decimal: {format_decimal(val)}",
            f"Original DMS: {original_dms}",
            ""
        ]

def manual_dms_mode():
    deg = float(input("Degrees: "))
    mins = float(input("Minutes: "))
    secs = float(input("Seconds: "))
    decimal_val = dms_to_decimal(deg, mins, secs)
    original_dms = f"{deg}° {mins}′ {secs}″"
    print(f"Original Decimal: {format_decimal(decimal_val)}")
    print(f"Original DMS: {original_dms}")

    op, op_val, modified = apply_math_operation(decimal_val)
    if modified is not None:
        modified_dms = decimal_to_dms(modified)
        print(f"Modified Decimal: {format_decimal(modified)}")
        print(f"Modified DMS: {modified_dms}")
        return [
            f"Original Decimal: {format_decimal(decimal_val)}",
            f"Original DMS: {original_dms}",
            f"Modified (operation: {op} {op_val}): {format_decimal(modified)}",
            f"Modified DMS: {modified_dms}",
            ""
        ]
    else:
        return [
            f"Original Decimal: {format_decimal(decimal_val)}",
            f"Original DMS: {original_dms}",
            ""
        ]

def manual_unit_mode():
    val = float(input("Enter numeric value: "))
    unit = input("Is this value in hours, minutes, or seconds? ").strip()
    decimal_val = unit_to_decimal(val, unit)
    original_dms = decimal_to_dms(decimal_val)
    print(f"Original Input: {val} {unit}")
    print(f"Decimal Degrees: {format_decimal(decimal_val)}")
    print(f"DMS: {original_dms}")

    op, op_val, modified = apply_math_operation(decimal_val)
    if modified is not None:
        modified_dms = decimal_to_dms(modified)
        print(f"Modified Decimal: {format_decimal(modified)}")
        print(f"Modified DMS: {modified_dms}")
        return [
            f"Original Input: {val} {unit}",
            f"Decimal Degrees: {format_decimal(decimal_val)}",
            f"DMS: {original_dms}",
            f"Modified (operation: {op} {op_val}): {format_decimal(modified)}",
            f"Modified DMS: {modified_dms}",
            ""
        ]
    else:
        return [
            f"Original Input: {val} {unit}",
            f"Decimal Degrees: {format_decimal(decimal_val)}",
            f"DMS: {original_dms}",
            ""
        ]

def main():
    while True:
        print("\n--- Coordinate Converter ---")
        print("1) Decimal → DMS")
        print("2) DMS → Decimal")
        print("e) Exit")
        choice = input("Select conversion type (1/2/e): ").strip()

        if choice == "e":
            print("Exiting...")
            break
        elif choice not in ("1", "2"):
            print("Invalid choice.")
            continue

        mode = input("Manual input (M) or File input (F)? ").strip().lower()

        if mode == "m":
            special = input("Do you want to use hours/minutes/seconds input mode? (y/n): ").strip().lower()
            if special == "y":
                results = manual_unit_mode()
            else:
                if choice == "1":
                    results = manual_decimal_mode()
                else:
                    results = manual_dms_mode()

            save_choice = input("Save results? (y/n): ").strip().lower()
            if save_choice == "y":
                dir_choice = input("Save to default directory? (y) or current? (n): ").strip().lower()
                if dir_choice == 'y':
                    output_dir = DEFAULT_OUTPUT_DIR
                else:
                    output_dir = os.getcwd()
                save_results(results, output_dir)

        elif mode == "f":
            use_default = input("Use default input directory? (y/n): ").strip().lower()
            if use_default == "y":
                input_path = choose_file_from_directory(DEFAULT_INPUT_DIR)
            else:
                custom_dir = input("Enter directory path: ").strip()
                input_path = choose_file_from_directory(custom_dir)

            if not input_path:
                continue

            results = process_file(input_path, choice)

            save_choice = input("Save results? (y/n): ").strip().lower()
            if save_choice == "y":
                dir_choice = input("Save to same directory (S) or default directory (D)? ").strip().lower()
                if dir_choice == "s":
                    output_dir = os.path.dirname(input_path)
                else:
                    output_dir = DEFAULT_OUTPUT_DIR
                save_results(results, output_dir)
            else:
                print("\n--- Results ---")
                for r in results:
                    print(r)
        else:
            print("Invalid mode.")

if __name__ == "__main__":
    main()
