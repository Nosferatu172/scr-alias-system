# STRICT ENTRYPOINT ENFORCEMENT
# This file prevents multiple orchestration systems from coexisting.

_ACTIVE_ENTRYPOINT = "main"

def assert_single_entrypoint(name: str):
    global _ACTIVE_ENTRYPOINT

    if _ACTIVE_ENTRYPOINT != name:
        raise RuntimeError(
            f"❌ Entrypoint conflict detected: {name} vs {_ACTIVE_ENTRYPOINT}"
        )

    _ACTIVE_ENTRYPOINT = name
