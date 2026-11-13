# `$deliver`'s CI poll stays in the foreground and keys on `bucket` — #508

## Problem

`skills/deliver/SKILL.md` §3 step 1 polls with `sleep <interval> && gh pr checks <PR> --json
name,state || true`, backing off 30s to 60s. Claude Code refuses a foreground sleep of about
30 s, steering a worker to a background wait it can stall on (#505). The step reads raw `state`,
not `bucket`, and `|| true` hides a failed call. Authority: WORK:SCOPE `q508-695de191`.

## Scope

1. Rewrite §3 step 1 to state the poll by its properties: each call is foreground, finishes under
   the harness's foreground maximum, leads with no sleep the harness refuses, and reads one
   compact `gh pr checks <PR> --json name,bucket` snapshot. Calls are spaced by pauses the
   harness accepts or by other work in hand, never by a background task the turn ends on.
2. Decide from `bucket`, over every check: any `pending` means not done; once none is pending,
   any `fail` or `cancel` goes to step 2, and `skipping` is not a failure. `no checks reported`
   (exit 1, no JSON) means not yet registered: pending. Any other call yielding no JSON is
   retried once, then the worker stops and reports the `gh` error. The exit code is not the
   verdict, so `|| true` goes.
3. Add one sentence to the worker paragraph of `references/dispatch-liveness.md` "Waiting
   mechanics" naming `$deliver` §3 step 1 as a worker's CI poll, so both give one form.
4. Bump `.claude-plugin/plugin.json` to `7.13.7`.

No ADR: the issue fixes the approach. Exclusions: the WORK:SCOPE set.

### Failure model

- Actors and deployments: a worker running `$deliver` §3 under Claude Code or Codex.
- Invariants and assets: the worker reaches a terminal CI result without ending its turn; a
  failed or cancelled check never reads as pass; a failed `gh` call reads as neither.
- Accepted: a worker ignoring the prose still stalls; the refusal threshold is harness-owned,
  so the step names the property, not a number; no wait form for an already-backgrounded push
  is verified here — reported to the orchestrator as a follow-up.
- Covered elsewhere: the dispatcher's condition wait — `references/dispatch-liveness.md` (#505);
  a check that never finishes — the workflow's own job timeout.

## Success

1. §3 step 1 states Scope item 1's properties, with no leading `sleep` chain.
2. §3 step 1 decides as in Scope item 2, with no `|| true`.
3. The dispatch-liveness worker paragraph gains exactly Scope item 3's sentence.
4. `.claude-plugin/plugin.json` version is `7.13.7`.
5. `just verify` and `just plugin-check` pass.

## Validation

- Criteria 1–3 — task-test-not-applicable: prose read by a model; anatomy rule 4 forbids
  asserting on prose. The pointer is plain text, not a link no gate checks.
- Criterion 2 inputs — focused-test, observed 2026-11-13: `gh pr checks 509 --json name,bucket`
  gives a `bucket` per check; `gh pr checks 1 ...` gives `no checks reported`, exit 1.
- Criterion 4 — focused-test: `just version-check`.
- Criterion 5 — focused-test: `just plugin-check`; the pre-push hook's `just ci` run.
