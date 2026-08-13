# Implementation plan: terminal pull-request state before mergeability

**Goal.** Make `$return-to-town` immediately recognize an already-merged pull request before
consulting lazily computed mergeability fields.

**Architecture.** This is an instruction-only contract change in the existing
`return-to-town` skill. One explicit-field GitHub snapshot supplies terminal state and the
existing check data; lifecycle state controls whether computed mergeability is relevant.

**Tech stack.** Markdown skill contract, GitHub CLI examples, `just verify`.

**Design:** `docs/workflow/specs/2026-08-13-terminal-pr-state-design.md`.
**Decision:** `docs/adr/0009-terminal-pr-state-precedes-mergeability.md`.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- The implementation file is `skills/return-to-town/SKILL.md`.
- GitHub reads use explicit JSON fields.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/merged-state-first-76`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.

## File map

| File | Responsibility |
|---|---|
| `skills/return-to-town/SKILL.md` | Status snapshot, terminal-state ordering, and entry into post-merge cleanup |

## Task 1 — Order terminal state before mergeability

**Files:** modify `skills/return-to-town/SKILL.md`.

**Interfaces:** consumes pull-request fields `state`, `mergedAt`, `mergeable`,
`mergeStateStatus`, and `statusCheckRollup`. Produces one of three outcomes: merged cleanup,
closed-unmerged stop, or the existing open-PR green/mergeable evaluation. No later task
consumes a new code interface.

### Step 1.1 — Establish the failing behavioral review

Give a fresh, read-only reviewer the unchanged skill and the specification's V1 packet.

Expected: fail. The current contract does not require querying `state` or `mergedAt` before
computed fields and therefore cannot guarantee immediate cleanup for V1.

### Step 1.2 — Add the minimal terminal-state contract

In `skills/return-to-town/SKILL.md`, add the explicit status snapshot:

```sh
gh pr view <N> \
  --json state,mergedAt,mergeable,mergeStateStatus,statusCheckRollup \
  --jq '{state, mergedAt, mergeable, mergeState: .mergeStateStatus,
         checks: [.statusCheckRollup[] | {name, status, conclusion}]}'
```

Require branching on `state` before computed fields: `MERGED` proceeds directly to tracking
and cleanup, `CLOSED` stops without cleanup, and only `OPEN` evaluates or polls
`mergeable`/`mergeStateStatus`. Keep the existing merge authorization and cleanup sequence.

### Step 1.3 — Re-run focused behavioral review

Give a fresh, read-only reviewer the changed skill and fixed packets V1, V1b, V2, and V3
from the spec.

Expected: all pass. V1 performs no poll, V2 preserves open-PR behavior, and V3 performs no
post-merge cleanup.

Run `just shape-check`, `just public-safety`, and `git diff --check`.

Expected: every command exits 0.

Commit explicit path `skills/return-to-town/SKILL.md` with:
`fix: check terminal PR state before mergeability`.

## Task 2 — Whole-change verification

**Files:** no planned edits; accepted review fixes may change only
`skills/return-to-town/SKILL.md` and the unmerged design artifacts.

**Interfaces:** consumes the completed contract and produces branch-review and guardrail
evidence.

### Step 2.1 — Trace scope and review the branch

Read issue #76's latest complete `WORK:SCOPE` annotation and verify token
`8E015A61-A363-4098-9F86-55305B0BC22D`. Map all three criteria to the current skill, then run
an independent adversarial whole-diff review against `main`. Resolve every defensible finding;
commit each accepted fix separately.

Expected: every criterion maps to explicit contract text and no implementation file lies
outside the frozen surface.

### Step 2.2 — Run full guardrails

Run `just verify` bare, followed by `git diff --check` and
`git status --short --untracked-files=all`.

Expected: all commands exit 0; status contains only intentional, committed branch changes.

### Step 2.3 — Rollback and cleanup

The change is instruction-only and reverts with its commits. Do not commit `.agent/` review
artifacts. If a behavioral review attempts a live GitHub mutation, stop it; the packets are
read-only hypothetical inputs.
