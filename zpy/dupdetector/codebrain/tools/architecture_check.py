#!/usr/bin/env python3

import os
import ast
from pathlib import Path


# --------------------------------------------------
# SCAN REAL MODULES
# --------------------------------------------------

def get_real_modules(base_path: Path):
    modules = set()

    for file in base_path.rglob("*.py"):
        if "__pycache__" in str(file):
            continue

        rel = file.relative_to(base_path)
        module = str(rel).replace("/", ".").replace(".py", "")

        modules.add(f"codebrain.{module}")

    return modules


# --------------------------------------------------
# EXTRACT IMPORTS
# --------------------------------------------------

def extract_imports(file_path: Path):
    imports = set()

    try:
        tree = ast.parse(file_path.read_text())
    except Exception:
        return imports

    for node in ast.walk(tree):

        if isinstance(node, ast.ImportFrom):
            if node.module:
                imports.add(node.module)

        elif isinstance(node, ast.Import):
            for n in node.names:
                imports.add(n.name)

    return imports


# --------------------------------------------------
# BUILD ARCHITECTURE MAP
# --------------------------------------------------

def build_graph(base_path: Path):
    graph = {}

    for file in base_path.rglob("*.py"):
        if "__pycache__" in str(file):
            continue

        module = str(file.relative_to(base_path)).replace("/", ".").replace(".py", "")
        full_module = f"codebrain.{module}"

        graph[full_module] = extract_imports(file)

    return graph


# --------------------------------------------------
# VALIDATION
# --------------------------------------------------

def validate_architecture(base_path: str):
    base = Path(base_path) / "codebrain"

    real_modules = get_real_modules(base)
    graph = build_graph(base)

    errors = []

    print("\n🧠 ARCHITECTURE VALIDATION\n")

    for mod, imports in graph.items():
        for imp in imports:

            # ignore stdlib / external libs
            if not imp.startswith("codebrain"):
                continue

            if imp not in real_modules:
                errors.append((mod, imp))

    if errors:
        print("❌ INVALID IMPORTS DETECTED:\n")

        for src, bad in errors:
            print(f"  {src}  →  {bad}")

        print("\n🚨 ARCHITECTURE VIOLATION")
        return False

    print("✔ Architecture is valid")
    return True


# --------------------------------------------------
# CLI ENTRY
# --------------------------------------------------

if __name__ == "__main__":
    import sys

    path = sys.argv[1] if len(sys.argv) > 1 else "."
    ok = validate_architecture(path)

    if not ok:
        exit(1)
