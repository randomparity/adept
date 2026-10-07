# 0058 — Classify failures before model escalation

## Status

Accepted (2026-09-12)

## Context

The shared model-selection policy describes capability tiers and runtime
resolution. Forge handles worker failure and owns the progress ledger. Without a
classification boundary, a failed worker can be sent to a stronger model for
missing context or a service failure, while the new dispatch appears to start a
new recovery allowance.

## Decision

The shared policy defines when a demonstrated capability gap warrants a stronger
tier and when another failure class follows its existing owner. Forge applies
that classification to worker outcomes and records the evidence, distinct
correction, returned-worker dispatch history and existing allowance use in its
current brief, report and ledger. A returned `CANNOT_COMPLETE` keeps the current
`task-N.<attempt>` suffix, which counts only liveness replacement. Repeating the
same failure after the same correction stops for diagnosis; no new numeric
returned-worker ceiling is introduced. Selection is subordinate to scope,
safety, claim ownership, predecessor-end evidence and existing budgets.
The final whole-branch reviewer retains its independent strongest-available rule.

## Consequences

A worker report alone does not prove that a stronger model is needed. A
coordinator must test its explanation against the task, available context and
failure artifact. Unavailable capability or an exhausted or unknown existing
allowance holds the dependent action. A new model does not make a second worker, review pass or
continuation automatically permissible.

## Considered & rejected

- **Keep failure routing only in forge.** judgment: coordinator and later
  consumers would lack the same classification boundary.
- **Introduce a numeric task retry ceiling or tracker state.** judgment: the
  operator chose to preserve existing limits and require distinct evidence and
  correction for each retry; another authority could drift from current ledgers.
- **Retry with a stronger model after every failure.** judgment: it misclassifies
  context and environment failures and evades the budget's purpose.
