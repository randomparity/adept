# Benchmark manifest and selection mechanism — implementation plan

Issue: #119 · Branch: `feat/benchmark-manifest-119` · Base: `main`

## Goal

Build the Python manifest schema, validator, deterministic selection, per-task
validation, issue materialization, and dataset fetch mechanisms that encode the
v1 benchmark protocol. Wire Python tests and linting into the guardrail suite.

## Architecture

Six Python modules under `benchmarks/`, each with a unittest suite. Selection
reads a JSONL dataset file (produced by the standalone fetch script), filters
and enumerates combinations, calls `validate_task.py` per candidate, and emits a
manifest + ledger. Materialization reads the manifest and creates benchmark-owned
GitHub issues. The validator checks any manifest against protocol constraints.

## Tech stack

Python 3.13+ (stdlib for all testable code). `ruff` for lint + format. `unittest`
for tests. `huggingface_hub` + `pyarrow` lazy-imported in `fetch_dataset.py`
only.

## Global constraints

- Repo is public. No host paths, secrets, or auth in committed code.
- Conventional commits, imperative mood, ≤72-char subject.
- Python line length 100. Absolute imports. Google-style docstrings on public APIs.
- `ruff.toml` at repo root configures lint + format for `benchmarks/`.
- Tests use `tempfile.TemporaryDirectory`, no network, no Docker.
- Every script exits with a clear exit code: 0 success, 1 finding, 2 fault.
- `just verify` must pass green before every commit.
- Guardrail commands: `just verify` (full suite), `just commit-check` (per-commit).
- `BASE_BRANCH` = `main`.

---

## Task 1: ruff config + Justfile + CI wiring

Sets up the Python toolchain integration so subsequent tasks can lint and test
as they go.

### Files

- Create `ruff.toml` at repo root.
- Modify `Justfile`: add `py-test` and `py-lint` recipes; add `py-lint` to
  `commit-check`; add `py-test` to `verify`.
- Modify `.github/workflows/verify.yml`: add `ruff` to the `brew install` line.
- Create `benchmarks/__init__.py` (empty).

### ruff.toml

```toml
target-version = "py312"
line-length = 100

[lint]
select = ["E", "F", "W", "I", "UP", "B"]
```

### Justfile additions

Add after the `test` recipe:

```makefile
py-test:
  #!/usr/bin/env bash
  set -euo pipefail
  python3 -m unittest discover -s benchmarks -p 'test_*.py' -v
```

Add after `format-check`:

```makefile
py-lint:
  #!/usr/bin/env bash
  set -euo pipefail
  ruff check benchmarks/
  ruff format --check benchmarks/
```

Change `commit-check`:

```makefile
commit-check: lint format-check public-safety py-lint
```

Change `verify`:

```makefile
verify: records commit-check shape-check ripgrep-config-check plugin-check test py-test py-lint actions-check
  prek run --all-files --stage pre-commit --dry-run
```

### CI workflow change

In `.github/workflows/verify.yml`, change the brew install line to:

```bash
brew install --quiet just shfmt actionlint zizmor prek ripgrep shellcheck jq ruff
```

### Verification

```bash
just py-lint    # expect: "All checks passed!" + no format diffs
just py-test    # expect: "Ran 0 tests" or "No tests found" — __init__.py has none
just verify     # expect: full suite green (py-test finds no tests yet — OK)
```

### Acceptance

- `ruff.toml` exists and `ruff check benchmarks/` passes on an empty package.
- `just py-lint` and `just py-test` recipes exist and run.
- `just verify` is green.

---

## Task 2: Manifest schema module + digest

### Files

- Create `benchmarks/manifest.py`.
- Create `benchmarks/test_manifest.py`.

### manifest.py

Constants for the pinned protocol values and the manifest schema:

```python
"""Manifest schema constants and digest computation for the v1 benchmark protocol."""

import hashlib
import json

PROTOCOL_VERSION = "adept-workflow-v1"
SCHEMA_VERSION = "1.0.0"

DATASET_NAME = "SWE-bench/SWE-bench_Verified"
DATASET_SPLIT = "test"
DATASET_REVISION = "03e151cf5560b1af6a4363c6a9d766deaaea6b56"

EVALUATOR_NAME = "SWE-bench/SWE-bench"
EVALUATOR_REVISION = "128cbd1a5759694874e6bd56624cb2fd6fb079e2"

SUPPORTED_LICENSES = frozenset({
    "MIT", "BSD-2-Clause", "BSD-3-Clause", "Apache-2.0",
    "ISC", "Python-2.0", "PSF-2.0",
})

REQUIRED_TASK_FIELDS = (
    "instance_id", "issue_url", "license", "original_base_commit",
    "fail_to_pass", "pass_to_pass", "test_patch", "adaptation_evidence",
)

REQUIRED_EVIDENCE_FIELDS = (
    "gold_patch_applied_cleanly", "pre_patch_failures",
    "post_patch_all_pass", "evaluator_image",
)


def canonical_json_bytes(data: dict) -> bytes:
    """Serialize to RFC 8785 canonical JSON (sorted keys, no whitespace)."""
    return json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")


def compute_manifest_digest(manifest: dict) -> str:
    """SHA-256 of canonical JSON with the digest field set to empty string."""
    temp = dict(manifest)
    selection = dict(temp.get("selection", {}))
    selection["manifest_digest"] = ""
    temp["selection"] = selection
    return hashlib.sha256(canonical_json_bytes(temp)).hexdigest()
```

