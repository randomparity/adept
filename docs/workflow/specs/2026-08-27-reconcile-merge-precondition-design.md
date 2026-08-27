# Reconcile merge-precondition wording and deterministic guard validation — design

## Scope

Issue #243's charter token is `q243-241c0c5d`. The change clarifies that `$deliver` hands
back a green, mergeable pull request but does not authorize its merge; the commit-bound gate
and author handshake from accepted ADR 0035 remain the merge authority. The operator expanded
the issue to include the quest-log tracker fixture failure that blocked verification.

The permitted implementation surface is `skills/deliver/SKILL.md`,
`skills/quest-log/SKILL.md`, `.claude-plugin/plugin.json`, and
`tests/fixtures/quest-log/tracker-test.sh`. Runtime tracker behavior, `$return-to-town`, and
the existing `$deliver` tracking-write condition do not change.

## Design

`$deliver` names its green-plus-mergeable state as a hand-back condition and points merging
callers to ADR 0035. The `status:awaiting-merge` description names the recorded commit-bound
author handshake. No automated gate asserts on either wording.

The tracker fixture continues to derive the full operation set. For each non-exempt operation,
it captures `declare -f` output to a scalar, reports a distinct inspection failure if capture
fails, and searches that complete scalar for `github_require_id`. This implements ADR 0039 and
removes the `rg -q` early-close race without weakening `pipefail` or changing production code.

## Failure behavior

A function-definition capture failure stops with the operation name and an inspection error.
A successful capture without `github_require_id` retains the existing actionable missing-guard
failure. Empty or unknown operations remain governed by the existing derived-list checks.

## Verification

- Prove the guard assertion bites with a controlled missing-pattern fault, observe the focused
  tracker fixture fail, then revert the fault.
- Run `just test tracker-test` and require all assertions to pass.
- Run `git diff --check`, `just shape-check`, `just public-safety`, and
  `just version-check`.
- Run `just verify` bare and require exit 0 with no warnings.

## Architecture and guardrails

Host architecture is `x86_64`; the repository declares no target architecture, so the
relationship is `no-target-declared`. `BASE_BRANCH` is `main`. The full local guardrail is
`just verify`; CI invokes the same suite through `just ci`. ADR indexing is not coupled.

See [ADR 0039](../../adr/0039-capture-derived-guard-input-before-search.md).
