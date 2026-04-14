# AUTO-GENERATED GUARD

_ACTIVE = "engine.runner"

def assert_entrypoint(name: str):
    global _ACTIVE
    if _ACTIVE != name:
        raise RuntimeError(f"Entrypoint conflict: {name} vs {_ACTIVE}")
