"""Validate a v1 benchmark manifest against the protocol constraints.

Usable as a library (``validate_manifest(manifest: dict) -> list[str]``) or as a
CLI (``python3 -m benchmarks.validate_manifest <manifest.json>``). Exits 0 on a
valid manifest, 1 on validation findings, 2 on a fault (file unreadable or
unparseable).
"""

import json
import re
import sys

from benchmarks.manifest import (
    DATASET_NAME,
    DATASET_REVISION,
    DATASET_SPLIT,
    EVALUATOR_NAME,
    EVALUATOR_REVISION,
    PROTOCOL_VERSION,
    REQUIRED_EVIDENCE_FIELDS,
    REQUIRED_TASK_FIELDS,
    SCHEMA_VERSION,
    SUPPORTED_LICENSES,
    compute_manifest_digest,
)

SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
GITHUB_URL_RE = re.compile(r"^https://github\.com/[^/]+/[^/]+/(issues|pull)/[0-9]+$")


def _check_presence(
    manifest: dict, key: str, findings: list[str], context: str = ""
) -> object | None:
    """Return the value for ``key`` if present, appending a finding otherwise."""
    if key not in manifest:
        label = f"{context}.{key}" if context else key
        findings.append(f"missing required field: {label}")
        return None
    return manifest[key]


def validate_manifest(manifest: dict) -> list[str]:
    """Validate a manifest dict against the v1 protocol constraints.

    Returns a list of finding strings; an empty list means the manifest is valid.
    Each check verifies field presence before testing its value, so a missing
    field produces a named finding rather than a KeyError.
    """
    findings: list[str] = []

    # Top-level scalar fields.
    if "protocol_version" not in manifest:
        findings.append("missing required field: protocol_version")
    elif manifest["protocol_version"] != PROTOCOL_VERSION:
        findings.append(
            f"protocol_version: expected {PROTOCOL_VERSION!r}, got {manifest['protocol_version']!r}"
        )

    if "schema_version" not in manifest:
        findings.append("missing required field: schema_version")
    elif manifest["schema_version"] != SCHEMA_VERSION:
        findings.append(
            f"schema_version: expected {SCHEMA_VERSION!r}, got {manifest['schema_version']!r}"
        )

    # Dataset block.
    dataset = _check_presence(manifest, "dataset", findings)
    if isinstance(dataset, dict):
        for field, expected in [
            ("name", DATASET_NAME),
            ("split", DATASET_SPLIT),
            ("revision", DATASET_REVISION),
        ]:
            if field not in dataset:
                findings.append(f"missing required field: dataset.{field}")
            elif dataset[field] != expected:
                findings.append(f"dataset.{field}: expected {expected!r}, got {dataset[field]!r}")

    # Evaluator block.
    evaluator = _check_presence(manifest, "evaluator", findings)
    if isinstance(evaluator, dict):
        for field, expected in [
            ("name", EVALUATOR_NAME),
            ("revision", EVALUATOR_REVISION),
        ]:
            if field not in evaluator:
                findings.append(f"missing required field: evaluator.{field}")
            elif evaluator[field] != expected:
                findings.append(
                    f"evaluator.{field}: expected {expected!r}, got {evaluator[field]!r}"
                )

    # Groups block.
    groups = _check_presence(manifest, "groups", findings)
    if not isinstance(groups, list):
        findings.append("field groups must be a list")
        groups = []
    if len(groups) != 2:
        findings.append(f"group count: expected 2, got {len(groups)}")

    repositories: list[str] = []
    for i, group in enumerate(groups):
        if not isinstance(group, dict):
            findings.append(f"group {i}: not an object")
            continue
        repo = _check_presence(group, "repository", findings, context=f"group {i}")
        if isinstance(repo, str):
            repositories.append(repo)

        common_rev = _check_presence(group, "common_revision", findings, context=f"group {i}")
        if isinstance(common_rev, str) and not SHA40_RE.match(common_rev):
            findings.append(f"group {i}: common_revision is not a 40-hex SHA: {common_rev!r}")

        tasks = _check_presence(group, "tasks", findings, context=f"group {i}")
        if not isinstance(tasks, list):
            findings.append(f"group {i}: tasks is not a list")
            tasks = []
        if len(tasks) != 3:
            findings.append(f"group {i}: task count: expected 3, got {len(tasks)}")

        for j, task in enumerate(tasks):
            if not isinstance(task, dict):
                findings.append(f"group {i} task {j}: not an object")
                continue
            for field in REQUIRED_TASK_FIELDS:
                if field not in task:
                    findings.append(f"group {i} task {j}: missing required field: {field}")

            if "issue_url" in task and not GITHUB_URL_RE.match(str(task["issue_url"])):
                findings.append(
                    f"group {i} task {j}: issue_url is not a GitHub URL: {task['issue_url']!r}"
                )

            if "license" in task and task["license"] not in SUPPORTED_LICENSES:
                findings.append(f"group {i} task {j}: unsupported license: {task['license']!r}")

            if "original_base_commit" in task and not SHA40_RE.match(
                str(task["original_base_commit"])
            ):
                findings.append(
                    f"group {i} task {j}: original_base_commit is not a 40-hex SHA: "
                    f"{task['original_base_commit']!r}"
                )

            if "fail_to_pass" in task:
                ftp = task["fail_to_pass"]
                if not isinstance(ftp, list) or len(ftp) == 0:
                    findings.append(f"group {i} task {j}: fail_to_pass must be a non-empty list")

            if "test_patch" in task:
                tp = task["test_patch"]
                if not isinstance(tp, str) or len(tp) == 0:
                    findings.append(f"group {i} task {j}: test_patch must be a non-empty string")

            if "adaptation_evidence" in task:
                evidence = task["adaptation_evidence"]
                if not isinstance(evidence, dict):
                    findings.append(f"group {i} task {j}: adaptation_evidence is not an object")
                else:
                    for ef in REQUIRED_EVIDENCE_FIELDS:
                        if ef not in evidence:
                            findings.append(
                                f"group {i} task {j}: adaptation_evidence missing field: {ef}"
                            )

    if len(set(repositories)) < len(repositories):
        findings.append("groups must have different repository values")

    # Digest.
    selection = _check_presence(manifest, "selection", findings)
    if isinstance(selection, dict):
        if "manifest_digest" not in selection:
            findings.append("missing required field: selection.manifest_digest")
        else:
            expected = compute_manifest_digest(manifest)
            if selection["manifest_digest"] != expected:
                findings.append(
                    f"manifest_digest: expected {expected!r}, got {selection['manifest_digest']!r}"
                )

    return findings


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <manifest.json>", file=sys.stderr)
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

    if not isinstance(manifest, dict):
        print(f"{argv[1]}: manifest is not a JSON object", file=sys.stderr)
        return 2

    findings = validate_manifest(manifest)
    if findings:
        for finding in findings:
            print(f"  {finding}")
        return 1
    print(f"{argv[1]}: manifest is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
