HELP_TEXT = """
🧠 CODEBRAIN — Autonomous AI Refactor System
===========================================

DESCRIPTION
-----------
CodeBrain is an AI-powered system that:
- detects duplicate and similar functions
- merges and improves code using AST + GPT
- updates dependencies across files
- validates changes with tests
- safely commits changes using git
- optionally creates GitHub pull requests

It is designed to behave like a cautious autonomous developer.

------------------------------------------------------------

USAGE
-----

Basic run:
  python main.py /path/to/project

Autonomous mode (continuous analysis):
  python main.py /path/to/project --auto

Custom interval (seconds):
  python main.py /path/to/project --auto --interval 60

------------------------------------------------------------

MODES
-----

Default Mode:
  Runs analysis + safe refactor once

Autonomous Mode (--auto):
  Runs continuously in a loop
  Learns stability over time
  Applies refactors only when confident

------------------------------------------------------------

FEATURES
--------

✔ Duplicate detection (AST-based)
✔ Semantic clustering (AI embeddings)
✔ Risk-aware filtering (call graph)
✔ Safe refactoring with rollback
✔ Test validation before/after changes
✔ Git snapshots + branch creation
✔ PR-style summaries
✔ Optional GitHub PR creation
✔ GPT-powered code improvement

------------------------------------------------------------

ENVIRONMENT SETUP
-----------------

Optional but recommended:

GitHub PR support:
  export GITHUB_TOKEN=your_token

GPT code improvement:
  export OPENAI_API_KEY=your_key

------------------------------------------------------------

SAFETY MODEL
------------

CodeBrain will ONLY refactor when:
- duplicates are stable across runs
- confidence threshold is met
- functions are not high-risk (usage-based)
- tests pass before AND after refactor

If anything fails:
✔ changes are rolled back automatically

------------------------------------------------------------

OUTPUT
------

refactor_workspace/
  ├── functions.json
  ├── duplicate_groups.json
  ├── ai_clusters.json
  ├── dependency_graph.json
  ├── call_graph.json
  ├── refactor_summary.md
  └── PR_DESCRIPTION.md

------------------------------------------------------------

WARNINGS
--------

⚠ This tool can modify code.
⚠ Always test on a safe project first.
⚠ Use git (enabled automatically) for rollback safety.

------------------------------------------------------------

EXAMPLES
--------

Run once:
  python main.py ./my_project

Run continuously:
  python main.py ./my_project --auto

Fast testing loop:
  python main.py ./my_project --auto --interval 30

------------------------------------------------------------

AUTHOR MODE
-----------

This system behaves like a junior-to-mid-level AI developer.
Trust it gradually and review its PRs like you would a human teammate.

============================================================
"""
