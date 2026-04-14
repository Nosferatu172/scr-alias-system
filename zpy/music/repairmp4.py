#!/usr/bin/env python3
# Script Name: restores-music-mp4-wsl-4.py
# ID: SCR-ID-20260317131056-H22S4I8S91
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: restores-music-mp4-wsl-4

import os
from datetime import datetime

# Define input and output directories
folder_path = "/mnt/c/Users/tyler/Documents/brave/"
output_folder = "/mnt/c/Users/tyler/Documents/tabs/"

# Print paths for debugging
print(f"Looking in: {folder_path}")
print(f"Saving to: {output_folder}")

# Ensure output folder exists
try:
    os.makedirs(output_folder, exist_ok=True)
    print("✔ Output folder verified or created.")
except Exception as e:
    print(f"❌ Failed to create output folder: {e}")
    exit(1)

# Custom yt-dlp prefix
custom_prefix = 'yt-dlp -S res,ext:mp4:m4a --recode mp4 -o "%(title)s.%(ext)s" -P /mnt/c/Users/tyler/Music/clm-mp4/ "'

# Get timestamp for output filename
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

# Process each .txt file
for filename in os.listdir(folder_path):
    if filename.endswith(".txt"):
        input_file = os.path.join(folder_path, filename)
        output_file = os.path.join(output_folder, f"{timestamp}_{filename}")

        print(f"🔄 Processing: {filename}")

        try:
            with open(input_file, "r", encoding="utf-8") as infile, open(output_file, "w", encoding="utf-8") as outfile:
                for line in infile:
                    stripped_line = line.strip()
                    if stripped_line:
                        modified_line = f"{custom_prefix}{stripped_line}\"\n"
                        outfile.write(modified_line)

            print(f"✅ Saved: {output_file}")
        except Exception as e:
            print(f"❌ Error processing {filename}: {e}")

print("🏁 All files processed.")
