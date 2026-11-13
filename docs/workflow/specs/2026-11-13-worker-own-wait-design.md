# A worker's own push and CI wait stays in the foreground — #505

## Problem

`references/dispatch-liveness.md` tells its reader to put a wait on durable state into one
bounded background shell operation and never to poll in the foreground. A worker's push (its
pre-push hook runs the full suite) and its CI are waits on durable state, so the paragraph tells
a worker to background them. `skills/deliver/SKILL.md` §3 says the opposite. In the #500 run a
worker backgrounded both waits, ended its turn, and neither completion resumed it. Authority:
WORK:SCOPE `q505-eedaff8e`, whose exclusions record the operator's 2026-11-13 approval of this
approach; light lane, denominator 100 (S).

## Scope

1. In "Waiting mechanics", reword the durable-state paragraph so its audience is a dispatcher
   waiting on workers or on shared state they produce — tracker, branch, or CI state.
2. In that section, state the worker's side: a dispatched worker waiting on its own push or CI
   — even one dispatching workers of its own — runs it in the foreground with a raised timeout
   and does not end its turn while that wait is outstanding, because a background completion is
   not guaranteed to resume a worker whose turn has ended. A call that outlives its timeout may
   still be running, so the worker waits on that same task rather than starting a second copy.
   Point the "A worker's inner tool wait" bullet at that statement.

`skills/deliver/SKILL.md` §3 gains one pointer to it. Excluded: `skills/campaign/SKILL.md` (#506),
harness hooks, and concrete Claude Code wait mechanics, including §3 step 1's polling (an
orchestrator-owned follow-up; operator re-scope, 2026-11-13). No ADR: the operator chose the
approach.

### Failure model

- Actors and deployments: a dispatched quest worker, including one that dispatches its own
  workers, and its dispatcher, in Claude Code or Codex.
- Invariants and assets: a worker's push/CI wait does not leave it idle with no report; the
  dispatcher's background condition wait is unchanged.
- Accepted: a worker that ignores the prose still stalls — prose cannot enforce; the hook option
  is an approved exclusion (WORK:SCOPE `q505-eedaff8e`) with no owner.
- Covered elsewhere: the dispatcher's one probe and hold on a silent worker — this reference's
  "Probe and hold"; campaign's dispatch prompt wording — #506.

## Success

1. The durable-state background-wait paragraph names a dispatcher waiting on workers or shared
   state as its audience.
2. The reference states the worker rule in Scope item 2.
3. The reference carries no harness-specific wait recipe; the inner-tool-wait bullet points to
   the worker statement.
4. `.claude-plugin/plugin.json` version is `7.13.6`.
5. `just verify` and `just plugin-check` pass.

## Validation

- Criteria 1–3 — task-test-not-applicable: reference prose read by a model; anatomy rule 4
  forbids asserting on prose. `just shape-check` still resolves the reference's links.
- Criterion 4 — focused-test: `just version-check`.
- Criterion 5 — focused-test: `just plugin-check`; the pre-push hook's `just ci` run.
