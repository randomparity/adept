# Implementation plan: silent dispatch recovery

**Goal.** Give every dispatcher named by issue #48 one shared, fail-closed response when a
worker never returns its report.

**Architecture.** A neutral reference owns the complete liveness, reconciliation, retry-budget,
and recording contract. The four consumer skills link to it at their concrete report-wait sites
and state which existing report or ledger carries the required recovery-chain record.

**Tech stack.** Markdown skill contracts, fresh-agent behavioral evaluation, `just verify`.

**Design:** `docs/workflow/specs/2026-08-13-silent-dispatch-recovery-design.md`.
**Decision:** `docs/adr/0010-centralize-silent-dispatch-recovery.md`.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- The shared contract lives under `references/`; skills link to it with relative paths.
- Existing malformed-report handling remains intact and separate from silence handling.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/dispatch-no-report-48`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.

## File map

| File | Responsibility |
|---|---|
| `references/dispatch-liveness.md` | Canonical silent-worker and recovery contract |
| `skills/restock/SKILL.md` | Evaluation-report waits and worktree reclamation |
| `skills/forge/SKILL.md` | Party worker waits and progress-ledger recording |
| `skills/saga/SKILL.md` | Apply the contract to its one-pass gauntlet review and run report |
| `skills/trial-loop/SKILL.md` | Gauntlet waits, separate from malformed returns |

## Pre-implementation scope check

Run `git branch --show-current` and `git status --short --untracked-files=all`. Require branch
`feat/dispatch-no-report-48` and no changes outside committed design artifacts. Then run:

```sh
gh issue view 48 --json comments \
  --jq '[.comments[].body | select(test("(?m)^<!-- WORK:SCOPE -->$") and
    test("(?m)^<!-- SCOPE:COMPLETE -->$"))] | last'
