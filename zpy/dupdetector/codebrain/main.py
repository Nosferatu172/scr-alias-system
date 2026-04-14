#!/usr/bin/env python3

import argparse
from codebrain.engine.runner import run_pipeline, run_auto
from codebrain.help_text import HELP_TEXT


def main():
    parser = argparse.ArgumentParser(add_help=False)

    parser.add_argument("path", nargs="?", help="Project path")
    parser.add_argument("--auto", action="store_true")
    parser.add_argument("--interval", type=int, default=300)
    parser.add_argument("--help", action="store_true")

    args = parser.parse_args()

    if args.help or not args.path:
        print(HELP_TEXT)
        return

    # 🔒 SINGLE ENTRYPOINT DECISION
    if args.auto:
        run_auto(args.path, args.interval)
    else:
        run_pipeline(args.path)


if __name__ == "__main__":
    main()
