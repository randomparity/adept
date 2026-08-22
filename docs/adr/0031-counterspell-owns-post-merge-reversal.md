# 0031 — `$counterspell` owns the post-merge reversal path

## Status

Accepted (2026-08-22)

## Context

Nothing in the lifecycle handles "a merged PR turned out bad" (#51). The `risk:` taxonomy
in the quest-log skill reasons carefully about reversal cost at triage — reversible by
`git revert` alone vs. deploy-order dependencies vs. manual backfill — but no skill ever
executes that reasoning after a merge lands. `$return-to-town` treats `MERGED` as
conclusive and moves straight to tracking and cleanup; `$campaign` verifies a PR before
merging it but has no reconsideration path once merged; and `$quest`'s trivial-bugfix
classification is a pre-merge scoping decision with no expedited variant. Prior art is one
plan-local rollback section (`docs/workflow/plans/2026-08-11-close-the-upstream-attribution.md`,
"Rollback") written for a single merge shape and not reusable as-is.

This repo ships a plugin where every merge to the base branch is effectively a release:
the version gate means an installed copy picks the change up on its next update. That is
what makes a defined reversal path load-bearing rather than nice-to-have.

## Decision

A new standalone skill, **`$counterspell`**, owns post-merge reversal. It takes the bad
PR number, judges whether the damage is live, chooses revert or fix-forward using the
risk taxonomy's reversal-cost axis, writes the tracking state, and drives the fix through
a reduced pipeline whose review is compressed — iteration budget 2, the same floor as a
trivial bugfix — but never skipped.

### Revert vs. fix-forward

The choice reads the originating issue's `risk:` label when one exists; when absent,
`$counterspell` derives the assessment from the taxonomy's own criteria and records it in
its annotation. It never writes a `risk:` label itself: the taxonomy's human-read
invariant binds every writer, so an unattended run reports its derivation instead of
assigning.

- **Revert** when *all* of: the damage is live on the base branch (red CI, broken
  behavior an installed copy consumes); the reversal profile is `git revert` alone or
  less (the night-safe/night-watch reversal criteria); and no correct fix can land faster
  than the revert.
- **Fix-forward** when *any* of: a correct fix is small and lands immediately; the
  reversal cost exceeds `git revert` (deploy-order dependency, manual backfill,
  third-party state — the daytime-only reversal criteria), because reverting would trade
  one broken state for another; or consumers already depend on the landed behavior, so
  removal is itself breaking.
- **Revert now plus a follow-up issue** when the capability should return after rework:
  the revert stops the bleeding, the follow-up issue carries the redesign through the
  normal pipeline.

Git mechanics follow repo policy: never `git reset --hard`, never any force-push form;
revert forward, always. Under a merge-commit landing, `git revert -m 1 <merge-sha>`;
under a rebase landing, revert the range commit-by-commit in reverse order. A revert that
would touch `docs/adr/` or other append-only records stops at those paths — records are
append-only once merged, so the revert restores them from the pre-revert commit rather
than rolling them back. Revert conflicts that need judgment are not mechanical; they end
the revert route and the run falls back to fix-forward.

### Tracking state

Keyed on whether the bad PR satisfied its own issue's acceptance criteria:

- It did not → **reopen the original issue**. Its closure asserted work that was not
  delivered; reopening is the honest state. Strip any residual `status:` label, link the
  bad PR, and let this run claim the reopened issue under the standard claim protocol if
  the fix proceeds now, or leave it `status:ready` if it does not.
- It did, but regressed something else → the original issue stays closed (it was true at
  merge time); **file a new regression issue** referencing the bad PR and the affected
  behavior, following the bounty conventions for a grounded issue. Leave `risk:` and
  `priority:` to daytime triage; absence fails closed by design.

Both cases get `WORK:*` annotations naming the disposition and the evidence, so a later
session reads the whole story from GitHub.

### The reduced pipeline

Entry assumes the attunement facts of the repository are already known; the path skips
spec/ADR/plan authorship because *this* record is the standing decision governing it, and
skips the scope audit for the same reason. What remains:

1. Branch `hotfix/<slug>-<issue-or-pr-number>` off `origin/BASE_BRANCH`.
2. Claim the working issue (reopened original or new regression issue) per the claim
   protocol; set `status:in-progress`.
3. Build. For a pure revert the mechanical steps above *are* the build; verify against
   the evidence that convicted the PR — the test or command that failed now passes.
4. `$trial-loop` adversarial review, **iteration budget 2** — never zero. This is the
   clause that keeps urgency from becoming a silent review skip: a pure revert still
   meets one reviewer, because partial reverts and conflict-driven adaptations are the
   dominant failure mode of reverts, not of ordinary changes. If a finding requires a
   design decision, the change has outgrown this path: park and run full `$quest` on the
   tracking issue.
5. Security pass only under the quest skill's relevance test (a mechanical revert rarely
   triggers it; a hotfix that adds code can).
