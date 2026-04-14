from codebrain.core.validator import validate_syntax
from codebrain.core.resolver import update_references


# --------------------------------------------------
# REPLACE FUNCTION SAFELY
# --------------------------------------------------

def replace_function(file_text: str, old_name: str, new_name: str, new_code: str):
    """
    Rewrites a function inside a file safely:
    - removes old function
    - inserts new canonical function
    - updates references
    """

    lines = file_text.splitlines()

    new_lines = []
    skipping = False

    for line in lines:

        # detect function start
        if line.strip().startswith(f"def {old_name}"):
            skipping = True
            continue

        # stop skipping when next function/class appears
        if skipping:
            if line.startswith("def ") or line.startswith("class "):
                skipping = False

        if not skipping:
            new_lines.append(line)

    # append canonical function
    new_lines.append("\n" + new_code + "\n")

    updated = "\n".join(new_lines)

    # update references inside file
    updated = update_references(updated, old_name, new_name)

    # safety check
    if not validate_syntax(updated):
        raise Exception(f"❌ Syntax error after rewriting {old_name}")

    return updated
