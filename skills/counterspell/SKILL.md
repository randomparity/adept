---
name: counterspell
description: "Reverse a bad merged PR: judge the live damage, choose git revert vs fix-forward using the risk taxonomy's reversal-cost axis, write truthful tracking state, and drive the urgent fix through a reduced pipeline whose review is compressed but never skipped. Use when a merged PR turned out bad."
---
# Reverse a Bad Merge

The path for "a merged PR turned out bad" (#51). `$quest` classifies work before it
starts and never revisits the classification after the merge lands; `$return-to-town`
treats `MERGED` as conclusive because cleanup needs exactly that. This skill runs *after*
both, on the one question neither answers: should what landed be taken back?

ADR 0031 records the decision this skill implements. Read it before your first run; the
summary below is operational, not a substitute.

Invoke with the pull-request number: `$counterspell <PR-number>`.

## 0. Resolve the target

Snapshot once:

```sh
gh pr view <N> --json state,mergedAt,mergeCommit,headRefOid,baseRefName,closingIssuesReferences,title,body
```

Read `state` first. `OPEN` belongs to its own quest's pipeline — stop and say so.
`CLOSED` unmerged needs no reversal — stop and say so. Only `MERGED` proceeds.

Determine the landing shape from the merge commit's parent count:

```sh
git rev-list --parents -n 1 <mergeCommit.oid>
```

Two parents is a merge-commit landing; one parent is a rebase landing. This selects the
mechanical revert route in step 2 — determine it now, before anything is typed.

Collect the originating issues: the PR's closing references plus any issue linked in its
body. If none can be identified, file the regression issue first (step 3); never work
unclaimed.

## 1. Judge whether the damage is live

Name what the merge broke and find evidence it is live: red CI on the base branch after
the merge, broken behavior an installed plugin copy consumes, test failures reproducible
at `origin/<base>`. Say which evidence you observed; a belief that the PR is bad is not
damage.

**No live damage means this skill does not apply.** If review caught the problem before
anything consumed the merge, urgency buys nothing and the reduced pipeline below has no
justification: reopen or file the tracking issue (step 3) and run normal `$quest`.

## 2. Read the reversal cost, then choose

The quest-log skill's `risk:` taxonomy judges how expensive being wrong is. Read the
originating issue's `risk:` label when one carries it. When none does, derive the
assessment from the taxonomy's own criteria and record the derivation in your annotation —
never write a `risk:` label yourself: the taxonomy's human-read invariant binds every
writer, and an unattended assignment nobody saw is a confidently wrong `night-safe` that
looks identical to a correct one. This assessment, recorded, is also the validated risk
assessment that authorizes step 4's lowered review budget.

Choose exactly one disposition:

- **Revert** when all of: the damage is live; the reversal profile is `git revert` alone
  or less (no deploy-order dependency, manual backfill, or third-party state — the
  daytime-only reversal criteria are what disqualify); and no correct fix can land faster
  than the revert.
- **Fix-forward** when any of: a correct fix is small and lands immediately; the reversal
  cost exceeds `git revert`, because reverting trades one broken state for another; or
  consumers already depend on the landed behavior, so removal is itself breaking.
- **Revert now, redesign later** when the capability should return after rework: the
  revert stops the bleeding; the redesign is the working issue's business and runs
  through normal `$quest`, not this pipeline.

Git mechanics, from repo policy:

- Never `git reset --hard`; never any force-push form (`--force-with-lease` included).
  Revert forward, always.
- Under a merge-commit landing: `git revert -m 1 <merge-sha>`. Under a rebase landing:
  revert the range commit-by-commit in reverse order. The shape was determined in step 0.
- Exclude append-only record paths — `docs/adr/` above all — from any revert. Records do
  not roll back: restore them from the pre-revert commit
  (`git restore --source=<sha-before-revert> -- <path>`).
- Revert conflicts that need judgment are not mechanical. Abandon the revert route, fall
  back to fix-forward, and note the conflict in your annotation.

## 3. Write the tracking state

Keyed on one question per originating issue: did the bad PR satisfy that issue's
acceptance criteria?

- **It did not** — reopen that issue. Its closure asserted work that was not delivered;
  reopening is the honest state. Strip any residual `status:` label in the same edit that
  sets the next one, link the bad PR, and post a `WORK:TRAJECTORY` naming the disposition
  and evidence.
- **It did, but something else regressed** — leave the original closed (it was true at
  merge time) and file **one** regression issue for this run, naming every affected PR
  when a reversal spans several delivered features, referencing the bad PR and the
  affected behavior, grounded per the bounty conventions. Leave `risk:` and `priority:`
  unassigned for daytime triage; absence fails closed by design.

The issue whose failure constitutes the live damage is the **working issue**; any other
reopened or affected issues go to `status:ready`, are named in your annotation, and are
nobody's to claim implicitly. The "redesign later" disposition is not extra tracking
state — it is the working issue's business, run through normal `$quest`.

## 4. Run the reduced pipeline

Urgency compresses the standard lifecycle; it does not remove its guards.

1. Branch `hotfix/<slug>-<issue-or-pr-number>` off `origin/BASE_BRANCH`.
2. Claim the working issue under the quest-log claim protocol (mint
   `q<issue>-<8 hex>`, `claim-acquire`, verify, set `status:in-progress`). Skip the full
   charter/spec/plan: ADR 0031 is the standing decision governing this path. Any finding
   or design question this path cannot settle without a new decision means the change has
   outgrown it — release the claim, park per the exit edges, and hand the working issue
   to full `$quest`.
3. Build. For a pure revert the mechanical steps above are the build; verify against the
   evidence that convicted the PR — the test or command that failed now passes. For a
   hotfix, build minimally; scope discipline matters more here than anywhere, because
   every extra change widens the blast radius of an already-bad day.
4. `$trial-loop` adversarial review with **iteration budget 2** — one full pass plus one
   confirming pass. Never zero. The budget's lowering authority is the validated risk
   assessment step 2 produced and recorded. A pure revert still meets a reviewer: partial
   reverts and conflict-driven adaptations are the dominant revert failure, and urgency
   is why the budget shrinks, not why the review disappears.

   Two exits leave the pipeline here: a finding requiring a design decision means the
   change has outgrown this path (release the claim, hand the working issue to full
   `$quest`, per item 2); a blocked stop at the budget — an unresolved consequential
   finding that is not a design question — parks instead: `WORK:TRAJECTORY` first, then
   `status:needs-human`, branch and annotation left in place for the operator's
   approved-continuation decision. An unattended run never continues past its own park.
5. Security pass only under the quest skill's relevance test: a mechanical revert rarely
   triggers it; a hotfix that adds entry points, parses input, or changes defaults does.
6. Guardrails green, then `$deliver`: PR titled `revert: …` or `hotfix: …`, body carrying
   the bad PR number, the chosen disposition and why, the tracking-issue link, and
   acceptance criteria. A hotfix carries `Closes #<working issue>` — its merge delivers
   the fix. A revert PR never carries `Closes`: taking the change back is not delivering
   the working issue's work, so the issue stays open for the correct attempt.
7. Hand off through `$return-to-town`'s default. A delegated run never merges its own
   reversal.

## On a blocker

Park per the quest-log exit edges: `WORK:TRAJECTORY` first, then the label
(`status:blocked` for an external dependency, `status:needs-human` when the pipeline
cannot proceed). A stalled reversal is worse than a slow one — the bad code is live while
you hold it, so surface the blocker immediately rather than improvising past a guard.
