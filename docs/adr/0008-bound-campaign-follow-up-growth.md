# 0008 — Bound campaign follow-up growth

## Status

Accepted (2026-08-12)

## Context

Campaign review can discover real but low-value defects. Its current binary triage sends
every confirmed defect into a quest, while its re-enqueue step accepts every traceable
follow-up without an operator boundary. Repeated instances of one governed defect class can
therefore generate separate issues and quest cycles indefinitely.

The project must preserve confirmed evidence without filling the open queue with work nobody
intends to schedule. It must also retain the existing rule that issue creation is confirmed by
the operator.

## Decision

Campaign triage gains `close-not-planned`: a confirmed defect whose trigger likelihood and
impact do not justify its remediation cost. The verdict records the evidence, cost/benefit
rationale, and reconsideration condition. Campaign presents it in the batch plan, then closes
the issue with GitHub's not-planned reason. It is durable evidence, not an open backlog item.

Bounty's existing all-state deduplication owns recurrence discovery. It searches separately
for the evidenced mechanism or idiom, component or file family, and governing-decision
reference, then follows links from matched consolidation issues. It presents the candidate
history and any uncertain matches rather than treating title overlap as a complete inventory.
It groups only issues whose evidence establishes all applicable identity dimensions; a failed,
truncated, or inconclusive search stops filing rather than asserting that the threshold was not
met.

When the proposed instance would be the fourth or later in that class, bounty proposes one
ordinary consolidated-sweep issue instead of another instance issue. Its Evidence preserves
the current occurrence's source, trigger, and evidence alongside citations to every verified
historical instance. Existing issues are never mutated by this scan. An already-open sweep is
treated as the near-match to use rather than duplicated. A closed sweep remains historical
evidence: bounty proposes a new sweep only when current evidence shows the class still exists,
citing the prior sweep and new occurrence.

Bounty rechecks for an open matching sweep immediately before the confirmed create and never
knowingly creates a second one. This is not atomic: concurrent bounty runs can still create
duplicates, which return through the ordinary all-state deduplication flow rather than adding
locking or classifier state.

Campaign never automatically expands into review-created work. At re-enqueue it presents all
new traceable issues, their proposed routing, and any consolidation, then requires explicit
operator confirmation before adding them to the manifest and returning to triage.

## Consequences

- Campaign does not retain its confirmed low-value defects as open backlog items; they remain
  searchable among closed issues. Other issue-creation paths keep their existing queue policy.
- Defect-class identity is evidence-based, not title similarity alone. Uncertain matches stay
  separate rather than silently collapsing unrelated defects, and incomplete discovery stops
  filing rather than silently undercounting the class.
- A consolidated sweep is one executable issue. It becomes an epic only if later scoping shows
  that it genuinely requires several independently mergeable changes.
- A class may accumulate sequential sweeps when it demonstrably recurs after an earlier sweep
  closes. The immediate pre-create recheck narrows but cannot eliminate concurrent duplicate
  sweeps; any duplicate is handled by ordinary deduplication.
- Campaign runs pause at every follow-up expansion. This trades unattended throughput for a
  hard bound controlled by the operator.
- The contract remains instruction-only and adds no dependency, script, label family, or
  persistent classifier state.

## Considered & rejected

**Keep `track-only` issues open with a new disposition label.** Rejected because hundreds of
confirmed but intentionally unscheduled defects would still dominate the active queue. Closing
as not planned preserves the evidence without misrepresenting it as planned work.

**Create a defect-class epic and make every instance a sub-issue.** Rejected because sub-issues
represent independently executable units intended for completion. The purpose here is to avoid
cycling every instance. An ordinary sweep issue is the work item; historical instances are
evidence.

**Let campaign infer recurrence only from issues created during its current run.** Rejected
because closed historical instances are the evidence that establishes recurrence. Bounty
already searches all states before filing and is the narrowest owner for that discovery.

**Keep bounty's current near-match prompt and let the operator consolidate case by case.**
Rejected because it recreates the same instance-versus-sweep judgment on every recurrence and
provides no consistent fourth-plus routing. The confirmation gate still chooses whether to
file; the class tuple and threshold make what it is choosing consistent.

**Automatically enqueue up to a numeric per-wave cap.** Rejected because any chosen cap allows
some unapproved scope expansion and becomes arbitrary policy. One explicit confirmation at the
existing re-enqueue boundary is simpler and gives the operator the complete proposed expansion.

**Do nothing.** Rejected because the observed campaign expanded four requested issues into
eleven follow-ups, with repeated quest cycles for one governed gate-script defect class.

## Provenance

Decided while designing issue #91, including the operator's decisions to close low-value
defects as not planned, use an ordinary consolidated issue rather than an epic, and make bounty
discover historical recurrence without mutating old issues.