### test_manifest.py

Tests:

1. `test_compute_digest_is_deterministic` — same dict → same digest.
2. `test_compute_digest_ignores_digest_field` — digest is computed with the
   field blanked, so two manifests identical except for the digest value produce
   the same digest.
3. `test_canonical_json_sorts_keys` — canonical bytes have sorted keys.
4. `test_supported_licenses_contains_protocol_set` — the 7 allowed licenses.

### Verification

```bash
just py-test    # expect: 4 tests pass
just py-lint    # expect: clean
```

### Acceptance

- `manifest.py` exports the constants and two functions.
- Digest computation is deterministic and ignores the digest field.

---

## Task 3: Manifest validator

### Files

- Create `benchmarks/validate_manifest.py`.
- Create `benchmarks/test_validate_manifest.py`.

### validate_manifest.py

A `validate_manifest(manifest: dict) -> list[str]` function returning a list of
finding strings (empty = valid), plus a CLI entry point that reads a JSON file
and exits 0/1/2.

Validation checks (each produces a named finding on failure):

1. `protocol_version` == `PROTOCOL_VERSION`
2. `schema_version` == `SCHEMA_VERSION`
3. `dataset.name` == `DATASET_NAME`, `dataset.split` == `DATASET_SPLIT`,
   `dataset.revision` == `DATASET_REVISION`
4. `evaluator.name` == `EVALUATOR_NAME`, `evaluator.revision` ==
   `EVALUATOR_REVISION`
5. `groups` has exactly 2 entries
6. each group has exactly 3 tasks
7. each group has a `repository` and `common_revision` (40-hex SHA)
8. the two groups have different `repository` values
9. each task has all `REQUIRED_TASK_FIELDS`
10. each `issue_url` matches `https://github.com/...`
11. each `license` is in `SUPPORTED_LICENSES`
12. each `original_base_commit` is a 40-hex SHA
13. each `fail_to_pass` is a non-empty list
14. each `adaptation_evidence` has all `REQUIRED_EVIDENCE_FIELDS`
15. `manifest_digest` matches `compute_manifest_digest(manifest)`

SHA-40 pattern: `^[0-9a-f]{40}$`. GitHub URL pattern:
`^https://github\.com/[^/]+/[^/]+/(issues|pull)/[0-9]+$`.

CLI:

```
python3 -m benchmarks.validate_manifest <manifest.json>
```

Exit 0 = valid, 1 = findings, 2 = fault (file unreadable or unparseable).

### test_validate_manifest.py

Tests:

1. `test_valid_manifest_passes` — a fixture manifest with correct values produces
   no findings.
2. `test_wrong_protocol_version` — finding naming the field.
3. `test_wrong_dataset_revision` — finding naming the pinned value.
4. `test_wrong_group_count` — finding naming the count.
5. `test_wrong_task_count_per_group` — finding.
6. `test_duplicate_repository_across_groups` — finding.
7. `test_bad_license` — finding naming the unsupported license.
8. `test_bad_sha` — finding naming the field.
9. `test_missing_task_field` — finding naming the missing field.
10. `test_empty_fail_to_pass` — finding.
11. `test_missing_evidence_field` — finding.
12. `test_digest_mismatch` — finding.
13. `test_cli_valid_exit_code` — subprocess call on a valid fixture exits 0.
14. `test_cli_invalid_exit_code` — subprocess call on an invalid fixture exits 1.
15. `test_cli_fault_exit_code` — subprocess call on a missing file exits 2.

Each test builds its fixture manifest from a `make_valid_manifest()` helper that
returns a known-good dict, then mutates one field.

### Verification

```bash
just py-test    # expect: all tests pass
just py-lint    # expect: clean
```

### Acceptance

- `validate_manifest()` returns findings for every constraint violation.
- CLI exits 0/1/2 correctly.

---

