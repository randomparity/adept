# A worker's own push and CI wait stays in the foreground — #505

## Problem

`references/dispatch-liveness.md` tells its reader to put a wait on durable state into one
bounded background shell operation and never to poll in the foreground. A worker's push (its
pre-push hook runs the full suite) and its pull request's CI are waits on durable state, so a
worker reading the paragraph is told to background them. `skills/deliver/SKILL.md` §3 says the
opposite: long commands run in the foreground, CI is polled with compact foreground snapshots,
and a worker never ends a turn waiting on a completion notification. In the #500 run a worker
backgrounded both waits, ended its turn, and was not resumed by either completion. Authority:
WORK:SCOPE `q505-eedaff8e`; light lane, denominator 100 (S).

## Scope

1. In "Waiting mechanics", reword the durable-state paragraph so its audience is a dispatcher
   waiting on workers or on shared state they produce — tracker, branch, or CI state — rather
   than any reader.
2. In the same place, state the worker's side: a worker waiting on its own push or CI runs the
   command in the foreground with a raised timeout, polls CI the way `$deliver` §3 does, and does
   not end its turn while that wait is outstanding, because a background task's completion is not
   guaranteed to resume a worker whose turn has ended. Point the "A worker's inner tool wait"
   bullet at that sentence rather than restating it.

No change to `skills/deliver/SKILL.md` (it already states the worker rule), to
`skills/campaign/SKILL.md` (#506), or to harness hooks (excluded). No ADR: the operator chose the
approach; there is no remaining decision with alternatives.

### Failure model

- Actors and deployments: a dispatched quest worker and its dispatcher, in Claude Code or Codex.
- Invariants and assets: a worker's push/CI wait does not leave it idle with no report; the
  dispatcher's background condition wait is unchanged.
- Accepted: a worker that ignores the prose still stalls — prose cannot enforce; the hook option
  is an approved exclusion with no owner.
- Covered elsewhere: the dispatcher's one probe and hold on a silent worker — this reference's
  "Probe and hold"; campaign's dispatch prompt wording — #506.

## Success

1. The durable-state background-wait paragraph names a dispatcher waiting on workers or shared
   state as its audience.
2. The reference states that a worker waits on its own push and CI in the foreground with a
   raised timeout and does not end its turn while that wait is outstanding.
3. The inner-tool-wait bullet refers to that statement rather than restating it.
4. `.claude-plugin/plugin.json` version is `7.13.4`.

## Validation

- Criteria 1–3 — task-test-not-applicable: reference prose read by a model; anatomy rule 4
  forbids asserting on prose. `just shape-check` still resolves the reference's links.
- Criterion 4 — focused-test: `just version-check`.
