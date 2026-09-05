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
command and what it produced. Nothing runs it, so nothing establishes that the named test would
fail without the implementation — a test that could never fail produces a report indistinguishable
from one that did. Red-green is the whole gate on a task since
[0052](0052-tests-gate-a-task-the-branch-gets-one-review.md) removed the per-task reviewer. The
green half is corroborated by the branch guardrail run that 0052 added. The red half is
corroborated by nothing.

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

A fourth exit sits beside the three verdicts rather than among them:
`red-command-dirtied-tree` reports the verdict *and* the tracked paths the command modified
outside the reverted set, because the verdict is real and the residue is real and collapsing
either into the other loses one of them.

**3. Red is a non-zero exit status, not a matched failure message.** The expected reason stays a
claim in the report that a human reads. Matching the text of a failure is the prose assertion the
repository's fourth anatomy rule forbids.

**4. Every party worker commit carries `Forge-Dispatch: <unit>.<attempt>`,** a git trailer, where
`unit` is `task-<N>` or `review-fix` and `attempt` is 1 or 2. `task-<N>` is the recovery chain
dispatch-liveness already requires; `.<attempt>` distinguishes the original from its one
replacement. The value is minted at dispatch on every run rather than at recovery time, and is
supplied to the worker as a third mandatory placement value.

**5. Step 5 verifies the chain, not the current dispatch's exact value.** Every commit in the
range must carry this unit with an attempt of 1 or 2. A commit with no trailer, or one naming a
different unit, is a stop-and-reconcile. A commit carrying attempt 1 on an attempt-2 run is not:
that is precisely the late-report race dispatch-liveness exists to reconcile, and stopping on it
would make the mechanism refuse the one case it was built for. It is recorded and both result sets
are reconciled. A replacement dispatch reuses the original task base, so attempt 1's commits stay
inside the checked range.

**6. `verify-red` ships as an executable under `skills/forge/scripts/`.** It mutates the working
tree and restores it under a trap. That is a deterministic file operation which a model
performing it inline will eventually get wrong in the one way that matters — leaving an
implementation reverted — which is the second anatomy rule's own criterion.

## Consequences

Every revert is task-wide, so *k* focused contracts are *k* checks against the same maximally
reverted tree rather than *k* independent ones: the second entry's `red-confirmed` says its
command failed with all of the task's implementation absent, not with its own. Independence
belongs to the first entry only, and the whole-branch review is what separates the rest. This is accepted rather than fixed — per-entry reverts would grow the script for a residual
review already reads.

A task with *k* focused contracts costs *k* reverts and *k* restores, not *k* test runs. Each
`git checkout` rewrites the reverted file and advances its mtime, so an mtime-keyed build system
rebuilds those paths on the revert, again on the restore, and once more for the guardrail run.
In an interpreted project that is the *k* focused runs the entries are scoped to. In a compiled
one it is 2*k* rebuilds, and the decision is worth less there for a second reason: a command that
fails because the tree no longer compiles exits non-zero exactly as a failing assertion does, and
`red-confirmed` cannot tell them apart. The mechanism's value is scoped to projects where a test
can run against a partially reverted tree; where it cannot, this buys a weaker signal at a higher
price and sampling is the open question this record does not settle.

A red command that modifies a **tracked** path gets its own outcome rather than being folded into
the verdict. The script reverted what it was told to revert and cannot restore what the command
touched, so it reports the residue against the command that made it — otherwise the next focused
entry stops on a dirty-tree precondition one entry away from the cause.

A worktree-mutating script is now in the per-task loop. Its restoration failure is a distinct
loud exit that stops the run, matching the shape already used for the reviewer's
`CLEANUP_FAILED`: reviewer-created state left unresolved is not something a later phase resumes
past.

`red-not-separable` is an honest hole rather than a hidden one. Inline-test languages get no red
re-derivation from this decision, and the whole-branch review sees the recorded outcome.

`red-confirmed` establishes only that the named command **did not succeed** against the reverted
tree. It does not establish that an assertion was evaluated. A command that cannot load or
compile — a missing import, an absent symbol — exits non-zero without reaching one, and so does a
test that asserts nothing. Whether the command failed for the entry's stated reason stays a
report claim the whole-branch review reads.

