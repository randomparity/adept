"""Deterministic selection of two repository-disjoint task groups.

Reads a canonical JSONL dataset (one instance per line) and produces a manifest
and candidate ledger following the v1 protocol's deterministic selection rules:

1. Enumerate by ascending instance_id.
2. Exclude per objective rules (license, author identity).
3. For each repository in lexical order, enumerate 3-task combinations.
4. Test candidate common revisions in lexical order.
5. Select the first two qualifying combinations from different repositories.

The ``validate_fn`` parameter is the seam between selection and per-task
validation: in tests it is a stub; in production it is a subprocess call to
``validate_task.py``.
"""

import json
import sys
from itertools import combinations
from pathlib import Path

from benchmarks.manifest import (
    DATASET_NAME,
    DATASET_REVISION,
    DATASET_SPLIT,
    EVALUATOR_NAME,
    EVALUATOR_REVISION,
    PROTOCOL_VERSION,
    SCHEMA_VERSION,
    SUPPORTED_LICENSES,
    compute_manifest_digest,
)


class SelectionError(Exception):
    """Raised when selection cannot produce two qualifying groups."""


def _parse_jsonl(path: str) -> list[dict]:
    """Parse a JSONL file, skipping malformed rows."""
    instances = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(row, dict):
                continue
            if "instance_id" not in row:
                continue
            instances.append(row)
    return instances


def _check_eligibility(instance: dict) -> tuple[bool, str | None]:
    """Return (eligible, exclusion_rule) for an instance."""
    license_val = instance.get("license")
    if license_val is None:
        return False, "license-missing"
    if license_val not in SUPPORTED_LICENSES:
        return False, "license-not-supported"
    return True, None


def _build_manifest(groups: list[dict]) -> dict:
    """Build a manifest dict from selected groups."""
    manifest = {
        "protocol_version": PROTOCOL_VERSION,
        "schema_version": SCHEMA_VERSION,
        "dataset": {
            "name": DATASET_NAME,
            "split": DATASET_SPLIT,
            "revision": DATASET_REVISION,
        },
        "evaluator": {
            "name": EVALUATOR_NAME,
            "revision": EVALUATOR_REVISION,
        },
        "groups": groups,
        "selection": {
            "candidate_ledger": "ledger.json",
            "manifest_digest": "",
        },
    }
    manifest["selection"]["manifest_digest"] = compute_manifest_digest(manifest)
    return manifest


def select_tasks(
    dataset_jsonl: str,
    validate_fn=None,
) -> tuple[dict, dict]:
    """Select two repository-disjoint task groups from a dataset JSONL file.

    Returns ``(manifest, ledger)``. ``validate_fn`` is called per
    ``(instance_dict, candidate_revision)`` and must return an
    ``adaptation_evidence`` dict or raise ``SelectionError``. If ``None``, a
    subprocess call to ``validate_task.py`` is used.
    """
    if validate_fn is None:
        validate_fn = _default_validate_fn

    instances = _parse_jsonl(dataset_jsonl)
    instances.sort(key=lambda inst: inst["instance_id"])

    # Build the candidate ledger with eligibility filtering.
    ledger_instances = []
    eligible: dict[str, list[dict]] = {}

    for inst in instances:
        eligible_flag, exclusion_rule = _check_eligibility(inst)
        repo = inst.get("repo", "unknown/unknown")
        entry = {
            "instance_id": inst["instance_id"],
            "repository": repo,
            "status": "eligible" if eligible_flag else "excluded",
            "exclusion_rule": exclusion_rule,
            "evidence": f"license field: {inst.get('license', 'missing')}",
        }
        ledger_instances.append(entry)
        if eligible_flag:
            eligible.setdefault(repo, []).append(inst)

    # Process repositories in lexical order.
    ledger_combinations = []
    selected_groups: list[dict] = []
    selected_repos: set[str] = set()

    for repo in sorted(eligible.keys()):
        if len(selected_groups) >= 2:
            break
        if repo in selected_repos:
            continue

        repo_instances = eligible[repo]
        if len(repo_instances) < 3:
            continue

        # Enumerate 3-task combinations: sort IDs within each combo, then sort
        # combos by the (first, second, third) tuple.
        combos = []
        for combo in combinations(repo_instances, 3):
            sorted_combo = sorted(combo, key=lambda inst: inst["instance_id"])
            ids = tuple(inst["instance_id"] for inst in sorted_combo)
            combos.append((ids, sorted_combo))
        combos.sort(key=lambda c: c[0])

        for ids, combo_instances in combos:
            # Candidate revisions: distinct base commits in lexical order.
            base_commits = sorted(set(inst["base_commit"] for inst in combo_instances))

            combo_entry = {
                "repository": repo,
                "instance_ids": list(ids),
                "candidate_revisions_tested": base_commits,
                "qualifying_revision": None,
                "status": "rejected",
            }

            for candidate_rev in base_commits:
                try:
                    evidences = []
                    for inst in combo_instances:
                        evidence = validate_fn(inst, candidate_rev)
                        evidences.append(evidence)
                except SelectionError:
                    continue

                # All three tasks validated at this revision.
                combo_entry["qualifying_revision"] = candidate_rev
                combo_entry["status"] = "selected"
                ledger_combinations.append(combo_entry)

                # Build the group.
                group = {
                    "group_id": chr(ord("A") + len(selected_groups)),
                    "repository": repo,
                    "common_revision": candidate_rev,
                    "tasks": [
                        {
                            "instance_id": inst["instance_id"],
                            "issue_url": inst.get("issue_url"),
                            "license": inst.get("license"),
                            "original_base_commit": inst["base_commit"],
                            "fail_to_pass": inst.get("FAIL_TO_PASS", []),
                            "pass_to_pass": inst.get("PASS_TO_PASS", []),
                            "test_patch": inst.get("test_patch", ""),
                            "adaptation_evidence": evidence,
                            "materialized_issue_number": None,
                        }
                        for inst, evidence in zip(combo_instances, evidences, strict=True)
                    ],
                }
                selected_groups.append(group)
                selected_repos.add(repo)
                break

            if combo_entry["status"] != "selected":
                ledger_combinations.append(combo_entry)

            if len(selected_groups) >= 2:
                break

    if len(selected_groups) < 2:
        raise SelectionError(
            f"fewer than 2 qualifying groups found ({len(selected_groups)}); "
            "discretionary replacement is forbidden"
        )

    manifest = _build_manifest(selected_groups)
    ledger = {
        "dataset_revision": DATASET_REVISION,
        "instances": ledger_instances,
        "combinations": ledger_combinations,
    }
    return manifest, ledger


def _default_validate_fn(instance: dict, revision: str) -> dict:
    """Production validate_fn: subprocess call to validate_task.py."""
    import subprocess

    with __import__("tempfile").NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(instance, f)
        instance_path = f.name

    try:
        import tempfile

        work_dir = tempfile.mkdtemp()
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "benchmarks.validate_task",
                instance_path,
                revision,
                work_dir,
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise SelectionError(f"validate_task.py exited {result.returncode}: {result.stderr}")
        return json.loads(result.stdout)
    finally:
        Path(instance_path).unlink(missing_ok=True)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} <dataset.jsonl> <output-dir>", file=sys.stderr)
        return 2
    try:
        manifest, ledger = select_tasks(argv[1])
    except SelectionError as exc:
        print(f"selection error: {exc}", file=sys.stderr)
        return 1

    output_dir = Path(argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)
    with open(output_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    with open(output_dir / "ledger.json", "w") as f:
        json.dump(ledger, f, indent=2)
    print(f"manifest and ledger written to {output_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
