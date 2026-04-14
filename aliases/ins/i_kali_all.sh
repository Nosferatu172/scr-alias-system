#!/usr/bin/env bash
# Script Name: i_kali_all.sh
# ID: SCR-ID-20260329042928-J5R2Y4S7VQ
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: i_kali_all

echo 'Installing Kali-linux-everything'

sudo apt-get update
sudo apt update
sudo apt install python3-pip

echo 'lightdm shared/default-x-display-manager select lightdm' | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
-o Dpkg::Options::="--force-confdef" \
-o Dpkg::Options::="--force-confold" \
install kali-linux-everything kali-desktop-xfce lightdm

echo 'Completed Installing kali-linux-everything'
