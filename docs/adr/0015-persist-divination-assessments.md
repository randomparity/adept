# 0015 — Persist divination assessments separately from scope charters

## Status

Accepted (2026-08-13)

## Context

`$divination` estimates blast radius, change hazards, complexity, and decomposition, but its
read-only, in-session output disappears before a later or dispatched `$quest` can use it. Quest
therefore repeats the assessment. `$bounty decompose` likewise refers to a divination split that
may no longer be present. Reusing `WORK:SCOPE` would make the estimate durable, but that marker is
already owned by quest's frozen external-authority charter and serves as its liveness signal.

## Decision

`$divination` posts its assessment to the scoped issue as a complete `WORK:DIVINATION`
annotation. The annotation contains the assessed issue URL, a token, source revision evidence,
blast radius, change hazards, complexity, and decompose verdict. It follows the shared
whole-line markers, completion sentinel, and latest-complete-wins rules.

Consumers read the latest complete `WORK:DIVINATION` block, verify that it names the requested
issue, and revalidate it against the live issue and implicated repository state. Stale,
malformed, incomplete, mismatched, or absent assessments are evidence gaps, not blockers:
`$quest` derives the fields itself and `$bounty` proceeds without a persisted split.

`WORK:DIVINATION` remains advisory evidence. It never freezes scope, authorizes implementation,
changes issue status, or assigns `risk:*` execution-policy labels. `$quest` continues to own and
post `WORK:SCOPE` after it freezes the complete charter.

## Consequences

Pre-work assessment now writes one public issue comment, so `$divination` is no longer read-only.
The distinct marker preserves ownership and lets dispatched workflows recover the assessment
without treating it as authority. Revalidation deliberately permits repeated analysis when the
issue or repository moved after the annotation; durability removes accidental duplication, not
the need to check current evidence.

The annotation registry and direct consumers change together. Existing issues need no migration;
absence retains the former derive-or-proceed behavior.

## Considered & rejected

**Post `WORK:SCOPE` directly.** Rejected because a divination estimate cannot supply quest's
outcome, provenance, exclusions, permitted surface, ambiguity resolution, or interaction mode.
Sharing the marker would let advisory analysis impersonate frozen authority and liveness.

**Keep divination read-only and document the duplication.** Rejected because the duplicate work
is systematic at dispatch and the tracker already provides a bounded durable annotation channel.

**Store the assessment only in local scratch state.** Rejected because local state is neither
dispatch-visible nor durable across machines and sessions.

**Make a persisted assessment binding until explicitly invalidated.** Rejected because issue
comments, links, and repository state can change independently; current evidence must win over a
cached estimate.
