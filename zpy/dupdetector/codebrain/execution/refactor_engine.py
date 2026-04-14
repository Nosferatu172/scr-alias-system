import ast
from pathlib import Path


def replace_function_ast(file_path: str, old_name: str, new_code: str):
    """
    Safely replaces a function using AST.
    """

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            tree = ast.parse(f.read())
    except Exception:
        return False

    new_body = []

    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == old_name:
            continue
        new_body.append(node)

    try:
        new_func = ast.parse(new_code).body[0]
    except Exception:
        return False

    new_body.append(new_func)

    new_tree = ast.Module(body=new_body, type_ignores=[])

    try:
        updated_code = ast.unparse(new_tree)
    except Exception:
        return False

    Path(file_path).write_text(updated_code)
    return True
