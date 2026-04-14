from pathlib import Path

from .config import IGNORE_DIRS, SUPPORTED_EXTENSIONS, SELF_DIR


# --------------------------------------------------
# IGNORE LOGIC
# --------------------------------------------------

def is_ignored(path: Path) -> bool:
    """
    Ignore:
    - dependency folders
    - system/generated folders
    - the CodeBrain tool itself
    """

    # NEVER scan CodeBrain itself
    try:
        if SELF_DIR in path.parents:
            return True
    except Exception:
        return False

    # Ignore known directories
    for part in path.parts:
        if part in IGNORE_DIRS:
            return True

    return False


# --------------------------------------------------
# FILE SCANNER
# --------------------------------------------------

def scan_files(root: str):
    """
    Recursively scan a project directory and return
    all valid source files based on extension rules.
    """

    root_path = Path(root)

    if not root_path.exists():
        raise FileNotFoundError(f"Path not found: {root}")

    files = []

    for path in root_path.rglob("*"):

        # skip non-files
        if not path.is_file():
            continue

        # skip ignored paths
        if is_ignored(path):
            continue

        # filter supported file types
        if path.suffix not in SUPPORTED_EXTENSIONS:
            continue

        files.append(path)

    return files
