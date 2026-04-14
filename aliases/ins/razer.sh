#!/usr/bin/env bash
# Script Name: razer.sh
# ID: SCR-ID-20260404035031-F8IK2OSF1C
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: razer
zsudo add-apt-repository ppa:openrazer/stable
sudo add-apt-repository ppa:polychromatic/stable
sudo apt-get update -y
sudo apt install openrazer-meta polychromatic
sudo gpasswd -a $USER plugdev
sudo apt-get update -y
sudo apt install openrazer-meta -y
sudo apt install python-openrazer -y
sudo apt install python3-openrazer -y
sudo modprobe razerkbd
echo "Now reboot or reconnect the keyboard in order for it to take effect"
