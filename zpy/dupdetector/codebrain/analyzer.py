import ast
from difflib import SequenceMatcher


# ==================================================
# FUNCTION EXTRACTION
# ==================================================

class FunctionExtractor(ast.NodeVisitor):
    def __init__(self):
        self.functions = []

    def visit_FunctionDef(self, node):
        ops = []

        for n in ast.walk(node):
            if isinstance(n, ast.BinOp):
                ops.append(type(n.op).__name__)
            elif isinstance(n, ast.Call):
                ops.append("Call")
            elif isinstance(n, ast.Return):
                ops.append("Return")
            elif isinstance(n, ast.If):
                ops.append("If")

        signature = f"{node.name}|args:{len(node.args.args)}|ops:{sorted(set(ops))}"

        self.functions.append({
            "name": node.name,
            "line": node.lineno,
            "raw_signature": signature,
            "file": None
        })

        self.generic_visit(node)


# ==================================================
# FILE ANALYSIS
# ==================================================

def analyze_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            tree = ast.parse(f.read())
    except Exception:
        return []

    extractor = FunctionExtractor()
    extractor.visit(tree)

    return extractor.functions


def analyze_files(files):
    out = []

    for file in files:
        funcs = analyze_file(file)

        for f in funcs:
            f["file"] = str(file)

        out.extend(funcs)

    return out


# ==================================================
# DUPLICATE GROUPING
# ==================================================

def group_duplicates(functions):
    groups = {}

    for f in functions:
        key = f["raw_signature"]
        groups.setdefault(key, []).append(f)

    return groups


# ==================================================
# NEAR DUPLICATES (LIGHTWEIGHT ONLY)
# ==================================================

def similarity(a, b):
    return SequenceMatcher(None, a, b).ratio()


def find_near_duplicates(functions, threshold=0.85):
    matches = []

    for i in range(len(functions)):
        for j in range(i + 1, len(functions)):
            s = similarity(
                functions[i]["raw_signature"],
                functions[j]["raw_signature"]
            )

            if s >= threshold:
                matches.append((functions[i], functions[j], s))

    return matches
