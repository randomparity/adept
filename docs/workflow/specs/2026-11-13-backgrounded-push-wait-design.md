# A worker's wait on a backgrounded push is a contract, not a recipe — #511

## Problem

The worker paragraph of `references/dispatch-liveness.md` "Waiting mechanics" says a call
that outlives its timeout may still be running, so the worker waits on that same task. It
gives no form for that wait and does not say whether the omission is deliberate. A worker
whose pre-push hook the harness backgrounded (#508's step 8) has to improvise. Authority:
WORK:SCOPE `q511-1892f1a9`, operator option (a): record "no recipe".

## Scope

1. Extend the worker paragraph with the contract for a call the harness has backgrounded:
   one bounded foreground call keeps checking that same task's completion; the worker never
   ends its turn on the task; it never starts a second push; an unfinished or inconclusive
   wait counts as no passing result, as `$deliver` §2's push step already says of a hook.
2. In the same paragraph, state that the reference deliberately documents no
   harness-specific wait recipe, because output-file paths and backgrounding thresholds are
   harness-assigned and cannot be verified from this repository, and because in #505 every
   written recipe failed review.
3. The paragraph names no output-file path, until-loop, timeout number, or Monitor usage,
   and does not prescribe `bounded_call`, which cannot attach to an already-backgrounded task.
4. `skills/deliver/SKILL.md` §2's push step gains one link to that paragraph and none of its
   text.
5. Bump `.claude-plugin/plugin.json` to `7.13.8`.

No ADR: the operator fixed the decision; it is recorded in the reference itself.

### Failure model

- Actors and deployments: a dispatched worker running `$deliver`'s push under Claude Code or
  Codex, whose push call the harness backgrounds.
- Invariants and assets: one push per candidate; the worker's turn stays open until the push
  ends; no unfinished hook reads as a pass.
- Accepted: a worker that cannot express a bounded check in its harness stays unhelped beyond
  the contract — stating a form is excluded; a worker ignoring the prose still stalls.
- Covered elsewhere: the dispatcher's background wait (same reference, excluded); the CI poll
  (`$deliver` §3 step 1, #508).

## Success

1. The worker paragraph states Scope item 1's four obligations.
2. It states Scope item 2's decision and both reasons.
3. It contains none of the items Scope item 3 names.
4. `$deliver` §2's push step carries exactly one added link to the paragraph, with no copied
   obligation text.
5. `.claude-plugin/plugin.json` version is `7.13.8`.
6. `just verify` and `just plugin-check` pass.

## Validation

- Criteria 1–4 — task-test-not-applicable: prose read by a model; anatomy rule 4 forbids
  asserting on prose. The link's file is held by `check-skill-shape.sh` rule 5; its anchor is checked by reading.
- Criterion 5 — focused-test: `just version-check`.
- Criterion 6 — focused-test: `just plugin-check`; the pre-push hook's `just ci` run.
