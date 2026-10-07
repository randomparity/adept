# 0087 — Refill independent campaign work at completion

## Status

Accepted (2026-10-07)

## Context

Issue #346 asks campaign to use capacity vacated by an independent worker without
waiting for its whole wave. Campaign also owns ordered landing, reservations and
ADR-index publication, which cannot follow completion order.

## Decision

Reuse the existing manifest. Keep serial groups merge-before-next; treat each planned
parallel wave as a finite approval/publication group, not an execution barrier.
At observed worker completion, reconcile its row, then dispatch the earliest eligible
approved independent row within the lowest task, campaign and harness concurrency cap.
Keep occupied or uncertain ownership charged against capacity. Recompute eligibility
from existing approvals, dependencies, scopes and claim bindings on resume.

Preserve merge-required dependencies, assigned landing order, consumed reservations,
commit-bound gates and cleanup preconditions. For an uncoupled ADR index, close each
fixed planned group when its members are merged or explicitly blocked/skipped; publish
its merged pending rows on a separate branch. A blocked member that later lands forms a
later finite publication group. Index publication does not bar eligible worker refill.

## Consequences

Execution and landing have distinct eligibility. Out-of-order completion can leave a
finished PR waiting for its predecessor. Pending index rows remain represented in the
existing manifest notes/outcomes until publication is verified. A failed publication
remains visible without authorizing a duplicate write or dependent dispatch.

## Considered & rejected

- **Keep whole-wave execution barriers.** judgment: does not meet the requested refill
  behavior when an independent row can use a vacated slot.
- **Merge in completion order.** judgment: conflicts with the required reservation and
  mandatory-edit ordering.
- **Add a scheduler or new manifest columns.** judgment: the existing row state, scope,
  assignments, worker bindings and notes already carry the decision inputs.
