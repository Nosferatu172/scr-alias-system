# diff_engine.py

import difflib


def generate_diff(original: str, modified: str):
    return "\n".join(
        difflib.unified_diff(
            original.splitlines(),
            modified.splitlines(),
            fromfile="original",
            tofile="modified"
        )
    )
