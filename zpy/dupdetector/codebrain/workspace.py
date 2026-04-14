from pathlib import Path
import os
import json


# --------------------------------------------------
# CREATE WORKSPACE FOLDER
# --------------------------------------------------

def init_workspace(root_path: str):
    """
    Creates a dedicated output folder inside the project
    """

    ws = Path(root_path) / "refactor_workspace"

    os.makedirs(ws, exist_ok=True)
    os.makedirs(ws / "backups", exist_ok=True)

    return ws


# --------------------------------------------------
# SAFE JSON WRITER
# --------------------------------------------------

def write_json(path: Path, data):
    """
    Writes structured output safely
    """

    def clean(obj):
        # makes numpy / non-serializable objects safe later
        try:
            import numpy as np
            if isinstance(obj, np.ndarray):
                return obj.tolist()
        except Exception:
            pass

        return obj

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=clean)
