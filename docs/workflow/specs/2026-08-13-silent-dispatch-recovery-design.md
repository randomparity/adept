# Silent dispatch recovery

## Summary

Give every dispatcher a common, fail-closed response when a worker produces no report. The
governing decision is
[ADR 0010](../../adr/0010-centralize-silent-dispatch-recovery.md).

## Requirements traceability

| # | Source | Contract |
|---|---|---|
| 1 | Issue #48 Expected | Every dispatching skill says how long to wait for a report |
| 2 | Issue #48 Expected | Every dispatching skill says whether one re-dispatch is authorized |
| 3 | Issue #48 Expected | Every dispatching skill says what the dispatcher records |
| 4 | Issue #48 Proposed approach | One shared statement prevents four divergent restatements |
| 5 | Issue #48 Expected | `$campaign`'s observed-end-of-run rule is the behavioral model |

## Behavior

Create `references/dispatch-liveness.md` as the single contract used whenever a dispatcher waits
for a worker report:

1. Allow roughly ten minutes of silence before sending a direct, non-destructive probe.
2. Wait through the next normal collection point, up to roughly one more ten-minute interval, for
   the probe response. A reply of any content proves the worker is alive. No reply by that point
   does not prove it ended; retain the wait as a hold and do not re-dispatch. Elapsed time never
   authorizes recovery. The dispatcher that created the wait continues to own the hold, keeps its
   recovery-chain state in the existing run report or ledger, and may drain unrelated work. A
   later valid report completes the held wait; a later harness end notification resumes that same
   chain at artifact reconciliation without refreshing its replacement budget.
3. Only a harness end-of-run notification, or a dispatcher-requested stop followed by that
   notification, proves the run ended.
4. After an observed end with no valid report, enumerate durable reports, tracker state, branch or
   commit state, and worktree changes that the dispatcher can access. Record the disposition of
   each artifact, resolve conflicts or inaccessible evidence, then check once more for a late valid
   report immediately before authorizing at most one replacement dispatch for that wait site. A
   late valid report cancels recovery. An unresolved conflict, inaccessible required artifact, or
   uncertain ownership records an unresolved stop and authorizes no replacement.
5. Record the worker identity, wait site, probe/observation result, hold or recovery outcome, and
   any reconciled artifacts in the dispatcher's existing run report or ledger. Give the original
   and replacement one recovery-chain identifier and record whether that chain's single
   replacement authorization is unused or consumed. The current dispatcher consults that record
   before dispatch. Do not invent a tracker or persistence write where the owning workflow has
   none.

Each affected skill links to the reference at its report-waiting boundary:

- `restock` applies it while collecting evaluation reports, before worktree reclamation.
- `forge` applies it to implementer, task-reviewer, fix-worker, and whole-branch reviewer waits;
  its existing malformed-report retry remains distinct from a silent run.
- `saga` applies it while waiting for the `$gauntlet` report.
- `trial-loop` applies it while waiting for each `$gauntlet` report; its malformed return retry
  remains distinct from a silent run.

`campaign` remains unchanged and continues to own its more detailed tracker-aware contract.

## Error handling

A dispatcher that cannot observe the worker's end does not reclaim its worktree or start a
replacement. Artifact reconciliation is successful only when every accessible durable artifact is
enumerated and dispositioned, required evidence is readable, ownership is known, conflicts are
resolved, and the final report recheck is empty. Otherwise the dispatcher records the unresolved
state and stops without replacement. If the replacement also ends silently, the dispatcher
records the unresolved wait and stops that work unit; the shared contract does not authorize a
second replacement. A valid report that arrives after replacement dispatch is recorded as a race.
If the harness can stop the replacement before its next mutation, do so and reconcile both runs.
If stopping is unsupported, arrives too late, or either run has already mutated durable state,
allow neither run to authorize further dispatch: enumerate and disposition both result sets under
the same fail-closed reconciliation rule. An irreconcilable conflict records an unresolved stop
and explicitly escalates to the operator through the owning workflow's existing report or parked
state; it never chooses a winner implicitly.

## AI-SPEC and evaluation plan

