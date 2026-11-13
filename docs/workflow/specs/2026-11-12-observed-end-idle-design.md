# Observed end on a harness that notifies on turn end — #500

## Problem

`references/dispatch-liveness.md` says a native agent's end-of-run notification proves the worker
ended. Some harnesses send the same completion notification when a worker's turn ends, while it
is idle and still resumable, so a dispatcher cannot tell which happened. Claim recovery, the one
replacement, and worktree reclamation in campaign, restock and forge all key on observed end, and
campaign and restock restate the old test locally. Authority: WORK:SCOPE `q500-05440895`
(re-frozen on operator options A and A2); light lane, denominator 100 (S).

## Scope

1. Rewrite the first sentence of "Observed end and reconciliation". The notification, or a
   requested stop followed by it, proves an end only where the harness tells a turn end from a
   run end, by notification or run-state. Elsewhere, or when the dispatcher cannot establish
   that, a completion notification alone is not an observed end, even carrying a final report;
   the observed end is an explicit stop through the harness's stop control plus that control's
   result stating the stop succeeded or this worker is no longer running. Any other result proves
   nothing. The dispatcher stops only after reconciling the final report or under a stop
   authority its workflow grants, such as campaign's operator-directed re-dispatch.
2. Replace the four local definitions — campaign's step-5 re-dispatch and cleanup "What counts"
   sentences, restock's prior-manifest and step-3c parentheticals — with a pointer to that
   section. Nothing else there changes; forge already only links.

The receipt section's idle-notification sentence stays as written and is not repeated. No
ownership change beyond the four pointers. No ADR: ADR 0010 already places this test
in the shared reference to evolve there.

### Failure model

- Actors and deployments: a dispatching model in Claude Code or Codex reading worker
  notifications.
- Invariants and assets: on a non-distinguishing harness, a resumable worker's worktree, branch
  and claim are not reclaimed or replaced on a completion notification alone.
- Accepted: a stop for a worker whose final report was already reconciled but which had already
  ended — one tool call.
- Accepted: on such a harness, a silent held worker with no granted stop stays a hold until a
  late report or an operator stop — the existing hold rule, not a new state.
- Covered elsewhere: a harness with no stop capability — existing recovery rules (the unit holds);
  the one-replacement authorization — unchanged.

## Success

1. The section limits the notification test to harnesses that distinguish turn end from run end.
2. Elsewhere it requires an explicit stop plus a succeeded or not-running stop result, and
   bounds when the stop may be issued.
3. The four named local definitions point to the section; the receipt sentence is not repeated.
4. `.claude-plugin/plugin.json` version is `7.13.1`.

## Validation

- Criteria 1–2 — task-test-not-applicable: reference prose read by a model; anatomy rule 4
  forbids asserting on prose.
- Criterion 3 — focused-test: `just shape-check` resolves the new relative links.
- Criterion 4 — focused-test: `just version-check`.
