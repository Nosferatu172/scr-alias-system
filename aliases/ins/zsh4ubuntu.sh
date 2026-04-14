#!/usr/bin/env bash
# Script Name: i_zsh.sh
# ID: SCR-ID-20260329042941-82MGUYTP4L
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: i_zsh

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install zsh -y
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
exec zsh
