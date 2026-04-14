import json
from datetime import datetime
from pathlib import Path


LOG_FILE = Path("evolve/evolution_log.json")


# --------------------------------------------------
# LOG SYSTEM BEHAVIOR
# --------------------------------------------------

def log_event(event_type: str, data: dict):
    """
    Records what the system observed during execution
    """

    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "event": event_type,
        "data": data
    }

    logs = []

    if LOG_FILE.exists():
        try:
            with open(LOG_FILE, "r") as f:
                logs = json.load(f)
        except Exception:
            logs = []

    logs.append(entry)

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

    with open(LOG_FILE, "w") as f:
        json.dump(logs, f, indent=2)


# --------------------------------------------------
# SELF-IMPROVEMENT SUGGESTIONS
# --------------------------------------------------

def analyze_weaknesses(summary):
    """
    Looks at pipeline output and finds weaknesses
    """

    issues = []

    if summary.get("duplicate_groups", 0) > 50:
        issues.append("High duplication → improve merge heuristics")

    if summary.get("near_duplicates", 0) > 100:
        issues.append("Too many near duplicates → refine similarity threshold")

    if summary.get("functions", 0) < 10:
        issues.append("Low function count → expand parser coverage")

    return issues


def propose_improvements(issues):
    """
    Converts issues into actionable improvements
    """

    improvements = []

    for issue in issues:

        if "duplication" in issue:
            improvements.append(
                "Enhance merger.py to auto-select canonical functions more accurately"
            )

        if "near duplicates" in issue:
            improvements.append(
                "Tune similarity threshold or add semantic weighting"
            )

        if "parser" in issue:
            improvements.append(
                "Extend analyzer.py to support more constructs"
            )

    return improvements
