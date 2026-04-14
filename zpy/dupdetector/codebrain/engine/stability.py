import json
from pathlib import Path

STATE_FILE = Path("evolve/refactor_state.json")


def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception:
            return {}
    return {}


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def update_stability(groups):
    """
    Tracks stability of duplicate groups across runs
    """
    state = load_state()

    for key, funcs in groups.items():
        if len(funcs) < 2:
            continue

        state[key] = state.get(key, 0) + 1

    save_state(state)
    return state


def get_stable_groups(groups, state, min_runs=3):
    stable = []

    for key, funcs in groups.items():
        if len(funcs) < 2:
            continue

        if state.get(key, 0) >= min_runs:
            stable.append(funcs)

    return stable