6. Guardrails green, then `$deliver`: PR titled with a `revert:` or `hotfix:` prefix,
   body carrying the bad PR number, the chosen disposition and why, the tracking-issue
   link, acceptance criteria, and `Closes #<working issue>`.
7. Hand off through `$return-to-town`'s default. Delegated runs never self-merge.

If there is no live damage — the problem was caught by review before anyone consumed it —
urgency buys nothing and the reduced pipeline should not be used: file or reopen the
tracking issue and go through normal `$quest`.

## Consequences

- The plugin gains a twenty-ninth skill: `counterspell/` with one `SKILL.md`, a
  cheatsheet row, and a MINOR version bump per the version gate.
- The risk taxonomy gains an executor: the quest-log skill points its reversal-cost
  axis at `$counterspell` instead of leaving it reasoning about a moment (triage) that
  never comes again after the merge.
- `$return-to-town` keeps `MERGED` as conclusive *for cleanup*, and gains one routed
  exit: an operator-reported bad merge invokes `$counterspell` rather than being
  improvised as a revert inside the hand-off flow.
- Urgent fixes get a bounded fast lane whose cost ceiling is explicit (budget 2) and
  whose floor is also explicit (one full review pass plus one confirming pass).
- The reopen-vs-new-issue rule makes the tracker's history truthful: an issue closed by a
  PR that failed its own criteria does not stay closed, and an issue genuinely delivered
  does not get blamed for an unrelated regression.

## Considered & rejected

- **A documented fast path through `$quest`'s trivial-bugfix classification.**
  verified: `skills/quest/SKILL.md` classifies at step 1 (:59–78), before any branch
  exists, and its abbreviated path (:215–229) starts from an open issue and a frozen
  charter and then runs the same nine-step pipeline; a post-merge failure starts from a
  merged PR, often a closed issue, and a moved base. judgment: threading inverted-entry
  conditionals through a 759-line working skill costs more than a new entry point and
  risks the ordinary path, which every issue runs.
- **Teach `$return-to-town` to reverse merges inline.** verified:
  `skills/return-to-town/SKILL.md`'s `MERGED` branch (:50–56) is deliberately
  tracking-and-cleanup only, and the skill runs at the end of *every* successful quest.
  judgment: putting an adversarial was-this-merge-wrong judgment into a flow that runs
  unconditionally invites it to fire on healthy hand-offs, and grows the most
  frequently-run closing skill into a second quest.
- **Do nothing; keep per-plan rollback sections like the attribution plan's.**
  verified: the prior art (`docs/workflow/plans/2026-08-11-close-the-upstream-attribution.md`
  :965–993) is prose bound to one PR's merge shape and one gate's failure modes; nothing
  else in the tree executes a reversal, and the next bad merge would start from the same
  blank page #51 filed. judgment: a recurring emergency procedure that lives only in
  unrelated plans is not a procedure.
- **Always reopen the original issue.** verified: the issue labels carry
  `status:`/closed-state semantics where closed-state is authoritative
  (`skills/quest-log/SKILL.md`, label state machine rules). judgment: reopening an issue
  whose acceptance criteria were met blames the delivered work for someone else's
  regression and muddies the history a retrospective reads.
