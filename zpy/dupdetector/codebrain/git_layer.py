import subprocess


def run_git_command(path, args):
    return subprocess.run(
        ["git"] + args,
        cwd=path,
        capture_output=True,
        text=True
    )


def create_snapshot(path, message):
    run_git_command(path, ["add", "."])
    run_git_command(path, ["commit", "-m", message])


def rollback(path):
    print("⚠️ Rolling back last change...")
    run_git_command(path, ["reset", "--hard", "HEAD~1"])
