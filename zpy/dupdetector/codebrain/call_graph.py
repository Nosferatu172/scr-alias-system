import ast
from collections import defaultdict
from pathlib import Path


# ==================================================
# SYMBOL TABLE BUILDER (FILE LEVEL)
# ==================================================

def build_symbol_table(files):
    """
    Builds:
    function_name -> list of file paths where defined
    """

    table = defaultdict(list)

    for file_path in files:
        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                tree = ast.parse(f.read())
        except Exception:
            continue

        for node in tree.body:
            if isinstance(node, ast.FunctionDef):
                table[node.name].append(str(file_path))

    return dict(table)


# ==================================================
# DEPENDENCY RESOLVER (AST + IMPORT AWARE)
# ==================================================

class DependencyResolver(ast.NodeVisitor):

    def __init__(self, file_path, symbol_table):
        self.file_path = str(file_path)
        self.symbol_table = symbol_table

        self.current_function = None
        self.dependencies = defaultdict(set)

        # alias map
        self.imports = {}

    # -----------------------------
    # IMPORT HANDLING
    # -----------------------------

    def visit_Import(self, node):
        for alias in node.names:
            name = alias.name
            asname = alias.asname or name
            self.imports[asname] = name

    def visit_ImportFrom(self, node):
        module = node.module or ""

        for alias in node.names:
            name = alias.name
            asname = alias.asname or name
            full = f"{module}.{name}" if module else name
            self.imports[asname] = full

    # -----------------------------
    # FUNCTION CONTEXT
    # -----------------------------

    def visit_FunctionDef(self, node):
        prev = self.current_function
        self.current_function = node.name

        self.generic_visit(node)

        self.current_function = prev

    def visit_AsyncFunctionDef(self, node):
        self.visit_FunctionDef(node)

    # -----------------------------
    # CALL RESOLUTION
    # -----------------------------

    def visit_Call(self, node):
        if not self.current_function:
            return

        target = self._resolve(node.func)

        if target:
            resolved = self._resolve_symbol(target)
            self.dependencies[self.current_function].add(resolved)

        self.generic_visit(node)

    def _resolve(self, node):
        if isinstance(node, ast.Name):
            return node.id

        if isinstance(node, ast.Attribute):
            return node.attr

        return None

    def _resolve_symbol(self, name):
        # check imports first
        if name in self.imports:
            return self.imports[name]

        # check global symbol table
        if name in self.symbol_table:
            files = self.symbol_table[name]
            return f"{files[0]}:{name}"

        return name


# ==================================================
# BUILD FULL DEPENDENCY GRAPH
# ==================================================

def build_call_graph(files):
    """
    Returns:
    function -> list of resolved dependencies
    """

    symbol_table = build_symbol_table(files)
    graph = defaultdict(set)

    for file_path in files:
        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                tree = ast.parse(f.read())
        except Exception:
            continue

        resolver = DependencyResolver(file_path, symbol_table)
        resolver.visit(tree)

        for func, deps in resolver.dependencies.items():
            graph[f"{file_path}:{func}"].update(deps)

    return {k: list(v) for k, v in graph.items()}


# ==================================================
# USAGE MAP (INCOMING EDGES)
# ==================================================

def build_usage_map(call_graph):
    usage = defaultdict(int)

    for caller, callees in call_graph.items():
        for callee in callees:
            usage[callee] += 1

    return dict(usage)


# ==================================================
# SAFE FILTER (UPDATED TO HANDLE FULL KEYS)
# ==================================================

def filter_safe_groups(confident_groups, usage_map, max_risk=2):
    safe = []

    for key, group, score in confident_groups:

        risk = 0

        for func in group:
            name = func["name"]
            usage = usage_map.get(name, 0)

            if usage > 5:
                risk += 2
            elif usage > 2:
                risk += 1

        if risk <= max_risk:
            safe.append((key, group, score))
        else:
            print(f"⚠️ Skipping risky group: {group[0]['name']} (risk={risk})")

    return safe
