#!/usr/bin/env python3
import os
import re
import sys
import argparse

# --------------------------------------------------
# HELP FORMATTER
# --------------------------------------------------

class CustomHelp(argparse.RawTextHelpFormatter):
    pass

# --------------------------------------------------
# UTILS
# --------------------------------------------------

def is_binary(file_path):
    try:
        with open(file_path, 'rb') as f:
            return b'\0' in f.read(1024)
    except:
        return True

def scan_files(root, pattern):
    matches = []
    for dirpath, _, filenames in os.walk(root):
        for fname in filenames:
            path = os.path.join(dirpath, fname)

            if is_binary(path):
                continue

            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    for i, line in enumerate(f, 1):
                        if re.search(pattern, line, re.IGNORECASE):
                            matches.append((path, i, line.rstrip()))
            except:
                continue

    return matches

def interactive_replace(matches, pattern, replacement):
    compiled = re.compile(pattern, re.IGNORECASE)
    replace_all = False

    for path, lineno, line in matches:
        new_line = compiled.sub(replacement, line)

        if line == new_line:
            continue

        print(f"\n📄 {path}:{lineno}")
        print(f" - {line}")
        print(f" + {new_line}")

        if not replace_all:
            choice = input("Replace? [y]es / [n]o / [a]ll / [q]uit: ").lower()
        else:
            choice = 'y'

        if choice == 'q':
            print("❌ Aborted.")
            return
        elif choice == 'a':
            replace_all = True
        elif choice != 'y':
            continue

        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()

            lines[lineno - 1] = compiled.sub(replacement, lines[lineno - 1])

            with open(path, 'w', encoding='utf-8') as f:
                f.writelines(lines)

            print("✅ Replaced.")
        except Exception as e:
            print(f"⚠️ Failed: {e}")

# --------------------------------------------------
# CLI
# --------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(
        prog="grip",
        formatter_class=CustomHelp,
        add_help=False,
        description="""
🧠 GRIP — Recursive Interactive Grep + Replace

Search and replace phrases across files safely, including special characters:

  [ ] ( ) !! < > { } - + _ = \\ | " : ; ? , .

Examples:
  grip -a -w "foo[bar]"
  grip -d /path/to/code -w "hello world"
"""
    )

    # Help flags
    parser.add_argument('-h', '--h', '--help', action='help',
                        help='Show this help message and exit')

    # Directory options
    parser.add_argument('-a', '--a', '-cwd', action='store_true',
                        help='Use current working directory')

    parser.add_argument('-d', metavar='PATH',
                        help='Target directory path')

    # Search phrase
    parser.add_argument('-w', '--w', '--word', required=False,
                        help='Search phrase (supports special characters)')

    return parser

# --------------------------------------------------
# MAIN
# --------------------------------------------------

def main():
    parser = build_parser()
    args = parser.parse_args()

    # Resolve directory
    if args.a:
        root = os.getcwd()
    elif args.d:
        root = args.d
    else:
        print("❌ You must specify a directory: -a (cwd) or -d /path")
        sys.exit(1)

    if not os.path.isdir(root):
        print(f"❌ Invalid directory: {root}")
        sys.exit(1)

    # Get search phrase
    if args.w:
        search = args.w
    else:
        search = input("🔍 Enter search phrase: ")

    replace = input("✏️ Enter replacement: ")

    # Escape special characters literally
    pattern = re.escape(search)

    print(f"\n🔎 Scanning: {root}")
    matches = scan_files(root, pattern)

    print(f"📊 Found {len(matches)} matches.")

    if matches:
        interactive_replace(matches, pattern, replace)
    else:
        print("No matches found.")

if __name__ == "__main__":
    main()
