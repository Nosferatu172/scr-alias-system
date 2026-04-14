from codebrain.git_layer import create_snapshot, rollback
from codebrain.test_runner import run_tests
from codebrain.execution.refactor_engine import replace_function_ast


class ExecutionPhase:

    def run(self, ctx):

        if not ctx.safe_groups:
            print("ℹ️ Nothing to refactor")
            return ctx

        print("\n🛠 EXECUTION PHASE (SAFE MODE)\n")

        # --------------------------------------------------
        # PRE-SNAPSHOT
        # --------------------------------------------------
        create_snapshot(ctx.path, "Pre-refactor snapshot")

        ctx.applied_groups = []

        # --------------------------------------------------
        # APPLY CHANGES
        # --------------------------------------------------
        for _, group, _ in ctx.safe_groups:

            canonical = group[0]

            try:
                with open(canonical["file"], "r", encoding="utf-8") as f:
                    canonical_code = f.read()
            except Exception:
                continue

            print(f"🤖 Refactoring group: {canonical['name']}")

            for func in group[1:]:

                success = replace_function_ast(
                    func["file"],
                    func["name"],
                    canonical_code
                )

                if success:
                    print(f"✔ Updated: {func['file']}")
                    ctx.applied_groups.append(func)
                else:
                    print(f"❌ Failed: {func['file']}")

        # --------------------------------------------------
        # VALIDATION
        # --------------------------------------------------
        print("\n🧪 Running tests after refactor...")

        ok, _ = run_tests(ctx.path)

        # --------------------------------------------------
        # AUTO-ROLLBACK
        # --------------------------------------------------
        if not ok:
            print("\n❌ TESTS FAILED — ROLLING BACK")

            rollback(ctx.path)

            print("↩️ System restored to pre-refactor state")

            ctx.applied_groups = []
            return ctx

        # --------------------------------------------------
        # SUCCESS
        # --------------------------------------------------
        create_snapshot(ctx.path, "Post-refactor snapshot")

        print("\n✅ EXECUTION COMPLETE (SAFE)\n")

        return ctx
