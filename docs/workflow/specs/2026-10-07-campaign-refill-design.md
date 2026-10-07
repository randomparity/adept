# Completion-driven campaign refill

Authority: #346, parent #343, operator-approved campaign scope `q346-beb2932a`.
Decision: [ADR0087](../../adr/0087-completion-driven-campaign-refill.md).

## Problem and scope

Campaign's parallel dispatch and uncoupled ADR-index publication use a wave barrier.
Replace that execution barrier in `skills/campaign/SKILL.md`; retain campaign ownership
of eligibility and landing. Shared waits, recovery, review and merge rules keep their
existing owners. No new runner, state machine, manifest column or GitHub experiment.

## Design

A planned `sN` group remains serial and merges before its next row. A fixed `wN` group
records approved membership and bounds index publication; it is not a barrier between
independent execution groups. At each observed completion, reconcile report, artifacts,
worker end and existing row/claim binding once. Record the actual outcome before reuse.
Select the earliest approved independent row in planned order whose existing dependency,
claim, scope and artifact gates pass. A merge-required dependency requires verified merge,
not approval or a finished worker. Retain outstanding/uncertain owners against capacity;
use the minimum of task limit, campaign limit five, and exposed available harness limit.
Cap one executes one eligible independent worker at a time without changing landing gates.

Check scopes against still-active workers and waiting unmerged rows. Overlapping work
stays serial through merge. The only shared edit exceptions are the existing assigned
mandatory edits and coupled ADR-index rows, reconciled at ordered landing. On resume,
reconcile the existing manifest's row/attempt/worker/claim/artifact evidence before counting
capacity or dispatching; missing ownership evidence holds its row and capacity.

Worker completion permits refill before waiting for a slow sibling or a pending merge.
Merge handling remains serial under step 6, with exact-head handshake and assigned order.
Out-of-order completion does not reassign version/ADR reservations. Blocked/skipped rows
retain consumed reservations; only the orchestrator can reassign after the existing scan.

ADR index: absent skips; coupled retains each worker's own gated row. For uncoupled index,
freeze planned finite `wN` membership before dispatch, including undispatched members.
A group closes when its members are merged or explicitly blocked/skipped. Publish only
its merged pending rows once, on a separate branch, retaining membership and publication
identity/outcome in existing notes. An in-flight quiet/uncertain worker does not count as
blocked. A blocked member that later merges goes in a subsequent finite group recorded
before publication. Verify publication before clearing pending rows; reconcile a failed
or ambiguous write on resume. Eligible refill does not await index publication. Draining
includes reporting unpublished rows and the blocker when publication cannot finish.

## Success and evaluation

For the bounded workload, two slots and three independent approved tasks refill task C
after fast B completes while earlier slow A remains active. Baseline/changed conditions
use equivalent jobs and fresh Codex/Claude contexts. Freeze protocol before measurement;
use exclusive per-worker start/end artifacts and native events as available, not coordinator
self-grading. Publish versions/settings, revision, events, outcomes, elapsed, usage and
unknowns; retain failed attempts. Reuse #344 idle/blocker evidence without broad #347 work.
Constructed cases cover cap one, dependency/overlap gates, ordered versions, blocked rows,
uncertain claims, late reports/resume, three index states, exact-head merge and cleanup.

AI-SPEC: campaign operators trigger refill on worker completion; inputs are approved
manifest rows and validated worker/tracker evidence; output is a permitted next dispatch
or named hold. Sources are existing workflow records and actual harness capabilities.
No duplicate ownership, invented completion, premature dependency release or unordered
landing is allowed. Missing evidence holds; unavailable waits/usage are reported. The live
budget is four initial CLI runs of at most 240 seconds each and three workers each, cap two;
no automatic retries. Success is independently observed job overlap and correct reader cases.

## Failure model

- Actors and deployments: operator-authorized campaign coordinators and native workers
  on the tested Codex and Claude surfaces; ordinary GitHub-backed campaign resume.
- Invariants and assets: unique row ownership, existing approvals, bounded capacity,
  merge-required dependencies, scope isolation, ordered reservations, safe cleanup.
- Accepted failure classes: model/service timing and unavailable inner telemetry are
  reported limits; scratch runs establish no general throughput or reliability guarantee.
- Covered elsewhere: shared monitoring #344/ADR0086; recovery quest-log/dispatch-liveness;
  merge-authority changes #308; removed swarm #345; final comparative report #347.

## Trust boundaries

No new input or permission boundary. Existing untrusted reports/tracker text remain evidence,
not authority; campaign validates approval, exact claim binding, current artifacts and merge
head before dependent action. Private timing paths/identities stay outside published evidence.
External mutation experiments and new recovery authority are excluded by the approved scope.
