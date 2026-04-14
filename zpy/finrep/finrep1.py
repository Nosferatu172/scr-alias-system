#!/usr/bin/env python3
import os
import re
import sys

def is_binary(file_path):
    try:
        with open(file_path, 'rb') as f:
            return b'\0' in f.read(1024)
    except:
        return True

def search_files(root, pattern):
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

        # Apply replacement
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()

            lines[lineno - 1] = compiled.sub(replacement, lines[lineno - 1])

            with open(path, 'w', encoding='utf-8') as f:
                f.writelines(lines)

            print("✅ Replaced.")
        except Exception as e:
            print(f"⚠️ Failed: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: script.py <directory>")
        sys.exit(1)

    root = sys.argv[1]

    search = input("🔍 Enter search phrase: ")
    replace = input("✏️ Enter replacement: ")

    # Escape user input so special chars work literally
    pattern = re.escape(search)

    print("\n🔎 Scanning...")
    matches = search_files(root, pattern)

    print(f"Found {len(matches)} matches.")

    if matches:
        interactive_replace(matches, pattern, replace)
    else:
        print("No matches found.")

if __name__ == "__main__":
    main()
