#!/usr/bin/env bash
# Script Name: i_dep_script_compare.sh
# ID: SCR-ID-20260329042910-QCJXT9N4KA
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: i_dep_script_compare

apt update

apt install -y \
    libxcb-cursor0 \
    libxcb-xinerama0 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-xfixes0 \
    libxcb-randr0 \
    libxcb-sync1 \
    libxcb-glx0 \
    libx11-xcb1 \
    libxrender1 \
    libxi6 \
    libxkbcommon0
