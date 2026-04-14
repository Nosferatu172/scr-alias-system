from datetime import datetime
from pathlib import Path


def generate_summary(stable_groups):
    """
    Builds a human-readable PR-style summary
    """

    summary_lines = []

    summary_lines.append("## 🤖 Auto Refactor Summary\n")
    summary_lines.append(f"**Timestamp:** {datetime.utcnow().isoformat()}\n")

    for group in stable_groups:
        canonical = group[0]
        canonical_name = canonical["name"]

        summary_lines.append(f"\n### 🔁 Canonical Function: `{canonical_name}`")
        summary_lines.append(f"Source: {canonical['file']}\n")

        for func in group[1:]:
            summary_lines.append(
                f"- Replaced `{func['name']}` in `{func['file']}`"
            )

    summary_lines.append("\n---\n")
    summary_lines.append("### 🧠 Reasoning")
    summary_lines.append(
        "Duplicate functions detected consistently across runs. "
        "System selected a canonical implementation and replaced duplicates safely."
    )

    return "\n".join(summary_lines)


def save_summary(workspace_path, content):
    """
    Writes summary file into workspace
    """

    path = Path(workspace_path) / "refactor_summary.md"

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    return path
