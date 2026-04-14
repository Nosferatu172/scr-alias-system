from pathlib import Path

SUPPORTED_EXTENSIONS = {".py", ".rb", ".js"}

IGNORE_DIRS = {
    ".git",
    "__pycache__",
    "node_modules",
    ".venv",
    "refactor_workspace",
    "codebrain.egg-info"
}

# --------------------------------------------------
# FIX: PACKAGE ROOT INSTEAD OF CORE DIR
# --------------------------------------------------

SELF_DIR = Path(__file__).resolve().parents[1]
