# Reconcile merge-precondition wording and deterministic guard validation

**Goal.** Bring the skill contracts into alignment with ADR 0035 and make the tracker fixture's
derived issue-selector guard check deterministic.

**Architecture.** Documentation retains separate hand-back and merge-authorization contracts.
The fixture captures producer output before searching it, as decided by ADR 0039. The stack is
Markdown and Bash 3.2.

## Global Constraints

- `BASE_BRANCH` is `main`; the branch is `feat/reconcile-merge-precondition-243`.
- Bash 3.2 is the floor; use tabs, `set -euo pipefail`, and no associative arrays.
- No automated gate asserts on normative prose.
- Do not change tracker runtime behavior, `$return-to-town`, or `$deliver`'s tracking-write
  condition.
- Run `just verify` bare before each implementation commit.

## Task 1: Make the derived guard assertion deterministic

**Files:** modify `tests/fixtures/quest-log/tracker-test.sh`.

The design record for this task is
`docs/adr/0039-capture-derived-guard-input-before-search.md`; it must exist before the first
full guardrail run.

**Interfaces:** consumes `PROFILE_DECLARES`, `profile_<operation>` function definitions, and
`github_require_id`; produces the existing pass/fail assertion for every non-exempt operation.

1. Replace the `declare -f | rg -q` pipeline with a command substitution that captures the
   complete definition in `definition`. If capture fails, call `fail` with
   `github's profile_<operation> could not be inspected`.
2. Search `definition` for `github_require_id`; retain the existing missing-guard message.
3. Temporarily change `declare -f "profile_$op"` to
   `declare -f "profile_${op}_missing"`, run `just test tracker-test`, and require
   `github's profile_view could not be inspected`. Revert only that controlled fault.
4. Temporarily change the searched pattern to a nonexistent guard, run
   `just test tracker-test`, and require nonzero exit plus
   `github's profile_view takes an issue selector but never calls github_require_id`.
   Revert only that controlled pattern fault.
5. Run `just test tracker-test`; expect `tracker-test: all assertions passed` and exit 0.
6. Run `just verify`; expect exit 0, then commit as
   `test: make tracker guard scan deterministic`.

**Acceptance:** producer failure and missing-guard failure are distinct; the derived operation
coverage remains intact; no production tracker file changes.

## Task 2: Reconcile the documented merge states

**Files:** modify `skills/deliver/SKILL.md`, `skills/quest-log/SKILL.md`, and
`.claude-plugin/plugin.json`.

**Interfaces:** consumes accepted ADR 0035's four-part commit-bound gate; produces the
`$deliver` hand-back contract and the `status:awaiting-merge` label description.

1. Name `$deliver`'s green-plus-mergeable exit as hand-back and state that ADR 0035 separately
   governs merge authorization, including its author handshake.
2. State that `status:awaiting-merge` requires green, mergeable state plus the recorded
   commit-bound author handshake.
3. Bump `.claude-plugin/plugin.json` from `2.10.0` to `2.10.1`.
4. Run `git diff --check`, `just shape-check`, `just public-safety`, and
   `just version-check`; expect exit 0.
5. Run `just verify`; expect exit 0, then commit as
   `docs: distinguish hand-back from merge authorization`.

**Acceptance:** every issue criterion is visible in the three-file diff, no prose gate is added,
and the full guardrail passes.

## Final verification and cleanup

Run `git diff --check` and `just verify` bare. Confirm only the chartered files plus this spec,
ADR, and plan differ from `main`; keep the ignored Forge ledger and review artifacts private.
