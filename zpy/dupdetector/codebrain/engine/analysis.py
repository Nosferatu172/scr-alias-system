from codebrain.scanner import scan_files
from codebrain.analyzer import analyze_files, group_duplicates
from codebrain.call_graph import build_call_graph, build_usage_map


class AnalysisPhase:

    def run(self, ctx):
        ctx.files = scan_files(ctx.path)
        ctx.functions = analyze_files(ctx.files)
        ctx.groups = group_duplicates(ctx.functions)

        ctx.call_graph = build_call_graph(ctx.files)
        ctx.usage_map = build_usage_map(ctx.call_graph)

        return ctx
