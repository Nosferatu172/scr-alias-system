#!/usr/bin/env bash
# Script Name: dependancies_converters.sh
# ID: SCR-ID-20260404035023-LT2ZICOG00
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: dependancies_converters

sudo apt install poppler-utils -y
vpy on
pip install pdf2image pillow
pip install pillow reportlab
vpy off
sudo apt install libimage-exiftool-perl

