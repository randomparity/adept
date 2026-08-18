"""Materialize benchmark-owned GitHub issues from a manifest.

Creates issues #1/#2/#3 per group in lexical instance_id order with exact
labels. Supports dry-run mode. Computes a topology digest over the materialized
state.

CLI: ``python3 -m benchmarks.materialize_issues <manifest.json> <repo>``
Exit 0 = success, 1 = finding, 2 = fault.
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

from benchmarks.manifest import canonical_json_bytes

EXACT_LABELS = [
    "type:bug",
    "priority:P2",
    "status:ready",
    "risk:night-watch",
    "effort:M",
]


class MaterializationError(Exception):
    """Raised when materialization fails."""

    def __init__(self, message: str, is_fault: bool = False) -> None:
        super().__init__(message)
        self.is_fault = is_fault


def _run(cmd: list[str], runner=None) -> subprocess.CompletedProcess:
    if runner is not None:
        return runner(cmd)
    return subprocess.run(cmd, capture_output=True, text=True)


def _compute_topology_digest(groups: list[dict]) -> str:
    """SHA-256 over canonical JSON of the materialized topology state."""
    topology = []
    for group in groups:
        for task in sorted(group["tasks"], key=lambda t: t["instance_id"]):
            topology.append(
                {
                    "issue_number": task["materialized_issue_number"],
                    "labels": sorted(EXACT_LABELS),
                    "has_assignee": False,
                    "has_milestone": False,
                    "has_project": False,
                    "has_comments": False,
                    "has_reactions": False,
                    "has_linked_pr": False,
                    "has_sub_issues": False,
                }
            )
    return hashlib.sha256(canonical_json_bytes({"topology": topology})).hexdigest()


def materialize_issues(
    manifest: dict,
    repo: str,
    dry_run: bool = False,
    runner=None,
) -> dict:
    """Materialize benchmark-owned issues from a manifest.

    Returns an updated manifest with ``materialized_issue_number`` values and
    a topology digest. Raises ``MaterializationError`` on failure.
    """
    result = json.loads(json.dumps(manifest))  # deep copy

    if not dry_run:
        # Pre-check gh authentication.
        auth_res = _run(["gh", "auth", "status"], runner=runner)
        if auth_res.returncode != 0:
            raise MaterializationError(
                f"gh not authenticated: {auth_res.stderr.strip()}",
                is_fault=True,
            )
        # Pre-check repo existence.
        repo_res = _run(["gh", "repo", "view", repo], runner=runner)
        if repo_res.returncode != 0:
            raise MaterializationError(
                f"benchmark-owned repo does not exist: {repo}",
                is_fault=True,
            )
        # Idempotency: check for existing issues.
        list_res = _run(
            ["gh", "issue", "list", "--repo", repo, "--state", "all", "--limit", "100"],
            runner=runner,
        )
        existing_titles: set[str] = set()
        if list_res.returncode == 0:
            for line in (list_res.stdout or "").strip().splitlines():
                existing_titles.add(line.split("\t")[-1] if "\t" in line else "")

    for group in result["groups"]:
        sorted_tasks = sorted(group["tasks"], key=lambda t: t["instance_id"])
        for task in sorted_tasks:
            issue_body = task.get("problem_statement", "Benchmark task issue.")

            if dry_run:
                print(
                    f"gh issue create --repo {repo} "
                    f"--title '{task['instance_id']}' "
                    f"--body '{issue_body[:50]}...' "
                    f"--label {','.join(EXACT_LABELS)}"
                )
                task["materialized_issue_number"] = None
                continue

            # Idempotency: skip if issue already exists.
            if task["instance_id"] in existing_titles:
                # Find the existing issue number from the list output.
                for line in (list_res.stdout or "").strip().splitlines():
                    if task["instance_id"] in line and "\t" in line:
                        task["materialized_issue_number"] = int(line.split("\t")[0])
                        break
                continue

            cmd = [
                "gh",
                "issue",
                "create",
                "--repo",
                repo,
                "--title",
                task["instance_id"],
                "--body",
                issue_body,
            ]
            for label in EXACT_LABELS:
                cmd.extend(["--label", label])

            res = _run(cmd, runner=runner)
            if res.returncode != 0:
                raise MaterializationError(
                    f"issue creation failed for {task['instance_id']}: {res.stderr.strip()}",
                    is_fault=True,
                )
            try:
                task["materialized_issue_number"] = int(res.stdout.strip())
            except ValueError:
                raise MaterializationError(
                    f"unexpected gh output for {task['instance_id']}: {res.stdout.strip()}",
                    is_fault=True,
                ) from None

    if not dry_run:
        result.setdefault("selection", {})["topology_digest"] = _compute_topology_digest(
            result["groups"]
        )

    return result


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(f"usage: {argv[0]} <manifest.json> <repo> [--dry-run]", file=sys.stderr)
        return 2
    try:
        with open(argv[1]) as f:
            manifest = json.load(f)
    except OSError as exc:
        print(f"cannot read {argv[1]}: {exc}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"cannot parse {argv[1]}: {exc}", file=sys.stderr)
        return 2

    dry_run = "--dry-run" in argv
    try:
        result = materialize_issues(manifest, argv[2], dry_run=dry_run)
    except MaterializationError as exc:
        print(f"materialization error: {exc}", file=sys.stderr)
        return 2 if exc.is_fault else 1

    output_path = Path(argv[1])
    with open(output_path, "w") as f:
        json.dump(result, f, indent=2)
    print(f"manifest updated: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
