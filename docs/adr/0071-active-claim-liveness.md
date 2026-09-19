# 0071 — Protect in-flight claims without an age limit

## Status

Accepted (2026-09-18)

## Context

Issue #412 demonstrates an active quest waiting for an operator decision beyond
43200 seconds. ADR 0018's TTL treats that run as abandoned despite its in-flight
status. Time alone cannot distinguish an abandoned run from a legitimate wait.

## Decision

Supersede ADR 0018's liveness and recovery policy only; retain its exclusive label
primitive, token grammar and binding, verify gates, and other decisions.

An open issue's well-formed claim is live when its age is below `CLAIM_GRACE=600`
seconds or it carries `status:in-progress`, `status:in-review`, or
`status:awaiting-merge`. There is no in-flight TTL or refresh obligation. Closed
issues' claims remain stale. Malformed claims retain their explicit recovery path.

Quest-log owns this policy. Quest and campaign may authorize age-based recovery
only for an open issue outside those in-flight statuses after grace expires.
An in-flight claim requires an explicit operator recovery decision naming the
issue and observed claim. Campaign additionally retains its observed-worker-end
and branch-reuse gates. Resurrection must present claimed in-flight resets as
explicit abandonment decisions, not infer abandonment from its age/branch checks.
Record the decision in the owning workflow's existing durable notes before the
write. Standalone resurrection has no such artifact, so its confirmation is
single-session only and must be reacquired from a fresh plan after any handoff.
Immediately before every claim-clearing write, including closed cleanup, re-read
claim and issue state and hold if the observed claim changed or state no longer
fits the action. Force recovery remains available.

The tracker primitive still enforces token, grammar, and caller-supplied age or
force arguments; it does not decide policy or authenticate the operator's intent.

## Consequences

- A quiet in-flight claim can occupy an issue indefinitely until explicit recovery.
- Status and claim observations are not atomic. This change governs cooperating
  workflow callers; it adds no server-side lease, conditional deletion, or protection
  from an old installed workflow or a caller bypassing the policy.
- Pre-status grace, closed cleanup, clock-skew assumptions, and claim exclusion in
  seek-quest remain with their existing owners. No new heartbeat or state store.

## Considered & rejected

- **Keep the TTL.** verified: at base commit
  `accf93c10f5a267c833b798c0da26b8a9a295a9f`, the liveness predicate in
  `skills/quest-log/SKILL.md` makes age 85791 stale even with in-progress status,
  matching the #412 report and violating its acceptance criterion.
- **Refresh at phase seams.** judgment: a human checkpoint can outlast the TTL
  without another phase seam; timed refresh adds an obligation during legitimate waits.
- **Move policy into the tracker command.** judgment: this change is the authorization
  contract of the owning skills; duplicating it in the generic recovery primitive adds
  executable surface while explicit operator intent would still belong to the caller.
