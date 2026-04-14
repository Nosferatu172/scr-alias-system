import re


def update_references(file_text: str, old_name: str, new_name: str):
    """
    Replaces all function calls safely
    """

    pattern = rf"\b{old_name}\b"
    return re.sub(pattern, new_name, file_text)