## Task 4: Deterministic selection algorithm

### Files

- Create `benchmarks/select_tasks.py`.
- Create `benchmarks/test_select_tasks.py`.

### select_tasks.py

Core function:

```python
def select_tasks(
    dataset_jsonl: str,
    validate_fn: Callable[[str, str], dict] | None = None,
) -> tuple[dict, dict]:
    """Select two repository-disjoint task groups from a dataset JSONL file.

    Returns (manifest, ledger).
    validate_fn is called per (instance_json, candidate_revision) and must return
    an adaptation_evidence dict or raise ValidationError. If None, a subprocess
    call to validate_task.py is used.
    """
```

Algorithm steps (from the spec):

1. Parse JSONL, sort by ascending `instance_id`.
2. Filter by eligibility rules (license, repo visibility, author identity).
3. Build ledger with exclusions.
4. Group eligible by repository (lexical order).
5. Per repo: `itertools.combinations(eligible, 3)`, sorted IDs, sorted combos.
6. Per combo: candidate revisions = distinct base commits, lexical order.
7. Per revision: call `validate_fn` for each task; first all-pass = qualifying.
8. Select first two qualifying combos from different repos.
9. Build manifest with `compute_manifest_digest`.

The `validate_fn` parameter is the seam for testing: tests pass a stub that
returns success/failure based on known fixture data, avoiding subprocess calls.

### test_select_tasks.py

Tests:

1. `test_filter_excludes_bad_license` — an instance with GPL-3.0 is excluded.
2. `test_filter_excludes_randomparity_author` — an instance whose issue author is
   `randomparity` is excluded.
3. `test_filter_excludes_missing_author_identity` — an instance with no
   author evidence is excluded.
4. `test_combination_ordering` — combos are sorted by (first, second, third) ID.
5. `test_ids_sorted_within_combination` — IDs inside each combo are lexical.
6. `test_candidate_revisions_lexical_order` — distinct base commits tested in
   lexical order.
7. `test_first_qualifying_revision_selected` — the first revision where all
   three tasks pass is selected, not a later one.
8. `test_first_two_disjoint_repos_selected` — two groups from different repos.
9. `test_insufficient_groups_raises` — fewer than 2 qualifying combos raises an
   error with a clear message.
10. `test_ledger_records_exclusions` — every excluded instance has a rule +
    evidence.
11. `test_ledger_records_combinations` — every tested combo is in the ledger
    with its status.
12. `test_manifest_digest_matches` — the emitted manifest's digest matches
    `compute_manifest_digest`.
13. `test_manifest_has_correct_counts` — 2 groups, 3 tasks each.

Fixtures: small JSONL files with 4–6 instances across 2–3 repos, with known
base commits and licenses. The stub `validate_fn` returns success for
predetermined (instance_id, revision) pairs.

### Verification

```bash
just py-test    # expect: all tests pass
just py-lint    # expect: clean
```

### Acceptance

- Selection is deterministic given the same input.
- Filtering, ordering, and group selection match the protocol.
- Ledger is complete.
- Manifest passes `validate_manifest()`.

---

## Task 5: Per-task validation

### Files

- Create `benchmarks/validate_task.py`.
- Create `benchmarks/test_validate_task.py`.

### validate_task.py

```python
def validate_task(
    instance: dict,
    candidate_revision: str,
    work_dir: str,
    runner: Callable[[list[str]], subprocess.CompletedProcess] | None = None,
) -> dict:
    """Validate one task at a candidate revision.

    1. git clone upstream repo at candidate_revision (read-only).
    2. git apply --check the gold patch.
    3. git apply the gold patch.
    4. Run SWE-bench Docker evaluator: pre-patch failure + post-patch pass.
    5. Return adaptation_evidence dict.
    6. Restore candidate checkout.
    """
```

The `runner` parameter defaults to `subprocess.run` and is the test seam.

### test_validate_task.py

Tests:

1. `test_gold_patch_apply_check_fails` — `git apply --check` returns nonzero →
   raises, evidence records failure.
2. `test_gold_patch_apply_succeeds` — apply succeeds → proceeds to evaluator.
3. `test_pre_patch_failure_assertion` — at least one FAIL_TO_PASS must fail
   pre-patch; if all pass pre-patch, raises.
4. `test_post_patch_all_pass` — all FAIL_TO_PASS + PASS_TO_PASS pass post-patch
   → evidence records success.
5. `test_post_patch_failure` — a post-patch test failure → raises.
6. `test_evidence_fields_complete` — returned dict has all
   `REQUIRED_EVIDENCE_FIELDS`.
7. `test_restore_after_validation` — work directory is restored to candidate
   revision after validation (gold patch removed).
