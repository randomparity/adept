# 0009 — Terminal PR state precedes mergeability

## Status

Accepted (2026-08-13)

## Context

GitHub computes `mergeable` and `mergeStateStatus` lazily. They can remain `UNKNOWN` after a
pull request has already reached the terminal `MERGED` state. `$return-to-town` currently
leads its operator-merge status check with those computed fields, so a post-merge invocation
can poll an already-conclusive pull request.

The cleanup path must distinguish a merged pull request from one closed without merging.

## Decision

`$return-to-town` reads `state` and `mergedAt` in the same bounded status snapshot as checks
and mergeability. It interprets `state` before computed mergeability: `MERGED` proceeds
directly to post-merge tracking and cleanup, while `CLOSED` stops without post-merge cleanup.
Only an `OPEN` pull request consults `mergeable` and `mergeStateStatus` or waits for them.

## Consequences

- A merged pull request no longer waits for GitHub's mergeability recalculation.
- The existing green-and-mergeable requirement remains unchanged for open pull requests.
- The snapshot may still contain `UNKNOWN` computed fields, but terminal-state handling does
  not depend on them.
- This is an instruction contract; correctness is established by behavioral review rather
  than an automated assertion over prose.

## Considered & rejected

**Query terminal state in a separate preliminary request.** Rejected because one snapshot can
carry terminal state and the existing fields without another network round trip.

**Treat `mergedAt` alone as the terminal signal.** Rejected because `state` is the explicit
lifecycle discriminator; `mergedAt` remains useful corroborating context.

**Keep polling computed fields until GitHub settles.** Rejected because they cannot add useful
information after `state` is already `MERGED`.
