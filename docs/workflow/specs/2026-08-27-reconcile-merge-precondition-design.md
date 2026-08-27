# Reconcile merge-precondition wording and deterministic guard validation — design

## Scope

Issue #243's charter token is `q243-241c0c5d`. The change clarifies that `$deliver` hands
back a green, mergeable pull request but does not authorize its merge; the commit-bound gate
and author handshake from accepted ADR 0035 remain the merge authority. The operator expanded
the issue to include the quest-log tracker fixture failure that blocked verification, then
expanded it again to replace actionlint's deadlocking ShellCheck integration without losing
workflow-shell coverage.

The permitted implementation surface is `skills/deliver/SKILL.md`,
`skills/quest-log/SKILL.md`, `.claude-plugin/plugin.json`, and
`tests/fixtures/quest-log/tracker-test.sh`, `Justfile`, and a dedicated actionlint gate script
and fixture suite. Runtime tracker behavior, workflow runtime semantics, `$return-to-town`, and
the existing `$deliver` tracking-write condition do not change.

## Design

`$deliver` names its green-plus-mergeable state as a hand-back condition and points merging
callers to ADR 0035. The `status:awaiting-merge` description names the recorded commit-bound
author handshake. No automated gate asserts on either wording.

The tracker fixture continues to derive the full operation set. For each non-exempt operation,
it captures `declare -f` output to a scalar, reports a distinct inspection failure if capture
fails, and searches that complete scalar for `github_require_id`. This implements ADR 0039 and
removes the `rg -q` early-close race without weakening `pipefail` or changing production code.

The actions gate invokes actionlint with its integrated ShellCheck path disabled, then
fail-closed extracts every supported workflow literal `run: |` block and invokes ShellCheck on
each block with the explicit Bash dialect. The gate accepts only workflows with no `shell:`
override and with static Ubuntu/macOS runners or the exact `matrix.os` expression backed entirely
by literal Ubuntu/macOS matrix values. Any other shell, runner, or scalar form rejects the whole
workflow rather than being inferred or excluded. This implements ADR 0040 while preserving ADR
0034's inline Pages build.

## Failure behavior

A function-definition capture failure stops with the operation name and an inspection error.
A successful capture without `github_require_id` retains the existing actionable missing-guard
failure. Empty or unknown operations remain governed by the existing derived-list checks.

An actionlint failure, workflow discovery or extraction failure, unsupported run or shell form,
or ShellCheck failure stops `actions-check` with an actionable diagnostic.

## Verification

- Prove the guard assertion bites with a controlled missing-pattern fault, observe the focused
  tracker fixture fail, then revert the fault.
- Run `just test tracker-test` and require all assertions to pass.
- Prove the action gate passes `-shellcheck=` to actionlint, presents every extracted block to
  ShellCheck, and propagates actionlint, extraction, and ShellCheck failures with its fixture.
- Run `git diff --check`, `just shape-check`, `just public-safety`, and
  `just version-check`.
- Run `just verify` bare and require exit 0 with no warnings.

## Architecture and guardrails

Host architecture is `x86_64`; the repository declares no target architecture, so the
relationship is `no-target-declared`. `BASE_BRANCH` is `main`. The full local guardrail is
`just verify`; CI invokes the same suite through `just ci`. ADR indexing is not coupled.

See [ADR 0039](../../adr/0039-capture-derived-guard-input-before-search.md) and
[ADR 0040](../../adr/0040-shellcheck-workflow-blocks-outside-actionlint.md).
