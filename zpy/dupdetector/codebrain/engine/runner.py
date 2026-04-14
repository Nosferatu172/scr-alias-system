from codebrain.engine.pipeline import Pipeline
from codebrain.engine.context import Context
import time


def run_pipeline(path):
    ctx = Context(path)
    return Pipeline().run(ctx)


def run_auto(path, interval=300):
    print(f"\n🔁 Auto mode (interval={interval}s)\n")

    iteration = 1

    try:
        while True:
            print(f"\n🔄 Iteration {iteration}")
            run_pipeline(path)
            time.sleep(interval)
            iteration += 1

    except KeyboardInterrupt:
        print("\n🛑 Stopped\n")
