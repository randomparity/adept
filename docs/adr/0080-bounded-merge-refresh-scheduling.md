# 0080 Bound this run's merge refreshes

## Status

Accepted (2026-09-30)

## Context

[Issue #437](https://github.com/randomparity/adept/issues/437) reported repeated
base-moved failures while unrelated runs landed changes. At `8c1dfdc`, campaign
and return-to-town refresh remaining siblings after each merge; the shared gate
requires a fresh base check and a full refreshed candidate validation.
The operator excluded fixing unrelated actors and approved bounded local recovery.

## Decision

Amend [ADR0035](0035-the-merge-gate-binds-to-a-commit.md)'s refresh scheduling only.
Its four gate predicates, SHA binding and derivative-handshake authority still govern.
Select issue candidates 1 and 5: refresh only the next eligible PR in existing landing
order, and hold on the third distinct proven part-3 failure before another refresh.
This permits at most two refreshes after the first failure in a recovery chain.

The shared merge-gate reference owns the bound; callers own scheduling and their
existing hold paths. Keep exact PR/base identity, checked head/base observations,
count and refresh disposition in existing private workflow notes across restarts.
Repeat checks of the same failed head do not increment or authorize another refresh.
Unknown history/completion holds for reconciliation. Faults do not count; an intermediate
pass or new head does not reset. Only verified merge completion or an explicit operator
resolution resets the chain. Record that provenance rather than trusting comment text.

Report base movement without guessing another run's identity. Use existing trajectory
and status conventions. Add no executable, tracker schema, remote lock or new label.

## Consequences

Within one run and absent further base changes, ten initially green PRs need nine
head-only refreshes instead of 45 eager sibling refreshes (sum of nine through one).
Continued external writes can still prevent landing; the result is bounded own work
and a truthful hold, not a fairness or liveness guarantee. Full candidate hooks and CI
remain required, as do author authority and worktree ownership. The final base-check/merge
race remains ADR0035's accepted limitation. Operators must reconcile lost history.

## Considered & rejected

- **Refresh every sibling.** verified: `skills/campaign/SKILL.md:609–611` and
  `skills/return-to-town/SKILL.md:184–193` at `8c1dfdc` prescribe this amplification.
- **Keep retrying until quiet.** judgment: it leaves the approved cost bound unmet.
- **Monolithic refresh/wait/merge helper (candidate 2).** judgment: the approved instruction
  change needs no new executable or additional lifecycle to narrow model-turn delays.
- **Cross-run lease/FIFO (candidate 3).** judgment: outside the operator's bounded scope;
  exclusion covers coordination and recovery of unrelated actors.
- **Platform queue integration (candidate 4).** judgment: a separate platform contract,
  unnecessary to bound this run; ADR0035's existing queue caveat remains unchanged.
- **Persistent refresh-cost telemetry (candidate 6).** judgment: counting proven failures
  is sufficient for the selected bound without a cost-measurement subsystem.
