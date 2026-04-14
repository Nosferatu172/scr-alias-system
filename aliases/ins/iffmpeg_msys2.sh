#!/usr/bin/env bash
# Script Name: iffmpeg_msys2.sh
# ID: SCR-ID-20260412153150-034WB7CZSU
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: iffmpeg_msys2

# Update system (may need to run twice if prompted)
pacman -Syu --noconfirm || true

# If core packages were updated, rerun update to finish
pacman -Su --noconfirm

# Install FFmpeg and common extras
pacman -S --noconfirm \
  mingw-w64-x86_64-ffmpeg \
  mingw-w64-x86_64-gcc \
  mingw-w64-x86_64-pkg-config \
  mingw-w64-x86_64-x264 \
  mingw-w64-x86_64-x265 \
  mingw-w64-x86_64-libvpx

# Verify installation
echo "---- FFmpeg Version ----"
ffmpeg -version

# Show path for confirmation
echo "---- Installed at ----"
which ffmpeg
