import subprocess


def run_tests(project_path):
    try:
        result = subprocess.run(
            ["pytest", "-q"],
            cwd=project_path,
            capture_output=True,
            text=True
        )

        success = result.returncode == 0

        return success, {
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    except Exception as e:
        return False, {"error": str(e)}