Two cases are excluded rather than accepted, because they are reachable without a hostile actor.
Exit 126 and 127 — not executable, and not found — are a precondition failure, not a verdict: the
implementer ran the green half in the worker's environment and this runs in the orchestrator's, so
a runner present for one and absent for the other would otherwise confirm red for every entry of
every task with nothing evaluated. A focused command already failing at the task base for an
unrelated reason still yields a vacuous confirmation, bounded by the clean baseline the pocket
dimension establishes before the first task — the guarantee the green half already rests on.

The restoration trap covers an ordinary failure and an interrupt, not a `SIGKILL` or an abandoned
invocation. Those leave the implementation reverted and no code inside the script can report it,
so the orchestrator checks the tree after every invocation, including one that returned nothing.

Restoration is proved over the reverted paths, not over the whole tree. Anything the red command
writes elsewhere — a cache directory, a coverage file, a build artifact — stays where it landed.
That residue is outside this script's contract; the guardrail run and the whole-branch review
already read the tree it lands in.

The recovery-chain identifier now exists on every run instead of only on runs that had a silent
worker, so dispatch-liveness's required record is populated before a recovery rather than during
one.

The trailer separates a silent worker from its replacement. It does not separate a re-dispatch
after `NEEDS_CONTEXT` or `CANNOT_COMPLETE`, which reuses the unit's current attempt number —
those workers returned, and their reports account for what they did.

This repository's own commits carry the trailer whenever adept is built by adept. No gate reads
commit messages, so nothing else changes.

## Considered & rejected

- **Test-first commit discipline — the implementer commits the failing test alone, and the
  orchestrator checks that commit out and runs the command.** verified: it needs no new
  executable, but `CLAUDE.md` makes per-commit history load-bearing ("Never squash-merge code PRs
  — per-commit history is load-bearing for `git bisect`"), and this plants one deliberately red
  commit per contract in every branch that history is bisected over.
- **Sample one task per run instead of checking every contract.** verified, **for an interpreted
  project only**: the round trip measured in a git fixture on git 2.50.1 is
  `git checkout <base> -- <impl>`, one focused run exiting 1, `git checkout <head> -- <impl>`, and
  `git diff --quiet HEAD -- <impl>` clean — inside the existing worktree, so no dependency install
  is repeated, and sampling would add a selection rule to avoid a cost of one focused run. For a
  compiled project the ground does not hold: the same commands advance mtime twice per entry, and
  the Consequences above record that sampling stays undecided there rather than rejected.
- **Reconstruct in a fresh scratch worktree.** verified: the round trip restores the reverted
  paths to a clean `git diff HEAD -- <paths>` in the existing tree (git 2.50.1, macOS 25.6.0),
  against the cost of installing the project's dependencies again per task. A second worktree
  would additionally contain whatever the red command writes outside those paths, which the trap
  does not; that residue is accepted above rather than paid for with a per-task reinstall.
- **Match the report's expected failure message as well as the exit status.** judgment: the
  message belongs to the test runner, not to a contract anyone maintains — it moves with the
  runner's version and its formatting flags — so matching it would redden the loop on upgrades
  that broke nothing, and there is no stable text to match against.
- **Record a SHA-to-worker table in the ledger instead of a trailer.** judgment: that table is the
  inference the trailer removes, and it is a second copy that disagrees with the commit in exactly
  the race it exists for.
- **Have the orchestrator set the committer identity per worker, so the mark does not depend on
  the worker cooperating.** verified: `git config` is per repository, not per worktree.
  `git -C <linked-worktree> config user.email worker@e` then `git config user.email` in the main
  worktree printed `worker@e` (git 2.50.1, macOS 25.6.0, `extensions.worktreeConfig` unset), so a
  value set for one party worktree applies to the whole checkout — and it would overwrite the
  human's authorship on every commit the branch carries.
  This is the one alternative that does not rely on the untrusted party, and it loses on those
  two grounds rather than on cost. The trailer's dependence on worker cooperation is therefore a
  priced consequence: a worker that omits it is detected, and a worker that forges a sibling's
  value is not.
- **Put the dispatch identity in the commit subject.** verified: `git log
  --format='%(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)'` returns the value on git
  2.50.1 and an empty string for an absent key, so a trailer is queryable without parsing
  subjects — which conventional commits already own.
- **Do nothing.** verified: `skills/forge/SKILL.md` step 6 verifies a focused entry by reading
  that it "contains the red command and expected failure"; no orchestrator step executes it.
