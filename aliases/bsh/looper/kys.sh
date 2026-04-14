#!/usr/bin/env bash
# Script Name: kys.sh
# ID: SCR-ID-20260329042844-EDG1L8RHWM
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: kys

# repeat-password.sh — runs password-generator back-to-back until Ctrl+C

echo "Running password-generator repeatedly. Press Ctrl+C to stop."

while true; do
    password-generator;  # runs the command and waits until it finishes
done
