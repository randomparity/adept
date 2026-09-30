# 0077 — Verify claims at delivery and publication boundaries

## Status

Accepted (2026-09-30)

## Context

Issue #424 reports a displaced quest opening duplicate work. Delivery currently
invokes push and PR writes directly; the two publication helpers never verify claims.
G4 is a caller instruction and cannot mechanically prevent an omitted check.
The canonical tracker already distinguishes held0, absent2, foreign6 and transport4.

## Decision

Issue-backed delivery uses a deliver-owned executable for fixed push, PR-create
and PR-edit operations. It validates destination and arguments, then calls canonical
`claim-verify` immediately before the selected write. Only exit0 permits that write. Gates pin GH_HOST=github.com to the same host as
the selected public write; new GitHub commands explicitly qualify that host.
Issue-free delivery retains its existing commands. Publication helpers require
`--claim-token`, bind its issue to their destination, and verify before comment creation.
No helper acquires, recovers or releases a claim. Claim exits and holder diagnostics
remain available to the caller with its local checkout path.
The invocation break ships as version7.0.0; active callers migrate together.
Review preflight stays network-free; handoff preflight retains bounded read-only
discovery/full composition. Neither verifies a claim or writes. The managed push
may exceed120seconds for mandatory pre-push verification, explicitly authorized by
the operator; claim and GitHub-call bounds remain unchanged.

## Consequences

- A failed gate prevents the selected write, not writes already completed in an
  earlier phase. Lost ownership after a valid push leaves a remote branch to report.
- Verification and the remote write are not atomic. Managed pre-push hooks run
  between verification and the actual push; they remain mandatory and are not bypassed.
- A transport4 permits an ordinary retry of an unperformed write, never reacquisition.
  Existing indeterminate-write and one-time publication recovery rules remain.
- This is accidental stale-worker fencing, not protection against an actor bypassing
  the shipped entrypoint or reusing another holder's credentials and token.

## Considered & rejected

- **Do nothing** — verified: at base01553f0, deliver has no claim reference and both
  helpers' `post_comment` functions invoke GitHub without canonical verification.
- **Move G4 prose only** — judgment: a forgotten instruction still permits the write;
  deterministic executable ownership of the check is required by #424's outcome.
- **Duplicate label parsing** — judgment: the existing tracker owns claim grammar,
  transport and holder diagnostics; copying it would add an inconsistent policy owner.
- **Global hooks or atomic fencing service** — judgment: hooks do not own PR comments,
  and a new coordination service exceeds the requested existing-claim boundaries.

## Provenance

Human campaign invocation and Approve for #424; EMPTY exclusions, 2026-09-29.
Later operator decision: “allow the managed push to exceed 120 seconds”; campaign
records the managed-push-only exception, no bypass or atomicity promise.
Charter q424-c646f537; campaign ff1f1dfeec95-d9d0de73-def8-4a59-9962-e0c250f8c947.
