# 0012 — Restock composes shared workflow contracts

## Status

Accepted (2026-08-13)

## Context

`$restock` independently discovers repository facts, owns fixed global scratch paths, writes no
shared workflow tracking, and directly merges and cleans dependency branches. Those choices
duplicate contracts already owned by `$attunement`, `$quest-log`, and `$return-to-town`; their
behavior has consequently drifted. Dependabot PRs also commonly have no owning issue, while the
existing return-to-town tracking path assumes one.

## Decision

Keep dependency audit, graph grouping, evaluation, and serial ordering in `$restock`, but compose
the shared contracts at their ownership boundaries. `$attunement` supplies repository discovery.
`$quest-log` supplies PR status and review/trajectory annotations. One run-unique scratch root and
an ownership ledger govern temporary state. `$return-to-town` performs each authorized merge and
scoped cleanup.

Add an explicit PR-only tracking mode to `$return-to-town`. It records terminal trajectory and
clears status on the PR while skipping issue closure and cleared-dependent reconciliation. Normal
issue-backed behavior remains unchanged.

The PR-only lifecycle is `status:in-progress` while restock discovers and prepares the unit,
`status:in-review` while it evaluates, and `status:awaiting-merge` only for a clean authorized
`PASS`. Restock owns those three transitions and the PR's `WORK:REVIEW`; `$return-to-town` owns the
terminal PR `WORK:TRAJECTORY` and removal of active `status:` labels after merge. A non-merge
terminal evaluation receives `WORK:REVIEW` and has its active status removed by restock. These PR
labels are restock run state, not an extension of quest-log's issue state machine, and
issue-backed invocations continue to use that existing state machine and reconciliation behavior.

Before allocating current-run artifacts, restock scans prior restock run roots beneath the session
scratchpad and reads their ownership ledgers. It removes an artifact only when the ledger proves
its owner and the worker's end was observed under the dispatch-liveness contract. Missing,
conflicting, or incomplete ownership evidence preserves the artifact and produces an actionable
report; path shape and elapsed age never authorize deletion.

## Consequences

Restock no longer carries a second implementation of shared merge and cleanup rules. Temporary
artifacts cannot collide merely because two runs target the same repository, and uncertain
ownership retains evidence instead of deleting it. Workflow activity becomes visible on the PRs
being evaluated.

Return-to-town gains one explicit caller mode, so its tracking target is no longer implicitly
always an issue. Restock must pass complete ownership and guardrail context at that boundary.

## Considered & rejected

**Keep restock self-contained and copy newer rules into it.** Rejected because every later shared
workflow change would require another synchronized edit and review.

**Extract executable helpers for discovery and cleanup.** Rejected because the existing skill
contracts already provide the composition boundary, and another program would add shipped surface
without removing their prose contracts.

**Track only restock's own summary, not each PR.** Rejected because resurrection and retrospective
tools inspect durable GitHub state; a local-only report disappears with the run.

**Require every Dependabot PR to have an issue.** Rejected because that fabricates tracker objects
solely to satisfy an implementation assumption and adds external writes unrelated to evaluation.

**Do nothing.** Rejected because fixed scratch names and duplicated cleanup continue to create
cross-run collision and data-loss risk.
