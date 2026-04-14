from codebrain.engine.stability import update_stability, get_stable_groups
from codebrain.call_graph import filter_safe_groups


class PlanningPhase:
    """
    Phase 2 — Decision Layer
    """

    def run(self, ctx):

        print("\n🧠 PLANNING PHASE\n")

        # STEP 1 — stability tracking
        ctx.stability_state = update_stability(ctx.groups)

        ctx.stable_groups = get_stable_groups(
            ctx.groups,
            ctx.stability_state,
            min_runs=3
        )

        if not ctx.stable_groups:
            print("ℹ️ No stable groups yet")
            ctx.safe_groups = []
            return ctx

        print(f"✔ Stable groups: {len(ctx.stable_groups)}")

        # STEP 2 — prepare for filtering
        confident = [
            (f"group_{i}", group, 1.0)
            for i, group in enumerate(ctx.stable_groups)
        ]

        # STEP 3 — safety filtering
        ctx.safe_groups = filter_safe_groups(
            confident,
            ctx.usage_map
        )

        if not ctx.safe_groups:
            print("⚠️ No safe groups after filtering")
        else:
            print(f"✔ Safe groups: {len(ctx.safe_groups)}")

        return ctx
