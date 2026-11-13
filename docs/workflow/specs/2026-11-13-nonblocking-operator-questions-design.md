# Non-blocking operator questions in `$campaign` — #506

## Problem

`$campaign` says an operator question holds one row while the queue keeps draining, but the
orchestrator asks through a blocking prompt: worker messages queue undelivered, ready rows wait
unmerged, and the answer is acted on against stale state.
Authority: WORK:SCOPE `q506-2f5c84c7`; light lane, denominator 250 (M).

## Scope

One new paragraph in `skills/campaign/SKILL.md`, placed after **Single continuous task**:

1. A question the queue can continue past is asked without blocking: the question goes in the
   run output, the affected row is held in the manifest, and the orchestrator returns to its
   event wait, so worker messages and the operator's reply both arrive as events. The blocking
   form is kept only where every remaining row depends on the answer. The two completion-note
   questions in step 1 come before any queue exists, so they meet that test and stay as written.
2. Before acting on any operator answer, reconcile the affected row's durable state: its
   tracker, branch and PR head, and latest `WORK:` annotations. A queued worker message may not
   have arrived yet.
3. An optional addition to a live row is asked after its hand-off, as a follow-up candidate,
   unless the operator wants the row to wait for the answer.

Sites that ask the operator point at that paragraph instead of implying a blocking ask: the
single-continuous-task paragraph, step 3's convention-only branch reuse question, step 4's split
decision, step 5's held decision and in-flight hold, and step 6's merge hold. The merge hold's
existing `mergeStateStatus` re-check becomes one instance of rule 2. No ownership transition: the
skill already owns its question discipline, and no caller changes. `.claude-plugin/plugin.json`
moves to `7.13.5`.

### Failure model

- Actors and deployments: the campaign orchestrator model in a Claude Code or Codex session,
  with worker agents and one operator.
- Invariants: no row is merged, dispatched or closed on a stale answer; no unaffected row waits
  on a question.
- Accepted: a harness with no way to ask without blocking forces the blocking form; the rule
  then reduces to rule 2's reconciliation, as the excluded harness mechanism owns the rest.
- Accepted: nothing mechanically checks that a question was asked without blocking — anatomy
  rules 3 and 4 exclude hook or prose enforcement.
- Covered elsewhere: worker turn-end on its own background wait and `dispatch-liveness.md`
  (#505).

## Success

1. The skill states rule 1, including the event-wait return and the all-rows-depend exception.
2. Each of the six named sites is consistent with rule 1 and points to it.
3. The skill states rule 2 for every operator answer, naming the three state sources.
4. The skill states rule 3 with its operator-wait exception.
5. `.claude-plugin/plugin.json` version is `7.13.5`.

## Validation

- Criteria 1–4 — task-test-not-applicable: instruction prose with no executable consumer;
  anatomy rule 4 forbids asserting on it.
- Criterion 5 — focused-test: `just version-check` passes on `7.13.5`.
- Structure — focused-test: `just verify` keeps `check-skill-shape.sh` and link checks green.
