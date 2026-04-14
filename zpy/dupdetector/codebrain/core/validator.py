import ast


def validate_syntax(code: str) -> bool:
    """
    Ensures rewritten code is valid Python
    """

    try:
        ast.parse(code)
        return True
    except SyntaxError:
        return False
