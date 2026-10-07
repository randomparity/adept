# 0083 — Reconcile an existing verified review publication

## Status

Accepted (2026-10-07). Amends ADR0048's existing-comment recovery exclusion only.

## Context

Issue #312 identifies remote verification followed by a fatal local ledger append or
readback failure. PFR-6 in the helper suite reproduces the latter: one comment exists,
the verified line is present, no closing record exists and original inputs remain.
ADR0048's publication-absence recovery cannot admit that state.

## Decision

Add a separate human-authorized reconciliation route for exactly one existing matching
comment, unchanged delivered PR HEAD and original retained private inputs. Quest
retains authority and handoff ownership; the existing helper gains a reconcile mode
that reuses composition/readback/disposal and cannot create a comment. Admit absent
or one exact verification line, complete local records once, and preserve the original
helper body identity. The same one-attempt recovery authorization is consumed before
reconciliation. Failures remain parked; no automatic retry is added.

## Consequences

An existing comment becomes recoverable evidence rather than a permanent exclusion.
Ambiguous comments, changed HEAD, substituted inputs and incomplete ledger fragments
still need operator reconciliation. Original-body retention is required. Recovery
retains ADR0048's exclusive-publisher assumption and has no cross-service atomicity.

## Considered & rejected

- **Leave manual ledger surgery undocumented.** judgment: it leaves the requested
  recoverable state dependent on reconstructing private ownership rules unaided.
- **Atomically replace verification lines on ordinary publication.** judgment: it can
  narrow partial writes but cannot remove failure between remote verification and any
  local write, so it does not satisfy the recovery criterion alone.
- **Retry normal publication.** judgment: it would create another comment instead of
  reconciling the verified one and violates the approved duplicate-prevention boundary.