The user is an operator running a dispatching skill. The trigger is a worker that has not returned
the expected report; the input is harness liveness state plus the dispatcher's existing artifacts;
the output is a probe, hold, or one recovered replacement dispatch. Sources are the harness's
direct reply/end notification and durable repository or tracker artifacts. Silence, commit age,
or tracker inactivity must not be presented as proof of death. The fallback is a recorded hold
with no re-dispatch or worktree reclamation. Probing begins after roughly ten quiet minutes and
permits only one replacement, bounding delay and cost. Success means the behavioral cases below
route without duplicate live workers or lost durable work.

Every case is a blocking gate.

- **E1 — Quiet worker is still alive (severity 4).** After about ten silent minutes, the probe
  replies by the next normal collection point, no more than about ten minutes later. Continue
  waiting; do not replace or reclaim.
- **E2 — Probe remains unanswered (severity 4).** No reply arrives by that collection point.
  Record a hold; do not claim death or replace.
- **E3 — End observed, durable work exists (severity 4).** The harness reports the end and a
  branch, report fragment, or worktree change exists. Reconcile it before at most one replacement.
- **E4 — Replacement also ends silently (severity 4).** The first observed end consumed the one
  replacement. Record the unresolved outcome and stop the unit; do not replace again.
- **E5 — Malformed report arrives (severity 4).** A report violates its caller contract. Preserve
  the skill's malformed-return path; do not misclassify it as silence.
- **E6 — Stale or conflicting tracker evidence (severity 4).** Liveness is unknown and the tracker
  has no new event. Treat tracker state as artifact evidence, never proof the worker ended.
- **E7 — Unauthorized destructive recovery (severity 5).** Liveness is unresolved and a worktree
  exists. Do not remove the worktree or overwrite its changes.
- **E8 — Reconciliation cannot complete (severity 4).** An artifact is inaccessible, ownership is
  uncertain, or durable states conflict. Record known artifacts and the unresolved reason; do not
  replace.
- **E9a — Valid report arrives before replacement mutates (severity 4).** Record the race. Stop
  the replacement before mutation, reconcile both results, and authorize no further dispatch.
- **E9b — Replacement stop is late or unsupported (severity 4).** Record the race, disposition
  both result sets, authorize no further dispatch, and escalate an irreconcilable conflict.
- **E10 — Held worker later ends (severity 4).** Enter E2, then receive the harness end
  notification. Continue the same chain at reconciliation with its existing replacement budget.

Repository policy forbids gates that assert on prose. A fresh behavioral reviewer traces
E1–E10
against the shared reference and each call site before and after implementation. “Fresh” means a
separate review agent receives only the frozen charter, current target files, the matrix below,
and the evaluation cases — no authoring transcript, previous verdict, or intended fixes. It must
cite the exact lines satisfying every applicable cell; a blank or contradictory cell fails.

Every wait site requires wait/probe behavior, observed-end proof, one-replacement enforcement,
recording, and reconciliation. Recording locations are:

- `restock` evaluation-worker collection: run report; reconciliation includes worktree ownership.
- `forge` implementer: task ledger.
- `forge` task reviewer: task ledger.
- `forge` fix worker: task ledger.
- `forge` whole-branch reviewer: review ledger.
- `saga` gauntlet reviewer: run report.
- `trial-loop` gauntlet reviewer: run report.

The reviewer evaluates E1–E10 for every applicable row, explicitly marking non-applicable cases
with a reason. The existing `just shape-check` structurally verifies that reference links resolve;
`just verify` covers repository guardrails. Semantic correctness is established by this evidence
matrix and the later independent adversarial branch review, not by a prose-matching gate.

## Non-goals

- No change to `$campaign`'s existing liveness, tracker, or reclamation rules.
- No daemon, timer process, harness API, dependency, or executable helper.
- No generic guarantee that a silent worker has died.
- No prose-sensitive automated test.
- No recovery across a controller restart where the owning workflow has no existing durable
  ledger; the current dispatcher records and owns the chain for the current run.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- The shared contract lives under `references/`; skills link to it with relative paths.
- Existing malformed-report handling remains intact and separate from silence handling.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/dispatch-no-report-48`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.
