# Observed end on a harness that notifies on turn end — #500

## Problem

`references/dispatch-liveness.md` says a native agent's end-of-run notification proves the worker
ended. Some harnesses send the same completion notification when a worker's turn ends, while it
is idle and still resumable, so a dispatcher cannot tell which happened. Claim recovery, the one
replacement, and worktree reclamation in campaign, restock and forge all key on observed end, and
campaign and restock restate the old test locally. Authority: WORK:SCOPE `q500-05440895`
(re-frozen on the operator's option A); light lane, denominator 100 (S).

## Scope

1. Rewrite the first sentence of "Observed end and reconciliation". The notification, or a
   requested stop followed by it, proves an end only where the harness's end-of-run notification
   is distinct from its turn-end one. Where it is not, or the dispatcher cannot establish that it
   is, a completion notification alone is not an observed end, even carrying a final report;
   the observed end is an explicit stop through the harness's stop control plus that control's
   own success result for this worker. A stop without that result proves nothing. The dispatcher
   issues the stop only where its workflow would otherwise act on the end — after reconciling the
   final report, or under a stop authority the workflow already grants — never to settle a hold.
2. Replace the three local definitions — campaign's step-5 re-dispatch sentence, campaign's
   cleanup "What counts" sentence, restock's prior-manifest parenthetical — with a pointer to that
   section. Nothing else in those files changes; forge already only links.

The receipt section's idle-notification sentence stays as written and is not repeated. No
ownership transition beyond the three pointers. No ADR: the stop path already exists; this
tightens its evidence, and no viable alternative changes the decision.

### Failure model

- Actors and deployments: a dispatching model in Claude Code or Codex reading worker
  notifications.
- Invariants and assets: on a non-distinguishing harness, a resumable worker's worktree, branch
  and claim are not reclaimed or replaced on a completion notification alone.
- Accepted: a stop for a worker whose final report was already reconciled but which had already
  ended — one tool call.
- Covered elsewhere: a harness with no stop capability — existing recovery rules (the end stays
  unobserved and the unit holds); the one-replacement authorization — unchanged.

## Success

1. The section limits the notification test to harnesses that distinguish turn end from run end.
2. Elsewhere it requires an explicit stop plus the stop control's success result, and bounds when
   the stop may be issued.
3. The three named local definitions point to the section; the receipt sentence is not repeated.
4. `.claude-plugin/plugin.json` version is `7.13.1`.

## Validation

- Criteria 1–2 — task-test-not-applicable: reference prose read by a model; anatomy rule 4
  forbids asserting on prose.
- Criterion 3 — focused-test: `just shape-check` resolves the new relative links.
- Criterion 4 — focused-test: `just version-check`.
