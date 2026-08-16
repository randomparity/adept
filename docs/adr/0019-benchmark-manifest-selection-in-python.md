# 0019 — Benchmark manifest and selection mechanism in Python

## Status

Accepted (2026-08-16)

## Context

Issue #119 builds the machine-readable task-manifest schema and the deterministic
selection, validation, and materialization mechanisms that encode the v1
benchmark protocol (ADR 0017). The protocol requires enumerating the
SWE-bench_Verified test split, filtering by objective eligibility rules,
enumerating three-task combinations per repository in lexical order, testing
candidate common revisions via the SWE-bench Docker evaluator, and selecting the
first two repository-disjoint qualifying groups. It also requires materializing
the selected tasks into a benchmark-owned GitHub repository with an exact label
and topology contract.

This repository's construction rules (CLAUDE.md Anatomy rules 1–4) govern what
ships as plugin content. Rule 2 permits executable code that does something a
model cannot do reliably inline — a deterministic operation that would otherwise
burn context or be performed inconsistently. The selection algorithm, dataset
interop, and Docker orchestration clear that bar. Rules 1–4 say nothing about
language, but every existing script under `scripts/` is bash, and the gate suite
(shellcheck, shfmt, list-shell-sources) is bash-only.

## Decision

Implement the benchmark manifest schema, deterministic selection, per-task
validation, and issue materialization as Python 3 scripts under `benchmarks/`,
using the standard library for all testable code. Wire Python tests (unittest)
and linting (ruff) into the guardrail suite. Record this as a deliberate
language boundary: bash governs gate scripts under `scripts/`; Python governs
benchmark infrastructure under `benchmarks/`.

`fetch_dataset.py` lazy-imports `huggingface_hub` and `pyarrow` for Hugging Face
dataset access; these are not imported by tests or by any other module, so CI
needs no Python packages beyond the pre-installed runtime and ruff (via brew).

## Consequences

A second language lives in the repo. The guardrail suite gains `py-test` and
`py-lint` recipes; `py-lint` joins `commit-check` (every commit) and `py-test`
joins `verify` (push/CI). `list-shell-sources.sh` discovers only `.sh` files and
bash-shebang files, so Python files are invisible to shellcheck and shfmt — no
conflict. The CI workflow gains `ruff` in its brew install line.

`benchmarks/` ships in the plugin cache alongside `scripts/`, consistent with
the repo's existing pattern of shipping deterministic tooling. The scripts are
not skills and are not auto-discovered as invocable commands.

The manifest schema is a new external contract consumed by #120–#123. Changing
it after the first baseline creates a new schema version rather than silently
breaking downstream consumers.

## Considered & rejected

**bash + jq.** SWE-bench_Verified is distributed as parquet, which bash and jq
cannot parse. K-combination enumeration has no jq builtin and would require a
recursive jq function or a bash triple-nested loop with manual lexical sorting.
JSON manipulation for the manifest and ledger is verbose and error-prone in
bash. SWE-bench's own tooling is Python. Fighting bash for these operations
would produce fragile code that a reviewer cannot confidently verify.

**Python with pytest.** pytest is a runtime dependency not pre-installed on
GitHub runners and not in Homebrew. unittest is stdlib and covers the same
ground for unit tests. Adding pytest would require a pip install step in CI for
no functional gain.

**Python with pyarrow/pandas as hard dependencies.** Only `fetch_dataset.py`
needs parquet access. Making pyarrow a hard dependency would require installing
it in CI even though no CI test exercises the fetch path. Lazy-importing it in
the standalone fetch script keeps CI clean and the testable modules
dependency-free.

**Putting benchmark scripts under `scripts/`.** That directory's scripts are
gates invoked by `just` recipes and the pre-push hook. Benchmark infrastructure
is not a gate; mixing the two would blur the construction-rule boundary and
force `list-shell-sources.sh` to classify Python files it cannot lint.
