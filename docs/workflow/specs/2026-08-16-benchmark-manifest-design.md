# Benchmark manifest and selection mechanism

Issue: #119

## Goal

Build the machine-readable task-manifest schema and the deterministic selection,
validation, and materialization mechanisms that encode the v1 benchmark protocol
([`docs/benchmarks/adept-workflow-v1.md`](../../benchmarks/adept-workflow-v1.md)).
The frozen manifest and candidate ledger are produced by running these mechanisms;
this PR delivers the mechanisms and schema, not the frozen manifest itself.

## Scope and authority

The frozen scope is issue #119 annotation token
`a4f2c91e-7d3b-4e8a-9c6f-2b1e550d04a7`. Issue #119 supplies the outcome and
criteria. ADR 0017 and the v1 protocol (merged via PR #124) supply the frozen
selection procedure, pinned revisions, eligibility rules, and materialization
contract. Operator decisions 2026-08-16: benchmark-owned repo is a new public
repository (name defaulted `randomparity/adept-bench-tasks`); PR scope is
mechanism + schema, with the frozen manifest produced by running them.

Permitted surface: Python scripts under `benchmarks/`, their unittest suites,
a ruff configuration, Justfile recipe additions, CI workflow tool-install
additions, this specification, ADR 0019, and an implementation plan.

Excluded: the isolated three-arm runner (#120), telemetry (#121), scoring
(#122), and the first baseline run (#123); the actual frozen manifest run (not a
merge precondition for this PR); model/provider comparison; private or
Adept-authored tasks; hosted presentation; Adept optimization.

## Language decision

Python 3, recorded in [ADR 0019](../../adr/0019-benchmark-manifest-selection-in-python.md).
The repo's bash convention governs gate scripts under `scripts/`; benchmark
infrastructure is not a gate. The selection algorithm (k-combination enumeration,
lexical sorting, candidate-revision testing loop), SWE-bench dataset interop,
and JSON manipulation are natural in Python and error-prone in bash+jq. Standard
library only for all testable code; `huggingface_hub` + `pyarrow` are lazy-imported
in the standalone fetch script and never imported by tests or the selection logic.

## Architecture

Six components, each with one responsibility and a testable interface:

```
fetch_dataset.py  →  JSONL dataset
                        │
                        ▼
                 select_tasks.py  ──►  manifest.json + ledger.json
                        │                        │
                        │ calls per candidate    │ consumed by
                        ▼                        ▼
                 validate_task.py          materialize_issues.py
                 (git + Docker)            (gh CLI)
                        │                        │
                        ▼                        ▼
                 adaptation evidence      benchmark-owned repo
                                          with issues #1/#2/#3
```

`validate_manifest.py` validates any manifest JSON against the protocol
constraints independently of how it was produced.

## Manifest schema

The manifest is benchmark-owned, not agent-visible. It retains oracle material
(test names, test patches, base commits) needed by the evaluator (#121) but
never placed in an agent's environment. Gold patches are used only during
validation and are not retained; their proof is recorded as adaptation evidence.
Runtime agent-visible isolation — the sanitized Git repository with no later
commits, refs, or gold-patch objects, and the filesystem/environment boundary
that keeps the manifest out of the agent's reach — is owned by #120's runner per
the protocol's §Safety and leakage controls. #119 ensures the manifest is
benchmark-owned and that materialized issues contain only the unchanged public
issue body (no test names, patches, or oracle metadata).

### Manifest JSON structure

```json
{
  "protocol_version": "adept-workflow-v1",
  "schema_version": "1.0.0",
  "dataset": {
    "name": "SWE-bench/SWE-bench_Verified",
    "split": "test",
    "revision": "03e151cf5560b1af6a4363c6a9d766deaaea6b56"
  },
  "evaluator": {
    "name": "SWE-bench/SWE-bench",
    "revision": "128cbd1a5759694874e6bd56624cb2fd6fb079e2"
  },
  "groups": [
    {
      "group_id": "A",
      "repository": "owner/repo",
      "common_revision": "<40-hex-sha>",
      "tasks": [
        {
          "instance_id": "owner__repo-12345",
          "issue_url": "https://github.com/owner/repo/issues/12345",
          "license": "BSD-3-Clause",
          "original_base_commit": "<40-hex-sha>",
          "fail_to_pass": ["test.module::TestClass::test_method"],
          "pass_to_pass": ["test.module::OtherTest"],
          "test_patch": "<git diff>",
          "adaptation_evidence": {
            "gold_patch_applied_cleanly": true,
            "pre_patch_failures": ["test.module::TestClass::test_method"],
            "post_patch_all_pass": true,
            "evaluator_image": "<image:digest>"
          },
          "materialized_issue_number": null
        }
      ]
    }
  ],
  "selection": {
    "candidate_ledger": "ledger-2026-08-16-utc.json",
    "manifest_digest": "<sha256-of-canonical-json>"
  }
}
```

### Candidate ledger JSON structure

```json
{
  "dataset_revision": "03e151cf...",
  "instances": [
    {
      "instance_id": "owner__repo-12345",
      "repository": "owner/repo",
      "status": "eligible",
      "exclusion_rule": null,
      "evidence": null
    },
    {
      "instance_id": "owner__repo-99999",
      "repository": "owner/repo",
      "status": "excluded",
      "exclusion_rule": "license-not-supported",
      "evidence": "SPDX license GPL-3.0 recorded at <url>"
    }
  ],
  "combinations": [
    {
      "repository": "owner/repo",
      "instance_ids": ["id1", "id2", "id3"],
      "candidate_revisions_tested": ["<sha1>", "<sha2>"],
      "qualifying_revision": "<sha1>",
      "status": "selected"
    }
  ]
}
```

### Manifest digest

The `manifest_digest` is the lowercase SHA-256 of the manifest's RFC 8785
canonical JSON bytes, computed over the manifest with the `selection.manifest_digest`
field set to an empty string and all `materialized_issue_number` fields set to
`null`. The digest is computed after selection completes and before materialization
begins; it is immutable once computed and is the seed for the run schedule (protocol
§Deterministic measured order). Materialization updates `materialized_issue_number`
but must not recompute the digest.

## Manifest validator (validate_manifest.py)

Pure Python, no network, no subprocess. Validates:

- `protocol_version` equals `adept-workflow-v1`
- `schema_version` equals `1.0.0`
- `dataset.name`, `dataset.split`, `dataset.revision` match the pinned protocol values
- `evaluator.name`, `evaluator.revision` match the pinned protocol values
- exactly 2 groups, each exactly 3 tasks (count = 6)
- each group has one `repository` and one `common_revision` (40-hex SHA)
- the two groups have different `repository` values
- each task has: `instance_id`, `issue_url` (https GitHub URL), `license` (in
  the protocol allowlist), `original_base_commit` (40-hex SHA), `fail_to_pass`
  (non-empty array), `pass_to_pass` (array), `test_patch` (non-empty string),
  `adaptation_evidence` (object with the four required fields)
- `manifest_digest` matches the recomputed canonical-JSON digest

Exits 0 on valid, 1 on a validation finding (printing each finding), 2 on a
fault (cannot read or parse the file).

## Dataset fetch (fetch_dataset.py)

Standalone script using `huggingface_hub` and `pyarrow` (lazy-imported; not
imported by tests or other modules). Downloads the SWE-bench_Verified test split
at the pinned Hugging Face revision and emits canonical JSONL — one instance per
line with the fields the selection algorithm needs: `instance_id`, `repo`,
`base_commit`, `patch` (gold patch), `test_patch`, `FAIL_TO_PASS`,
`PASS_TO_PASS`, `problem_statement`, `issue_url`.

The JSONL format is the contract between fetch and select. Tests exercise the
normalization function (raw dataset row → canonical JSONL line) with fixture
rows; the network call is not tested in CI.
Malformed JSONL rows are skipped with a warning recorded in the candidate ledger.
`instance_id` is required; rows missing it are unprocessable and skipped under
exclusion rule `missing-required-field`. Rows with wrong types or invalid UTF-8
use `malformed-dataset-row`. Extra fields are ignored. The selection algorithm
does not crash on malformed input.

## Deterministic selection (select_tasks.py)

Stdlib only. Input: dataset JSONL file path. Output: manifest JSON + ledger JSON.

Algorithm (protocol §Deterministic task selection):

1. Parse JSONL. Enumerate instances by ascending `instance_id`.
2. Build the candidate ledger. For each instance, record `instance_id`,
   `repository`, `license` (read from the SWE-bench_Verified dataset's `license`
   field, not by scanning the upstream repository), `base_commit`, `issue_url`.
3. Exclude instances per the objective rules:
   - repository not public
   - SPDX license not in `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`,
     `ISC`, `Python-2.0`, `PSF-2.0`
   - missing or null `license` field uses exclusion rule `license-missing`
   - public issue author or SWE-bench contribution author has GitHub login
     `randomparity`
   - public evidence does not expose the author identity for that check
   - (evaluator image availability and test reproducibility are checked in the
     per-task validation step, not the pre-filter)
4. Record every exclusion with its rule and public source evidence.
5. Group eligible instances by repository.
6. For each repository in lexical order:
   a. Enumerate every 3-element combination of eligible instances
      (`itertools.combinations`).
   b. Sort IDs inside each combination lexically.
   c. Sort combinations by the tuple `(first_id, second_id, third_id)`.
   d. Candidate common revisions = the combination's distinct full
      `original_base_commit` SHAs in lexical order.
   e. For each candidate revision, in order:
      - Call `validate_task.py` for each of the three tasks independently from
        a clean candidate checkout.
      - The first revision satisfying all rules for all three tasks is the
        combination's qualifying common revision.
   f. The first combination with a qualifying common revision is this
      repository's selected group.
7. Select the first two qualifying combinations from different repositories. If
   fewer than two groups qualify, selection stops and reports the shortfall —
   discretionary replacement is forbidden (protocol §Deterministic task selection).
8. Emit the manifest and the complete accepted/rejected ledger.

The per-task validation call is a subprocess invocation of
`validate_task.py`. Tests mock the subprocess (via a callable parameter or env
override) and exercise the enumeration, filtering, sorting, and selection logic
with fixture JSONL.

## Per-task validation (validate_task.py)

Stdlib only (subprocess, json, pathlib). Input: instance JSON, candidate
revision, evaluator config. Steps:

1. `git clone` the upstream repository (read-only) at the candidate revision.
2. `git apply --check` the gold patch — must succeed without edits, fuzz, or
   conflict resolution.
3. `git apply` the gold patch.
4. Run the SWE-bench Docker evaluator with the instance's `test_patch`,
   `FAIL_TO_PASS`, `PASS_TO_PASS`, and the applied gold patch. The evaluator
   verifies:
   - at least one `FAIL_TO_PASS` test fails before the patch (pre-patch failure)
   - every `FAIL_TO_PASS` and `PASS_TO_PASS` test passes after the patch
5. Record adaptation evidence (gold patch applied cleanly, pre-patch failures,
   post-patch pass, evaluator image identifier).
6. Restore the candidate checkout. Cleanup runs on both success and failure paths:
   temporary directories are removed, Docker containers are stopped and removed,
   and git state is restored even when validation fails mid-step (try/finally).
Cleanup failures (e.g. directory permissions, Docker daemon unavailable) are
reported as warnings and do not prevent the validation result from being
recorded; best-effort cleanup is attempted on all paths.

The Docker invocation is via `subprocess.run`. Tests stub the git and docker
commands via a command-runner parameter and verify the orchestration logic,
evidence recording, and error handling.
Docker error handling distinguishes infrastructure failures (daemon unavailable,
image pull timeout, container crash) from evaluator findings (test results).
Infrastructure failures exit with code 2 (fault); evaluator findings exit with
code 1 (finding). No retry: a failed validation attempt is recorded in the ledger
with its failure category, and the selection algorithm moves to the next candidate
revision or combination.
A `git apply --check` failure (patch conflict, missing context, format error) is a
validation finding (exit 1), not an infrastructure failure — the patch does not apply
cleanly at this revision, so the candidate is ineligible.
Repository creation is a pre-run prerequisite: the benchmark-owned repo must
exist before materialization. If it does not, materialization exits with code 2
(fault) and a diagnostic naming the missing repo.
Selection and materialization are not designed for concurrent execution. The
protocol requires serial execution of all run units; concurrent access to the
benchmark-owned repository during materialization is undefined behavior.

## Issue materialization (materialize_issues.py)

Stdlib only (subprocess, json, hashlib). Input: manifest JSON, benchmark-owned
repo name. Steps:

1. For each group, in ascending `instance_id` order within the group:
   a. Create an issue with the unchanged public issue body.
   b. Issue numbers must be `#1`, `#2`, `#3` in lexical task order.
   c. Apply exact labels: `type:bug`, `priority:P2`, `status:ready`,
      `risk:night-watch`, `effort:M`.
   d. Verify the absence contract: no dependency, parent, sub-issue, milestone,
      project, assignee, linked branch, linked PR, comment, or reaction; no
      other issue visible.
2. Compute the topology digest over the materialized state.
3. Update the manifest with `materialized_issue_number` values.

`--dry-run` mode prints the planned `gh` commands and the expected topology
without executing writes. Tests exercise dry-run output and the topology digest
computation with fixture manifests.
Idempotency: materialize_issues.py detects existing issues in the benchmark-owned
repo before creating new ones. If an issue already exists and matches the contract
(correct body, labels, and absence), it is reused; if it exists but does not match
(extra label, comment, reaction, or missing required label), the operation fails
fatally — stops all materialization and reports the unexpected state. On partial
failure (some issues created, others not), the operation reports the incomplete
state and does not update the manifest. Re-running materialization completes the
missing issues without duplicating existing ones.

Topology digest: SHA-256 over RFC 8785 canonical JSON of the materialized topology
state — issue numbers in lexical instance_id order, the exact label set per issue,
and the verified absence of every relationship and metadata field the protocol
forbids (encoded as explicit `false` fields in the digested structure). The digest
is computed during materialization, before the manifest is updated, and recorded
in the manifest. On subsequent runs, a digest mismatch is a fatal error indicating
external modification or a different materialization run.

## File layout

```
benchmarks/
  __init__.py
  manifest.py               # schema constants, digest computation
  validate_manifest.py      # manifest validator (CLI + library)
  fetch_dataset.py          # HF dataset fetch (standalone, heavy deps)
  select_tasks.py           # deterministic selection (CLI + library)
  validate_task.py          # per-task gold-patch + evaluator validation
  materialize_issues.py     # benchmark-owned issue materialization
  test_manifest.py          # schema + digest tests
  test_validate_manifest.py # validator tests (valid + invalid fixtures)
  test_select_tasks.py      # selection algorithm tests (fixture JSONL)
  test_validate_task.py     # validation orchestration tests (stub subprocess)
  test_materialize_issues.py # materialization tests (dry-run + digest)
  test_fetch_dataset.py     # fetch normalization tests (fixture rows)
ruff.toml                   # ruff lint + format config
```

`benchmarks/` ships in the plugin cache alongside `scripts/` — consistent with
the repo's existing pattern of shipping deterministic tooling. The scripts clear
CLAUDE.md rule 2's bar (operations a model cannot do reliably inline) and rule 3
(every script runs and exits).

## Testing strategy

unittest (stdlib), discovered by `python3 -m unittest discover -s benchmarks -p
'test_*.py'`. No pytest dependency. Each test module is self-contained: fixtures
are built in `tempfile.TemporaryDirectory` contexts, no network, no Docker.

Test coverage per component:

- **manifest**: digest computation round-trip; canonical JSON ordering.
- **validate_manifest**: valid manifest passes; each constraint violation
  produces a named finding (wrong protocol_version, wrong count, duplicate repo,
  bad SHA, bad license, missing field, digest mismatch).
- **select_tasks**: filtering by each exclusion rule; combination enumeration and
  ordering; candidate-revision selection order; first-two-disjoint-repo
  selection; ledger completeness; manifest emission with correct digest.
- **validate_task**: gold patch apply check; pre-patch failure assertion;
  post-patch pass assertion; evidence recording; restore after validation;
  docker-invocation stub.
- **materialize_issues**: dry-run command output; label set; issue ordering;
  absence contract verification; topology digest; manifest update.
- **fetch_dataset**: row normalization (field mapping, FAIL_TO_PASS/PASS_TO_PASS
  JSON parsing, missing-field handling).

## Guardrail integration

### Justfile

New recipes:

```makefile
py-test:
  python3 -m unittest discover -s benchmarks -p 'test_*.py' -v

py-lint:
  ruff check benchmarks/
  ruff format --check benchmarks/
```

`py-lint` joins `commit-check` (runs on every commit, like shellcheck).
`py-test` joins `verify` only (runs on push/CI, like the `test` recipe).

### CI workflow

Add `ruff` to the `brew install` line in `.github/workflows/verify.yml`. Python3
is pre-installed on both ubuntu-latest and macos-latest. No pip installs needed
(unittest is stdlib; `fetch_dataset.py`'s heavy deps are not tested in CI).

### Shell-source gate

`list-shell-sources.sh` discovers files ending in `.sh` or with a bash shebang.
Python files match neither, so they are invisible to shellcheck, shfmt, and the
format-check recipe. No conflict.

### ruff configuration

`ruff.toml` at repo root, scoped to `benchmarks/`:

```toml
[lint]
select = ["E", "F", "W", "I", "UP", "B"]
```

Line length 100 (matching the repo's global limit). Target Python 3.12 (the
lowest Python widely available on GitHub Actions runners; the code uses no
3.13-only features).

## Security and leakage controls

### Boundary inventory

| Boundary | What crosses | Control |
|---|---|---|
| HF dataset → fetch script | untrusted dataset rows (public prose, code diffs) | fetch treats all input as data, never executes it; test_patch and gold_patch are stored as strings, never eval'd |
| Upstream repo → validate_task | untrusted git repository | read-only clone; `git apply --check` rejects malicious patches; Docker evaluator runs in pinned image |
| Manifest → agent runtime | oracle material (test names, test patches) | manifest is benchmark-owned; agent runtime never receives the manifest; the runner (#120) enforces filesystem and network isolation |
| materialize_issues → GitHub | issue bodies, labels | `gh` CLI scoped to benchmark-owned repo; upstream repos are read-only; `--dry-run` for testing |
| validate_task → Docker | gold patch, test patch, test lists | Docker image is pinned; subprocess args are passed as arguments, never interpolated shell |

### Actor model

Untrusted parties: public SWE-bench data (could contain malicious prose or
patches), upstream repository content (could contain malicious code in tests).
Trusted: benchmark operator, GitHub API, Docker runtime, host.

### Explicitly out of scope

- Agent-runtime isolation enforcement (owned by #120's runner).
- Network egress proxy configuration (owned by #120).
- Credential scoping beyond `gh` CLI's default (owned by #120).

## Dependencies

| Component | Dependencies |
|---|---|
| manifest, validate_manifest, select_tasks, validate_task, materialize_issues | Python 3 stdlib only |
| fetch_dataset | `huggingface_hub`, `pyarrow` (lazy-imported, not in CI) |
| tests | Python 3 stdlib (`unittest`, `json`, `tempfile`, `subprocess`, `unittest.mock`) |
| linting | `ruff` (via brew in CI, via pip locally) |

No `requirements.txt` for the stdlib-only code. `fetch_dataset.py` documents its
extra deps in a module docstring; running it requires `pip install
huggingface_hub pyarrow`, which the operator does outside CI.

## Interfaces to sibling issues

- **#120 (runner)**: consumes the manifest to provision task repositories and
  issue state; consumes the JSONL dataset contract for agent-visible material
  derivation.
- **#121 (telemetry)**: consumes `fail_to_pass`, `pass_to_pass`, `test_patch`,
  and `original_base_commit` from the manifest to run the functional evaluator.
- **#122 (scoring)**: consumes the manifest's group topology and issue ordering
  for campaign evaluation.
- **#123 (baseline)**: runs the full selection to produce the frozen manifest,
  then hands it to #120–#122.
