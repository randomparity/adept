# 0064 Standing repair authority is base-bound

## Status

Accepted (2026-09-13)

## Context

An unattended repair cannot get a human reading of its risk assignment or its exact
scope/exclusion packet during the run. Shared-code changes also fail the current
night-safe merge rule even when the affected consumers have decisive tests. A green
check or issue label cannot grant the missing authority.

## Decision

A repository may opt in through one maintainer-approved `Standing repair authority`
section in a tracked root `AGENTS.md` or `CLAUDE.md` on the protected base branch.
The section names a policy identity and revision, a bounded repair class, permitted
risk-assessment and exact scope-packet rules, and the affected-consumer proof required
for shared-code automatic merge. Maintainer approval must bind the exact
instruction-file blob (for example, an approved policy PR whose reviewed head
contains that blob). A worker reads that base-branch declaration, not an
issue, PR, or its own branch as authority, and records the instruction file's Git blob
ID as well as the policy identity/revision and case-specific evidence in the existing
risk rationale and `WORK:SCOPE` record. A changed blob ID or removal on the base revokes
prior packets even if the declared revision was not incremented. New packets
against a changed blob need new approval of that blob; changing their blob
reference alone grants nothing. Duplicate sections, unverified blob-bound
approval provenance, or an unreadable base fail closed.

Shared work remains `risk:night-watch`. A separate policy-bound predicate may admit
automatic merge only when the identified affected consumers of the changed contract
have decisive proof and no more restrictive criterion applies. Check that
predicate and recheck the live policy immediately before the final
commit-bound merge gate; its base-current check remains the last check before
the merge attempt. The campaign retains
its Scope approvals row, using policy-bound provenance with the exact exclusions,
owners, policy identity/revision, and blob ID instead of an operator confirmation
only while the live base and packet still match.

The policy may waive a per-repair human read only within its class. It cannot waive
claim ownership, review, the commit-bound merge gate, protected external-contract
decisions, or a repository's ordinary issue-creation confirmation. Outside the class,
the current per-repair gates apply. An unprovable case parks at its first authority
checkpoint.

## Consequences

Opt-in is explicit per repository and absent by default. A base-branch policy change
invalidates an in-flight packet instead of silently widening it. Shared-code merge
requires proof for the relevant direct and transitive consumers, not a refactor label
or generic green CI. A protected external contract still needs a separate operator
decision. This adds no approval database or replacement tracker protocol.

## Considered & rejected

- **Treat a campaign invocation as standing approval.** judgment: one campaign's
  authority does not express a revocable future repair class.
- **Read an opt-in from the repair branch or issue.** judgment: the actor proposing a
  repair could grant itself authority in the same change.
- **Mark all reversible shared changes night-safe.** judgment: reversibility alone
  cannot establish correctness for affected consumers.
