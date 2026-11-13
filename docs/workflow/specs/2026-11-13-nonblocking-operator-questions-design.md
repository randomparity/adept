# Non-blocking operator questions in `$campaign` — #506

## Problem

`$campaign` says an operator question holds one row while the queue keeps draining, but the
orchestrator asks through a blocking prompt: worker messages queue undelivered, ready rows wait
unmerged, and the answer is acted on against stale state.
Authority: WORK:SCOPE `q506-2f5c84c7`; light lane, denominator 250 (M).

## Scope

One new paragraph in `skills/campaign/SKILL.md`, after **Single continuous task**, governing
every operator question the orchestrator asks:

1. A question the queue can continue past is asked without blocking: it goes in the run output
   naming its issue and the decision asked, the row is held by its site's existing mechanism,
   and the orchestrator returns to its event wait, so worker messages and the reply arrive as
   events. The issue's "held in the manifest" example is met by those mechanisms: no new Queue
   status or column, and only step 5's decision receipt keeps a private record. The blocking
   form is kept only where every remaining row depends on the answer — for example step 1's
   completion notes or step 4's first plan confirmation.
2. An answer is acted on only when it applies unambiguously to exactly one open question;
   otherwise re-ask, listing the open questions. Before acting, reconcile that row's durable
   state from whichever sources exist: tracker, branch, PR head and merge state, latest `WORK:`
   annotations. If that state undermines the question — the row handed off, merged, closed or
   moved past the decision — re-present it instead of acting; ordinary progress does not.
3. An optional addition to a live row is asked after its hand-off, as a follow-up candidate,
   unless the operator wants the row to wait.

Six sites point at that paragraph: single continuous task, step 3's convention-only branch
reuse, step 4's split decision, step 5's held decision and in-flight hold, and step 6's merge
hold, whose `mergeStateStatus` re-check becomes an instance of rule 2. No caller or ownership
changes. `.claude-plugin/plugin.json` moves to `7.13.5`.

### Failure model

- Actors and deployments: the campaign orchestrator model in a Claude Code or Codex session,
  with worker agents and one operator.
- Invariants: no row is merged, dispatched or closed on a stale or misattributed answer; no
  unaffected row waits on a non-blocking question.
- Accepted: a harness with no non-blocking ask forces the blocking form; rule 2 still applies.
- Accepted: nothing mechanically checks how a question was asked (anatomy rules 3 and 4).
- Covered elsewhere: worker turn-end on its own background wait and `dispatch-liveness.md`
  (#505).

## Success

1. The skill states rules 1–3 as written above.
2. The six named sites point to the paragraph and none implies a blocking ask.
3. `.claude-plugin/plugin.json` version is `7.13.5`.

## Validation

- Criteria 1–2 — task-test-not-applicable: prose with no executable consumer (anatomy rule 4).
- Criterion 3 — focused-test: `BASE_SHA=$(git merge-base origin/main HEAD) just version-check`
  is red at the base version and green after the bump; `jq -r .version` reads `7.13.5`.
- Structure — guardrail, not focused evidence: `just verify`.
