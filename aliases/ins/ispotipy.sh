#!/usr/bin/env bash
# Script Name: ispotipy.sh
# ID: SCR-ID-20260412153104-A9Z7XIST9U
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: ispotipy

echo "Turning on vpy"
vpy on
echo "Installiing PiP spotipy"
pip install spotipy
echo "Completed Installing PiP spotipy"
echo "Turning off vpy"
vpy off
echo "Completed Install"
