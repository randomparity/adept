# Post-merge reversal (`$counterspell`) — implementation plan

Date: 2026-08-22 · Issue: #51 · Spec: [2026-08-22-post-merge-reversal-design.md](../specs/2026-08-22-post-merge-reversal-design.md) · ADR: [0031](../../adr/0031-counterspell-owns-post-merge-reversal.md)

## Goal

Implement the ADR 0031 decision: a new `counterspell` skill plus three wiring edits
(quest-log executor pointer, return-to-town routing, cheatsheet reference) and the
gate-mandated version bump.

## Architecture

Instructions-only change: one new `SKILL.md`, three edited Markdown files, one JSON
version field. No scripts, no processes (repo anatomy rules 1–3). Verification is the
guardrail suite plus a mutation check of shape rule 6.

## Global Constraints

- Repo is public: name the checkout root `$WORK`; never absolute host paths
  (`scripts/check-public-safety.sh` enforces).
- Conventional commits, imperative mood, ≤72-char subject, one logical change each.
- ADR number is **0031**, pre-assigned by the orchestrator. Do not renumber.
- No index table in `docs/adr/README.md` — the records gate warns (`W-INDEX-TABLE`) if
  one appears. Add no row despite the dispatch's "coupled" note; the repo's actual gate
  has no index coupling.
- Plugin version: MINOR bump (new skill added), `.claude-plugin/plugin.json` only,
  strictly greater than base (`2.8.1` → `2.9.0`).
- Every `` `$name` `` invocation written into any SKILL.md must resolve to an existing
  skill (shape rule 4); every relative link into `references/` must resolve (rule 5);
  every skill name must appear backtick-wrapped in `docs/cheatsheet.md` (rule 6).
- Guardrail: `just ci` (== `just verify`). Run gates bare; no pipes swallowing exits.
- Bash 3.2 floor applies to any script touched — none is planned.

---

## Task 1 — Create `skills/counterspell/SKILL.md`

**Files:** creates `$WORK/skills/counterspell/SKILL.md`. Nothing else in the directory;
rule 1 makes supporting files an exception requiring argument, and none is argued.

**Interfaces:** consumes quest-log's claim protocol, annotation convention, risk-taxonomy
criteria, and park rules; consumed by nothing yet (return-to-town gains a route pointer in
Task 3).

Exact content:

````markdown
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
````

**Acceptance:** file exists; frontmatter `name:` matches directory; rules 1–3 of
`scripts/check-skill-shape.sh $WORK` pass. Rule 6 necessarily still reports
`counterspell: not referenced in docs/cheatsheet.md` until Task 4 lands — expect exactly
that one finding at this checkpoint, and defer the full `just ci` to Task 6.

## Task 2 — Point the risk taxonomy at its executor (`skills/quest-log/SKILL.md`)

**Files:** modifies `$WORK/skills/quest-log/SKILL.md`, end of the `## Risk dimension`
section, immediately after the human-read-invariant paragraph (before `## Claim protocol`).

Insert:

```markdown
**Executor.** Triage reasons about reversal cost before work starts; `$counterspell` is
where that reasoning runs again if the change lands bad. It reads the label — or
re-derives the assessment from these criteria when none exists, reporting rather than
writing, since the invariant above binds every writer — to choose between `git revert`
and fixing forward (ADR 0031).
```

**Acceptance:** the paragraph sits inside `## Risk dimension`, names `$counterspell`,
does not duplicate the criteria.

## Task 3 — Route bad merges out of `$return-to-town`

**Files:** modifies `$WORK/skills/return-to-town/SKILL.md`, immediately after the state
interpretation list (the bullet beginning "Only `OPEN` continues below.").

Insert:

```markdown
`MERGED` is conclusive for cleanup and tracking; it is not a quality verdict. When the
operator reports the merged PR as bad, do not improvise a revert here — invoke
`$counterspell` with the PR number (ADR 0031) and let it choose the disposition and
write the tracking state.
```

**Acceptance:** `MERGED` semantics unchanged for the normal path; the only new behavior
is the routed exit.

## Task 4 — Cheatsheet reference (`docs/cheatsheet.md`)

**Files:** modifies `$WORK/docs/cheatsheet.md`.

Two edits:

1. "Start here" table, after the `/return-to-town` row:

```markdown
| A merged PR turned out bad | `/counterspell` |
```

2. "Batch orchestration & hygiene" table, after the `resurrection` row:

```markdown
| `counterspell` | Reverse a bad merged PR: revert or fix-forward, tracking writes, expedited-but-present review |
```

The bare-backtick row is load-bearing: shape rule 6 greps `` `counterspell` `` literally,
and the `/counterspell` form alone does not satisfy it.

**Acceptance:** `rg --no-config -qF -- '`counterspell`' docs/cheatsheet.md` exits 0;
mutation check (remove both rows, run `scripts/check-skill-shape.sh $WORK`, expect exit 1
naming counterspell; restore).

## Task 5 — Version bump (`.claude-plugin/plugin.json`)

**Files:** modifies `$WORK/.claude-plugin/plugin.json`, `"version": "2.8.1"` →
`"2.9.0"`. MINOR per ADR 0022's rule: a skill was added.

**Acceptance:** the bump rule exercised locally against the real base —
`BASE_SHA=$(git merge-base origin/main HEAD) scripts/check-plugin-version.sh` exits 0
(unset `BASE_SHA` validates format only and would pass even without the bump); CI
enforces the strict-greater-than-base rule again on the branch.

## Task 6 — Verify

1. `just ci` bare, from `$WORK`. Expect exit 0, no warnings.
2. Mutation check from Task 4.
3. Confirm no `docs/adr/README.md` table exists and `just records` reports clean.
