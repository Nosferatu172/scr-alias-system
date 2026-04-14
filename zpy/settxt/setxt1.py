#!/usr/bin/env python3
# Script Name: setxt1.py
# ID: SCR-ID-20260329031355-OYT38AMQPE
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: setxt1

import os

WINPROFILE = ENV["WINPROFILE"]

def rename_first_txt_file(directory):
    # Get all files in the directory
    files = os.listdir(directory)

    # Filter out only .txt files
    txt_files = [file for file in files if file.endswith('.txt')]

    # Check if there's at least one .txt file
    if txt_files:
        # Grab the first .txt file
        first_txt_file = txt_files[0]

        # Define the full paths for the current and new file names
        old_path = os.path.join(directory, first_txt_file)
        new_path = os.path.join(directory, 'exported-tabs.txt')

        # Rename the file
        os.rename(old_path, new_path)
        print(f"Renamed: {first_txt_file} -> exported-tabs.txt")
    else:
        print("No .txt files found in the directory.")

# Usage: Provide the directory path
directory = '$WINPROFILE/Documents/mine/brave/'  # Change this to your folder path
rename_first_txt_file(directory)
