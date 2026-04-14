#!/usr/bin/env bash
# Script Name: welcome.sh
# ID: SCR-ID-20260412154151-320JH0MBXR
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: welcome

echo "🧠======================================"
echo "   WELCOME TO SCR + CODEBRAIN"
echo "======================================"
echo

echo "This is a custom developer environment."
echo "Think of it like a toolbox you can explore."
echo

echo "👉 Quick things you can try:"
echo "  scr0 -l                 → list available commands"
echo "  scr0 -w <command>       → find where a command lives"
echo "  scr0 -e <command>       → open a command for editing"
echo
echo "  scr_cb run <path>       → run CodeBrain on a folder"
echo "  cop <path>              → normalize paths (Windows ↔ Linux)"
echo "  vpy on                  → activate/create Python environment"
echo

echo "👉 Safe playground:"
echo "  codebrain_test_sandbox"
echo "  (You can break anything there safely)"
echo

echo "👉 Example:"
echo "  scr_cb run codebrain_test_sandbox"
echo

echo "--------------------------------------"
echo "Press ENTER to explore commands..."
read

scr0 -l

echo
echo "✔ Tip: run 'guides.sh' anytime for help"
echo
