import ast


def improve_function(func_code):
    """
    Basic AI-style improvement:
    - removes duplicate returns
    - simplifies structure
    """

    try:
        tree = ast.parse(func_code)
    except Exception:
        return func_code  # fallback

    class Simplifier(ast.NodeTransformer):

        def visit_If(self, node):
            # simple pattern:
            # if cond: return x else: return y → inline
            if (
                len(node.body) == 1
                and len(node.orelse) == 1
                and isinstance(node.body[0], ast.Return)
                and isinstance(node.orelse[0], ast.Return)
            ):
                return ast.Return(
                    value=ast.IfExp(
                        test=node.test,
                        body=node.body[0].value,
                        orelse=node.orelse[0].value
                    )
                )
            return node

    new_tree = Simplifier().visit(tree)

    try:
        return ast.unparse(new_tree)
    except Exception:
        return func_code
