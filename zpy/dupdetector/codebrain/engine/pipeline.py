from codebrain.engine.analysis import AnalysisPhase
from codebrain.engine.planning import PlanningPhase
from codebrain.engine.execution import ExecutionPhase


class Pipeline:

    def __init__(self):
        self.analysis = AnalysisPhase()
        self.planning = PlanningPhase()
        self.execution = ExecutionPhase()

    def run(self, ctx):

        print("\n🚀 CODEBRAIN PIPELINE\n")

        ctx = self.analysis.run(ctx)
        ctx = self.planning.run(ctx)
        ctx = self.execution.run(ctx)

        print("\n✅ PIPELINE COMPLETE\n")

        return ctx
