# 0080 Bound and automate this run's merge refreshes

## Status

Accepted (2026-09-30)

## Context

[Issue #437](https://github.com/randomparity/adept/issues/437) reported repeated base-moved
failures and eager sibling refreshes at `8c1dfdc`. The operator excluded fixing unrelated
actors, approved bounded scheduling, and then explicitly approved a finite full helper,
private recovery-state format and boundary tests to remove model turns between refresh,
CI completion, gate enforcement and merge. A supplied local example demonstrated the useful
sequence but admitted a print-only gate and hardcoded successful-check count. Its observed
successful merges did not establish fail-closed enforcement; its code is not adopted here.

## Decision

Amend [ADR0035](0035-the-merge-gate-binds-to-a-commit.md)'s scheduling and mechanical execution,
not its four predicates, SHA binding, original authority or accepted final-base race.
Select issue candidates 1, 2 and 5. Refresh only the next eligible PR. One root-invoked
`refresh-merge --claim-token TOKEN --context CONTEXT` performs the ordinary finite sequence,
using a private v1 packet for explicit authority, commands and durable recovery facts.

The shared reference remains normative; the helper enforces decisions rather than printing
checks. Campaign/return-to-town retain ordering, scope/policy/assignment decisions, observed
worker-end and worktree reclamation, hold reporting, post-merge tracking and cleanup. Only an
explicit human-authorized root/direct-human flow enters; quest workers never inherit merge
permission. The helper uses an already-owned clean feature worktree and never reclaims one.

A genuine original handshake must be validated before refresh. Derivatives are only for
recorded refreshed descendants after exact-head CI/base checks. Reuse the existing claim
tracker, guarded push and verified handoff writer from one coherent installed bundle.
Dynamic complete SHA-addressed run sets replace fixed job counts. A fresh final ancestry
check and server match-head merge remain required; exit0 means authoritative MERGED readback.

The same repository/PR/base chain admits at most two refreshes after its first proven miss.
The third distinct failed head holds before another refresh or merge. Duplicate checks and
faults do not inflate the count; green checks, new heads, retry and restart do not reset it.
Record pending mutation before action and completed evidence afterwards. Unknown history or
ambiguous interruption holds. Only verified merge or explicit operator resolution resets.

The private packet is a minimal machine-readable form of existing workflow notes, not a new
tracker or identity service. Root attests human authority, observed end and ownership; shell
cannot independently observe those harness facts. One root invocation owns a packet at a
time. Require private regular files, validated fields and atomic read-back updates. There is
no lease, lockfile, PID file, background daemon, new dependency or remote state schema.

Run waits inside one finite invocation with bounded network calls and one terminal summary.
One owner supplies full candidate verification: the required managed push hook when it covers
the candidate, otherwise the approved full command. Hooks are never bypassed or duplicated
merely for another full run. Conflicts, stale assignments or new policy decisions return to
root; the helper does not repair unrelated work. Report observations without guessed actors.
The packet carries exact numbered and version assignments; each observed base is checked for
invalidation before refresh or merge. Unsupported conventions return to root, never to a new
allocator. Unverified mutation-capable child completion retains pending intent and reports an
indeterminate write, since existing child exit codes cannot always prove whether a write landed.

## Consequences

Under serial own merges with no further base changes, ten green PRs need nine head-only
refreshes rather than45 eager refreshes. The helper removes ordinary model turns between
mechanical steps; it does not shorten the actual hook/CI workload or promise every PR lands.
Independent writers may still prevent landing. Private history must survive restart, and
ambiguous writes require reconciliation. A derivative may remain when a later base check
holds; it approves that head's lineage, never substitutes for a current base.

A tested executable/private format adds maintenance cost, justified by deterministic
fail-closed decisions, bounded recovery and repeated token/context costs. Same-principal
caller honesty/serialization and ADR0035's final base race remain explicit limitations.
Boundary tests must exercise actual failure decisions and the controlled complete route.

## Considered & rejected

- **Eager sibling refresh.** verified: old campaign609–611 and return-to-town184–193 at
  `8c1dfdc` amplify work; both callers now choose only the next eligible row.
- **Instruction-only bound or wait-only helper.** judgment: preserves a model turn between
  CI, gate and merge and does not fulfill the approved full candidate2 sequence.
- **Copy the supplied script.** judgment: a printed gate, fixed successful-job count and
  unverified derivative authority do not enforce the approved predicates.
- **General merge framework.** judgment: one finite issue-backed path and one private packet
  suffice. Conflicts/policy/assignment decisions stay with their existing owners.
- **Cross-run leases/FIFO (candidate3) or platform queue work (candidate4).** judgment:
  expressly outside the operator's unrelated-actor boundary; no coordination is introduced.
- **Persistent refresh-cost telemetry (candidate6).** judgment: the approved cap needs failure
  evidence, not a measurement subsystem.
