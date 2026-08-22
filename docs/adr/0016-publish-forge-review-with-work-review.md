# 0016 — Publish the forge review with WORK:REVIEW

## Status

Accepted (2026-08-14)

## Context

`$forge` writes its whole-branch review beneath the ignored `.agent/` workspace. The review is
consumed during the build and then moved to trash, so it cannot be read after the quest worktree is
reclaimed. `$quest` already owns the PR's durable `WORK:REVIEW` annotation after `$deliver` creates
the pull request.

The review must outlive the worktree without making ignored scratch storage durable or conflating
the full forge review with the later trial-loop summary.

## Decision

`$forge` retains a successfully consumed whole-branch review and records it as pending publication
instead of disposing it at the end of the build. `$quest` carries that artifact through branch
review and shipping. Its existing `WORK:REVIEW` annotation keeps the review summary and adds a
separate, labelled section containing the complete forge review.

`$quest` reads the annotation back before it moves the scratch review to trash and records disposal
in the forge ledger. A failed or unverifiable publication stops the quest with the scratch artifact
intact. A quest with no forge review says so in the annotation and does not invent one.

## Consequences

- The full review becomes part of the PR discussion and survives worktree cleanup.
- `.agent/` remains ignored, temporary workspace; durability begins only after verified PR
  publication.
- `$quest`, rather than standalone `$deliver` or `$return-to-town`, owns the handoff because it
  already possesses the forge artifact and writes `WORK:REVIEW`.
- The PR comment service's size and availability limits become publication limits. Failure is
  visible and retains the source artifact; this decision does not add chunking or alternate
  storage.
- Review content crosses from model-written scratch data into a public repository discussion. The
  quest scans it with the repository's public-safety guard before posting and never publishes the
  local artifact path.

## Considered & rejected

**Give `$deliver` an optional review-artifact input.** Rejected because standalone delivery has no
review data today, while `$quest` already owns both the artifact and the durable review annotation.
The optional input would widen a second public contract without adding capability.

**Post a new annotation or separate PR comment.** Rejected because `WORK:REVIEW` is already the
durable record of the quest's review arms. A labelled section preserves the distinction without a
second lifecycle or latest-complete rule.

**Write the review outside the worktree.** Rejected because it makes host scratch storage the
durability mechanism and leaves ownership and cleanup after the quest undefined.

**Accept the loss.** Rejected by the operator's decision on issue #75 to attach the review to the
pull request.