8. `test_docker_invocation_uses_subprocess_args` — the Docker command is passed
   as a list of args, not a shell string (no `shell=True`).

Tests use a stub `runner` that returns canned `CompletedProcess` results and a
fixture git repo created with `git init` + commits.

### Verification

```bash
just py-test    # expect: all tests pass
just py-lint    # expect: clean
```

### Acceptance

- Validation correctly asserts pre-patch failure and post-patch pass.
- Evidence is complete and accurate.
- No `shell=True` in subprocess calls.
- Work directory is restored.

---

## Task 6: Issue materialization

### Files

- Create `benchmarks/materialize_issues.py`.
- create `benchmarks/test_materialize_issues.py`.

### materialize_issues.py

```python
def materialize_issues(
    manifest: dict,
    repo: str,
    dry_run: bool = False,
    runner: Callable[[list[str]], subprocess.CompletedProcess] | None = None,
) -> dict:
    """Materialize benchmark-owned issues from a manifest.

    For each group, creates issues #1/#2/#3 in lexical instance_id order with
    exact labels. Returns an updated manifest with materialized_issue_numbers.
    """
```

Labels: `type:bug`, `priority:P2`, `status:ready`, `risk:night-watch`,
`effort:M`.

Topology digest: SHA-256 of canonical JSON over the materialized state (issue
numbers, bodies, labels, absence contract).

### test_materialize_issues.py

Tests:

1. `test_dry_run_prints_gh_commands` — dry-run mode prints `gh issue create`
   commands without executing.
2. `test_issue_order_matches_lexical_instance_id` — issues are created in
   ascending instance_id order.
3. `test_exact_label_set` — each issue gets exactly the five required labels.
4. `test_no_extra_labels` — no label outside the required set is applied.
5. `test_manifest_updated_with_issue_numbers` — returned manifest has
   `materialized_issue_number` set.
6. `test_topology_digest_computed` — topology digest is present and matches a
   recomputed value.
7. `test_gh_invocation_uses_args_not_shell` — subprocess calls use arg lists.
8. `test_two_groups_create_six_issues` — 2 groups × 3 tasks = 6 issues.

Tests use a stub `runner` that captures commands and returns canned issue
numbers.

### Verification

```bash
just py-test    # expect: all tests pass
just py-lint    # expect: clean
```

### Acceptance

- Materialization creates issues in the correct order with exact labels.
- Dry-run mode works without side effects.
- Manifest is updated with issue numbers.
- Topology digest is computed.

---

## Task 7: Dataset fetch

### Files

- Create `benchmarks/fetch_dataset.py`.
- Create `benchmarks/test_fetch_dataset.py`.

### fetch_dataset.py

Standalone script (`if __name__ == "__main__"`). Lazy-imports
`huggingface_hub` and `pyarrow` inside the fetch function. The normalization
function is importable without those deps:

```python
def normalize_row(row: dict) -> dict:
    """Map a raw SWE-bench_Verified dataset row to canonical instance fields."""
```

Maps: `instance_id`, `repo`, `base_commit`, `patch`, `test_patch`,
`FAIL_TO_PASS` (JSON string → list), `PASS_TO_PASS` (JSON string → list),
`problem_statement`, `issue_url`.

### test_fetch_dataset.py

Tests:

1. `test_normalize_row_maps_all_fields` — a fixture row with all fields maps
   correctly.
2. `test_fail_to_pass_parsed_from_json_string` — SWE-bench stores these as JSON
   strings; the normalizer parses them to lists.
3. `test_pass_to_pass_parsed_from_json_string`.
4. `test_missing_issue_url_handled` — `issue_url` may be absent; normalizer
   sets it to `None` rather than crashing.
5. `test_empty_row_raises` — an empty dict raises a clear error.

### Verification

```bash
just py-test    # expect: all tests pass
just py-lint    # expect: clean
```

### Acceptance

- Normalization maps all required fields.
- JSON-string fields are parsed to lists.
- Missing fields are handled gracefully.
- `huggingface_hub` and `pyarrow` are not imported at module level.

---

## Task 8: Final verification + commit

### Steps

1. Run `just verify` — full suite must be green.
2. Run `ruff check benchmarks/` and `ruff format --check benchmarks/` — clean.
3. Run `python3 -m unittest discover -s benchmarks -p 'test_*.py' -v` — all
   tests pass.
4. Verify no host paths, secrets, or auth in any committed file:
   `just public-safety`.
5. Re-read the diff for complexity and naming.
6. Commit any remaining changes.

### Acceptance

- `just verify` exits 0.
- No ruff warnings.
- All Python tests pass.
- Public safety gate passes.
