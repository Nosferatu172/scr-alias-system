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
echo "  scr -l                 → list available commands"
echo "  scr -w <command>       → find where a command lives"
echo "  scr -e <command>       → open a command for editing"
echo
echo "  scr_cb run <path>       → run CodeBrain on a folder < not currently finished"
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

echo "Your Main Controller is called 'scr'"
echo "this when you start off run scr -clear"
echo "this resets your 'scr' to now linked scripts to run"
echo "if you 'scr -set' then it begins to find them in a these set directories"
echo "aliases is direct linked in the /lib folder inside aliases, all files are treated as aliases..."
echo "as if they where written inside .bashrc or .zshrc, feel free to expand and write more"
echo "zru, is for ruby. zpy is for python. bsh is for bash. zsh is for zsh scripts."
echo "I have not added more interpretures yet but will in upcoming."
echo "if you need help, with those script type or just wish to play around."
echo "type in 'scr -e sample' this will open up a sample.sh you can play with"
echo "if you wish to go to a script type in 'scr -c sample' or if you wish to take a look at a script"
echo "type in 'scr -v sample'. one thing you will notice, you can run a script without having to type in the extensions"
echo "if you wish to make some scripts, i have left behind 'mktool' for you."
echo "'scr mktool -h' it will give you some idea."
echo
echo "✔ Tip: run 'guides.sh' anytime for help"
echo
