#!/usr/bin/env python3
# Script Name: sptxt1.py
# ID: SCR-ID-20260329031442-VJBUMVMHM8
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: sptxt1

WINPROFILE = ENV["WINPROFILE"]

def split_file(input_file, lines_per_file=1):
    # Open the input file
    with open(input_file, 'r') as f:
        lines = f.readlines()  # Read all lines into a list

    # Calculate the number of new files needed
    num_files = len(lines) // lines_per_file + (1 if len(lines) % lines_per_file > 0 else 0)

    # Split the lines into smaller files
    for i in range(num_files):
        start_line = i * lines_per_file
        end_line = start_line + lines_per_file
        file_lines = lines[start_line:end_line]

        # Define the new file name
        new_file_name = f"{input_file}_part_{i + 1}.txt"

        # Write the lines to the new file
        with open(new_file_name, 'w') as new_file:
            new_file.writelines(file_lines)

        print(f"Created: {new_file_name}")

# Usage: provide the path to the input file you want to split
input_file = '$WINPROFILE/Documents/brave/exported-tabs.txt'  # Update with your actual file path
split_file(input_file)
