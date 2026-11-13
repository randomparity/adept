# Observed end on a harness that notifies on turn end — #500

## Problem

`references/dispatch-liveness.md` says a native agent's end-of-run notification proves the worker
ended. Some harnesses send the same completion notification when a worker's turn ends, while it
is idle and still resumable, so a dispatcher cannot tell which happened. Claim recovery, the one
replacement, and worktree reclamation in campaign, restock and forge all key on observed end.
Authority: WORK:SCOPE `q500-05440895`; light lane, denominator 100 (S).

## Scope

One amendment to "Observed end and reconciliation", after its first sentence: where the harness's
completion notification does not distinguish a turn end from a run end, that notification alone
is not an observed end, even when it carries a final report. The dispatcher obtains one by an
explicit harness stop of that worker and the harness's confirmation that the stop succeeded. A
dispatcher that cannot establish that its harness distinguishes the two treats it as one that
does not. The receipt section's sentence that an idle notification is neither an end of run nor
a stall stays as written and is not repeated. Campaign, forge and restock already link the
section; none restates it. No ownership transition is needed. No ADR: the issue's approach is the
stop-then-confirmation path the rule already allows, and no viable alternative changes it.

### Failure model

- Actors and deployments: a dispatching model in Claude Code or Codex reading worker
  notifications.
- Invariants and assets: a resumable worker's worktree, branch and claim are never reclaimed or
  replaced on a notification that may mean only a turn end.
- Accepted: an extra stop call for a worker that had already ended — bounded to one tool call.
- Covered elsewhere: a harness with no stop capability — the existing recovery rules, under which
  the end stays unobserved and the unit holds; the one-replacement authorization — unchanged.

## Success

1. The section states that, on a harness whose completion notification does not distinguish turn
   end from run end, the notification alone is not an observed end.
2. It names an explicit harness stop and its confirmation as how the dispatcher obtains one there.
3. The receipt section's idle-notification sentence is not duplicated, and no skill restates
   the rule.
4. `.claude-plugin/plugin.json` version is `7.13.1`.

## Validation

- Criteria 1–3 — task-test-not-applicable: changed surface is reference prose read by a model;
  anatomy rule 4 forbids asserting on prose, and `check-skill-shape.sh` already checks the
  existing links resolve.
- Criterion 4 — focused-test: `just version-check`.