```

Require token `scope-48-20260813T1500Z-a81d6c2e`. Stop on a branch, ownership, or token
mismatch.

## Task 1 — Define and adopt the shared recovery contract

**Files:** create `references/dispatch-liveness.md`; modify `skills/restock/SKILL.md`,
`skills/forge/SKILL.md`, `skills/saga/SKILL.md`, and `skills/trial-loop/SKILL.md`.

**Interfaces:** each consumer links to `../../references/dispatch-liveness.md` and supplies its
worker identity, wait-site name, existing run report or ledger, accessible durable artifacts, and
harness liveness events. The reference returns one of: continue waiting, recorded hold, completed
valid report, one reconciled replacement, or unresolved stop. Later phases in the current run rely
on the recorded recovery-chain identifier and unused/consumed replacement budget.

### Step 1.1 — Establish the failing behavioral evaluation

Dispatch a fresh read-only evaluator with only the frozen charter, the current four skill files,
the current `references/dispatch-liveness.md` or an explicit `absent` marker, and the spec's
E1–E10 cases and wait-site matrix. Use a fresh run identifier in the output filename and require
the evaluated `HEAD` in the top-level JSON. Require rows with these fields:

```json
{
  "wait_site": "string",
  "wait_probe_lines": [],
  "observed_end_lines": [],
  "one_replacement_lines": [],
  "recording_lines": [],
  "reconciliation_lines": [],
  "cases": {"E1": "pass|fail|not-applicable"},
  "pass": false
}
```

The evaluator must cite exact file and line references, explain every `not-applicable`, fail any
blank or contradictory required cell, and write its output to ignored
`.agent/evals/issue-48-before-<run-id>.json`. It receives no authoring transcript, earlier verdict,
or intended fix. Before consuming it, require its run identifier and evaluated `HEAD` to match the
current run and pre-implementation commit.

Expected: fail. `restock` and `saga` have no no-report path; `forge` covers only one missing final
review file and does not apply the contract to every dispatched worker; `trial-loop` retries a
malformed return but does not define silent-run liveness or recovery.

### Step 1.2 — Write the canonical reference

Create `references/dispatch-liveness.md` with these sections and guarantees:

- **When to probe:** roughly ten silent minutes; wait through the next normal collection point,
  no more than roughly ten further minutes. A response proves liveness; silence proves nothing.
- **Hold ownership:** the dispatcher owns the held chain, records it in the existing run report or
  ledger, may drain unrelated work, and resumes the same chain on a late report or harness end.
- **Observed end:** only a harness end notification, or dispatcher stop followed by that
  notification, authorizes recovery.
- **Reconciliation:** enumerate and disposition accessible reports, tracker state, branch/commit
  state, and worktree changes; resolve ownership/conflicts; perform a final late-report check.
  Inaccessible required evidence or unresolved state stops without replacement.
- **One replacement:** record a recovery-chain identifier and unused/consumed budget; the current
  dispatcher consults it before replacement; at most one follows successful reconciliation.
- **Late report:** cancel pre-dispatch recovery; after dispatch, stop before mutation when possible,
  otherwise disposition both result sets and escalate an irreconcilable conflict without another
  dispatch.
- **Record:** worker, wait site, observations, hold/recovery outcome, artifacts and dispositions,
  chain identifier, and budget state. Use the owning workflow's existing report/ledger; add no
  tracker write merely for this reference.

Keep the reference independent of campaign-specific labels and worktree locations.

### Step 1.3 — Wire every current wait site

Add short application paragraphs rather than duplicating the reference:

- In `restock`, place the link before “Once every subagent has reported.” Name each evaluation
  unit as a wait site and retain its chain state for the current run before a hold or replacement.
  Use Phase 3 worktrees/PR heads as the reconciliation surface. Forbid Phase 3c reclamation while
  liveness is unresolved; Phase 5 includes the chain state in the final report.
- In `forge`, place the link in Party before the per-task loop. Enumerate implementer,
  task-reviewer, fix-worker, and whole-branch reviewer waits. Use `.agent/sdd/progress.md` as the
  ledger, and record chain/budget lines before replacement. Replace the existing final-review
  “silent failure” blind retry with the shared contract; keep `WRITE_FAILED`, `PACKAGE_MISSING`,
  and malformed or non-empty-file validation as first-return error paths.
- In `saga`, place the link at the one-pass gauntlet dispatch. Retain the chain state for the
  current run before any hold or replacement and include it in the challenge summary. Use the
  draft/findings artifacts as reconciliation evidence. If liveness cannot be resolved, stop before
  confirmation or tracker writes and report the held chain.
- In `trial-loop`, place the link immediately before the gauntlet subagent dispatch. Explicitly
  separate “no report/end observed” from step 2's malformed compact-object retry. Retain chain
  state for the current run before a hold or replacement. Use the findings path/run ID as
  reconciliation evidence and carry the chain result into the loop's run report.

### Step 1.4 — Re-run the behavioral evaluation

Dispatch a different fresh evaluator with exactly the Step 1.1 input bundle and schema, now
against the changed files including `references/dispatch-liveness.md`. Write
`.agent/evals/issue-48-after-<run-id>.json`; verify its run identifier and evaluated `HEAD` before
consuming it.

Expected: every required matrix cell cites exact lines; E1–E10 pass for every applicable wait
site; no consumer contradicts the shared reference; malformed-report paths remain distinct.

Run `just shape-check`, `just public-safety`, and `git diff --check` bare.

Expected: every command exits 0. `shape-check` proves all new relative links resolve; it does not
claim to prove prose semantics.

Commit the five implementation paths with
`fix: handle silent dispatch workers`.

## Task 2 — Whole-change verification

**Files:** no planned edits; accepted review fixes may modify only the five implementation files
and the unmerged design artifacts.

**Interfaces:** consumes the completed shared contract and consumer links; produces independent
review evidence and the repository guardrail result.

### Step 2.1 — Recheck scope and behavior

Read issue #48's latest complete `WORK:SCOPE` and require token
`scope-48-20260813T1500Z-a81d6c2e`. Map each completion criterion to exact current lines. Compare
the changed consumer inventory to the spec matrix; a missing wait site is a blocking gap.

Run an independent adversarial branch review against `main`, including late reports, held-wait
continuation, inaccessible artifacts, replacement-budget reuse, and worktree reclamation. Resolve
every defensible finding and commit each accepted fix separately.

After the final accepted review fix, dispatch another fresh behavioral evaluator with the Step 1.1
bundle and schema against the final `HEAD`. Require a fresh run identifier, matching evaluated
`HEAD`, complete matrix, and passing E1–E10 results before full guardrails.

Expected: all criteria and matrix rows have evidence; no implementation path lies outside the
frozen surface.

### Step 2.2 — Run full guardrails

Run `just verify` bare, followed by `git diff --check` and
`git status --short --untracked-files=all`.

Expected: all commands exit 0; status contains only intentional committed branch changes.

### Step 2.3 — Rollback and cleanup

The change is instruction-only and reverts with its commits. Do not commit `.agent/` evaluation
or review artifacts. After reporting their run identifiers, evaluated commits, and verdicts, move
the run-specific evaluation artifacts to trash. If an evaluator attempts a repository, tracker,
or worktree mutation, stop it; all E1–E10 inputs are hypothetical and read-only.
