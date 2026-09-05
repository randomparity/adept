# 0055 — Party derives red and names its committer

## Status

Accepted (2026-09-05)

## Context

`$forge`'s party mode closes a task on what the implementer reports. One claim in that report is
already re-derived rather than read: step 5 requires every reported SHA to be an ancestor of the
assigned branch and the range from the task base to be non-empty, because "a worker that got lost
is exactly the one whose self-report cannot be trusted". Everything else in the report is read.

Two of the claims that are only read carry weight the reading does not support.

**The red half of a `focused-test` contract.** The inventory requires the entry to name "the test
file or case, expected red failure, and exact green command", and the implementer reports the red
command and what it produced. Nothing runs it. A test written after the implementation, against
the implementation, produces a report byte-identical to one written before — and red-green is the
whole gate on a task since [0052](0052-tests-gate-a-task-the-branch-gets-one-review.md) removed
the per-task reviewer. The green half is corroborated by the branch guardrail run that 0052 added.
The red half is corroborated by nothing.

**Which dispatch produced a commit.** [dispatch-liveness](../../references/dispatch-liveness.md)
requires a recovery-chain identifier spanning a worker and its one replacement, and requires the
race case — a late valid report arriving after a replacement was dispatched — to be reconciled
across both result sets. The identifier lives in the ledger and is minted when a recovery
happens, so at the moment two workers' commits sit on one branch, deciding which worker wrote
which commit means inferring authorship from ledger ordering.

## Decision

**1. The orchestrator re-derives red for every `focused-test` entry.** `verify-red` reverts the
task's non-test paths to the task base inside the party worktree, runs the entry's exact red
command, requires a non-zero exit, and restores the tree. It runs on every focused entry, not a
sample: the party worktree already has the project's dependencies installed and a focused entry
names a file or case rather than a suite, so the marginal cost is one focused run per contract.

**2. Three outcomes, because two would lie.** `red-confirmed` closes the entry.
`red-not-reproduced` — the command passed with the implementation reverted — is a
stop-and-reconcile, the same class as a failed ancestry check. `red-not-separable` — every path
the task changed is a named test path, so there is nothing to revert — is recorded and the run
continues. That third outcome is what an inline-test language produces: a Rust `#[cfg(test)]`
module cannot be pulled away from the code it tests, and reporting a vacuous pass there would be
worse than reporting the limit.

**3. Red is a non-zero exit status, not a matched failure message.** The expected reason stays a
claim in the report that a human reads. Matching the text of a failure is the prose assertion the
repository's fourth anatomy rule forbids.

**4. Every party worker commit carries `Forge-Dispatch: <unit>.<attempt>`,** a git trailer, where
`unit` is `task-<N>` or `review-fix` and `attempt` is 1 or 2. `task-<N>` is the recovery chain
dispatch-liveness already requires; `.<attempt>` distinguishes the original from its one
replacement. The value is minted at dispatch on every run rather than at recovery time, is
supplied to the worker as a third mandatory placement value, and is verified in step 5 beside the
ancestry check.

**5. `verify-red` ships as an executable under `skills/forge/scripts/`.** It mutates the working
tree and restores it under a trap. That is a deterministic file operation which a model
performing it inline will eventually get wrong in the one way that matters — leaving an
implementation reverted — which is the second anatomy rule's own criterion.

## Consequences

A task with *k* focused contracts costs *k* extra focused test runs. The entries are file- or
case-scoped by their own definition, so this is bounded by the plan's own choice of contract
granularity rather than by suite size.

A worktree-mutating script is now in the per-task loop. Its restoration failure is a distinct
loud exit that stops the run, matching the shape already used for the reviewer's
`CLEANUP_FAILED`: reviewer-created state left unresolved is not something a later phase resumes
past.

`red-not-separable` is an honest hole rather than a hidden one. Inline-test languages get no red
re-derivation from this decision, and the whole-branch review sees the recorded outcome.

A focused command that was already failing at the task base for an unrelated reason yields a
vacuous `red-confirmed`. What bounds it is the clean baseline the pocket dimension establishes
before the first task, which is the same guarantee the green half already rests on.

The recovery-chain identifier now exists on every run instead of only on runs that had a silent
worker, so dispatch-liveness's required record is populated before a recovery rather than during
one.

This repository's own commits carry the trailer whenever adept is built by adept. No gate reads
commit messages, so nothing else changes.

## Considered & rejected

- **Test-first commit discipline — the implementer commits the failing test alone, and the
  orchestrator checks that commit out and runs the command.** verified: it needs no new
  executable, but `CLAUDE.md` makes per-commit history load-bearing ("Never squash-merge code PRs
  — per-commit history is load-bearing for `git bisect`"), and this plants one deliberately red
  commit per contract in every branch that history is bisected over.
- **Sample one task per run instead of checking every contract.** verified: the round trip
  measured in a git fixture on git 2.50.1 is `git checkout <base> -- <impl>`, one focused run
  exiting 1, `git checkout <head> -- <impl>`, and `git status --porcelain` empty — inside the
  existing worktree, so no dependency install is repeated. Sampling would add a selection rule to
  avoid a cost that is one focused run.
- **Reconstruct in a fresh scratch worktree.** verified: the same round trip restores the existing
  tree to an empty `git status --porcelain` (git 2.50.1, macOS 25.6.0), so the isolation a second
  worktree buys is already provided by the trap, against the cost of installing the project's
  dependencies again per task.
- **Match the report's expected failure message as well as the exit status.** judgment: anatomy
  rule 4 — a gate asserting on the text of a failure is the class this repository removed 563
  lines of gate to be rid of.
- **Record a SHA-to-worker table in the ledger instead of a trailer.** judgment: that table is the
  inference the trailer removes, and it is a second copy that disagrees with the commit in exactly
  the race it exists for.
- **Put the dispatch identity in the commit subject.** verified: `git log
  --format='%(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)'` returns the value on git
  2.50.1 and an empty string for an absent key, so a trailer is queryable without parsing
  subjects — which conventional commits already own.
- **Do nothing.** verified: `skills/forge/SKILL.md` step 6 verifies a focused entry by reading
  that it "contains the red command and expected failure"; no orchestrator step executes it.
