# 0071 — Protect in-flight claims without an age limit

## Status

Accepted (2026-09-18)

## Context

Issue #412 demonstrates an active quest waiting for an operator decision beyond
43200 seconds. ADR 0018's TTL treats that run as abandoned despite its in-flight
status. Time alone cannot distinguish an abandoned run from a legitimate wait.

## Decision

Supersede ADR 0018's liveness predicate only; retain its exclusive label primitive,
token grammar and binding, verify gates, recovery mechanisms, and other decisions.

A well-formed claim is live when its issue is open and either its age is below
`CLAIM_GRACE=600` seconds or the issue carries `status:in-progress`,
`status:in-review`, or `status:awaiting-merge`. Otherwise it is stale, including every
claim on a closed issue. An in-flight claim has no age limit or refresh obligation, so
the former `CLAIM_TTL` does not authorize its recovery.

Quest-log owns the predicate. Quest, campaign, and resurrection consume it and do not
recover or clear an in-flight claim solely because of age. This decision does not
change the existing operator-authorized force path or define a new abandonment,
handoff, malformed-claim, or cleanup protocol.

## Consequences

- A quiet in-flight claim can occupy an issue indefinitely until the existing operator path
  resolves it.
- The pre-status grace window and closed-issue staleness remain unchanged.
- Malformed claims, force authorization, claim cleanup, token transfer, clock-skew
  assumptions, installed-consumer paths, and seek-quest exclusion remain with their
  existing owners. No heartbeat or state store is added.

## Considered & rejected

- **Keep the TTL.** verified: at base commit
  `accf93c10f5a267c833b798c0da26b8a9a295a9f`, the liveness predicate in
  `skills/quest-log/SKILL.md` makes age 85791 stale even with in-progress status,
  matching the #412 report and violating its acceptance criterion.
- **Refresh at phase seams.** judgment: a human checkpoint can outlast the TTL
  without another phase seam; timed refresh adds an obligation during legitimate waits.
- **Change recovery or cleanup protocols too.** rejected as outside issue #412; removing
  age as in-flight recovery authority is sufficient for the reported failure.
