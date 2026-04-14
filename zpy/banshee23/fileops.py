#!/usr/bin/env python3
# Script Name: fileops.py
# ID: SCR-ID-20260317131043-9TVNNBI94X
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: fileops
# fileops.py
# Centralized directory configuration (edit paths here)

from __future__ import annotations

DEFAULT_DIRS = {
    "brave_export_dir":  "/mnt/c/Users/{WIN_USER}/Documents/brave/",
    "default_music_dir": "/mnt/d/Windows/Music/clm/y-hold/",
    "default_videos_dir": "/mnt/d/Windows/Music/clm/Videos/y-hold/",
    "music_artist_dir":  "/mnt/d/Windows/Music/clm/Active-org/",
    "video_artist_dir":  "/mnt/d/Windows/Music/clm/Videos/Active-org/",
}

def with_win_user(template_path: str, win_user: str) -> str:
    return str(template_path).replace("{WIN_USER}", str(win_user))

def build_dirs(win_user: str) -> dict[str, str]:
    """
    Returns a dict with the same keys as DEFAULT_DIRS,
    with {WIN_USER} injected anywhere it appears.
    """
    return {k: with_win_user(v, win_user) for k, v in DEFAULT_DIRS.items()}
