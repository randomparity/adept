# `$deliver`'s CI poll stays in the foreground and keys on `bucket` — #508

## Problem

`skills/deliver/SKILL.md` §3 step 1 polls with `sleep <interval> && gh pr checks <PR> --json
name,state || true`, backing off 30s to 60s. Claude Code refuses a foreground command leading
with a sleep of about 30 s (#508), steering a worker to a background wait it can end its turn
on and stall (#505). The step decides from raw `state`, not the documented `bucket`, and
`|| true` hides a failed call. Authority: WORK:SCOPE `q508-695de191`; light lane, S (100).

## Scope

1. Rewrite §3 step 1 to state the poll by its properties: each call is foreground, finishes under
   the harness's foreground maximum, leads with no sleep the harness refuses, and reads one
   compact `gh pr checks <PR> --json name,bucket` snapshot. Pacing between calls uses only
   pauses the harness accepts or other work in hand, never a background task the turn ends on.
2. Decide from `bucket`: done means no check has bucket `pending`; a required check in `fail` or
   `cancel` fails; `skipping` keeps the existing expected-skip wording. The exit code (8 while
   pending) is not the verdict, and a snapshot that does not parse is a failed call, not a
   pending run — so `|| true` goes.
3. Add one sentence to the worker paragraph of `references/dispatch-liveness.md` "Waiting
   mechanics" pointing a worker's CI poll at `$deliver` §3 step 1, so both name one form.
4. Bump `.claude-plugin/plugin.json` to `7.13.7`.

No ADR: the issue fixes the approach. Exclusions are the WORK:SCOPE set (operator, 2026-11-13).

### Failure model

- Actors and deployments: a dispatched or interactive worker running `$deliver` §3 under
  Claude Code or Codex; `gh` with `--json bucket` support.
- Invariants and assets: the worker reaches a terminal CI result without ending its turn; a
  failed or cancelled required check never reads as pass; a failed `gh` call never reads as
  pending.
- Accepted: a worker that ignores the prose still stalls (prose cannot enforce); the exact
  refusal threshold is harness-owned and may change, so the step names the property, not a
  number.
- Covered elsewhere: waiting on an already-backgrounded push — deferred follow-up candidate;
  the dispatcher's condition wait — `references/dispatch-liveness.md` (#505).

## Success

1. §3 step 1 states the four call properties in Scope item 1 and no leading `sleep` chain.
2. §3 step 1 polls `--json name,bucket` and decides as in Scope item 2, with no `|| true`.
3. The dispatch-liveness worker paragraph gains exactly one sentence pointing at §3 step 1.
4. `.claude-plugin/plugin.json` version is `7.13.7`.
5. `just verify` and `just plugin-check` pass.

## Validation

- Criteria 1–3 — task-test-not-applicable: prose read by a model; anatomy rule 4 forbids
  asserting on prose. `just shape-check` still resolves the new link.
- Criterion 2 field — focused-test: `gh pr checks 509 --json name,bucket` returns a `bucket`
  per check, observed 2026-11-13.
- Criterion 4 — focused-test: `just version-check`.
- Criterion 5 — focused-test: `just plugin-check`; the pre-push hook's `just ci` run.
