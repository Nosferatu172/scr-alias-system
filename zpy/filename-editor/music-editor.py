#!/usr/bin/env python3
# Script Name: music-editor.py
# ID: SCR-ID-20260317131034-95EZURQ5EZ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: music-editor

import os
import re

def clean_filenames(directory, filenames):
    # If no specific filenames are provided, clean all in the directory
    if not filenames:
        filenames = os.listdir(directory)

    # Iterate over each file in the provided list of filenames
    for filename in filenames:
        if filename in os.listdir(directory):  # Check if the file exists in the directory
            # Remove content inside square brackets and parentheses
            new_filename = re.sub(r'[\[\(].*?[\]\)]', '', filename).strip()
            # Rename the file only if the name changes
            if new_filename != filename:
                old_path = os.path.join(directory, filename)
                new_path = os.path.join(directory, new_filename)
                os.rename(old_path, new_path)
                print(f'Renamed: "{filename}" to "{new_filename}"')
            else:
                print(f'No change: "{filename}"')
        else:
            print(f'File "{filename}" not found in the directory.')

# Ask for directory path
directory_path = input("Enter the directory path: ")

# Ask for specific files or type *.mp4 for all MP4 files
files_input = input("Enter the filenames or file pattern (e.g., *.mp4) or leave blank to process all: ")

# If user provides a pattern like *.mp4, we find matching files
if files_input:
    if files_input == "*.mp4":
        files_to_process = [f for f in os.listdir(directory_path) if f.endswith('.mp4')]
    else:
        files_to_process = files_input.split()
else:
    files_to_process = []

clean_filenames(directory_path, files_to_process)
