import requests
import os


def create_pull_request(repo, branch, base="main", title="Auto Refactor", body=""):
    """
    Creates a GitHub PR using API
    """

    token = os.getenv("GITHUB_TOKEN")
    if not token:
        raise Exception("Missing GITHUB_TOKEN")

    url = f"https://api.github.com/repos/{repo}/pulls"

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json"
    }

    data = {
        "title": title,
        "head": branch,
        "base": base,
        "body": body
    }

    response = requests.post(url, json=data, headers=headers)

    if response.status_code != 201:
        raise Exception(f"PR creation failed: {response.text}")

    return response.json()["html_url"]
