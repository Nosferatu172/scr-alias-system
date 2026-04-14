from datetime import datetime


def generate_branch_name():
    ts = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    return f"auto/refactor-{ts}"


def generate_pr_text(summary_file):
    return f"""
# 🤖 Automated Refactor PR

## Summary
This PR was generated automatically by the CodeBrain system.

## Changes
- Refactored duplicate functions
- Applied AST-level merges
- Updated cross-file dependencies

## Details
See: {summary_file}

## Safety
- Pre/post tests executed
- Rollback available via git

---
Generated automatically 🚀
"""
