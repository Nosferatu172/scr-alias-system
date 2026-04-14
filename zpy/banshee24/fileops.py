#!/usr/bin/env python3
# Script Name: fileops.py
# ID: SCR-ID-20260328145946-TX6DJP2YD7
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: fileops

import os


class FileOps:

    @staticmethod
    def build_dirs():
        """
        Builds and ensures all required directories exist.
        Returns a dictionary of directory paths.
        """

        home = os.path.expanduser("/")

        dirs = {
            "base_dir": os.path.join(home, "/mnt/c/Users/tyler"),
            "cookies_dir": os.path.join(home, "/mnt/c/scr/keys/cookies/", ""),
            "brave_export_dir": os.path.join(home, "/mnt/c/Users/tyler/Documents/brave/", ""),
            "default_music_dir": os.path.join(home, "/mnt/c/Users/tyler/Music", "clm"),
            "default_videos_dir": os.path.join(home, "/mnt/c/Users/tyler/Videos", "clm"),
        }

        # Create all directories if they don't exist
        for path in dirs.values():
            os.makedirs(path, exist_ok=True)

        return dirs

    # =========================
    # FILE HELPERS
    # =========================

    @staticmethod
    def list_files(directory):
        """Returns a list of full file paths in a directory."""
        if not os.path.exists(directory):
            return []

        return [
            os.path.join(directory, f)
            for f in os.listdir(directory)
            if os.path.isfile(os.path.join(directory, f))
        ]

    @staticmethod
    def list_files_with_ext(directory, extensions=None):
        """
        Returns files filtered by extension.
        extensions: list like ['.txt', '.json']
        """
        if not os.path.exists(directory):
            return []

        files = FileOps.list_files(directory)

        if not extensions:
            return files

        return [
            f for f in files
            if os.path.splitext(f)[1].lower() in extensions
        ]

    @staticmethod
    def ensure_dir(path):
        """Ensure a directory exists."""
        os.makedirs(path, exist_ok=True)
        return path

    @staticmethod
    def file_exists(path):
        """Check if a file exists."""
        return os.path.isfile(path)

    @staticmethod
    def read_lines(path):
        """Read file and return cleaned lines."""
        if not os.path.exists(path):
            return []

        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return [line.strip() for line in f if line.strip()]

    @staticmethod
    def write_lines(path, lines):
        """Write lines to a file."""
        with open(path, "w", encoding="utf-8") as f:
            for line in lines:
                f.write(f"{line}\n")

    @staticmethod
    def append_line(path, line):
        """Append a single line to a file."""
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"{line}\n")
