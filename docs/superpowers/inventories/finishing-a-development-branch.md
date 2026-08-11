# Behaviour inventory — `finishing-a-development-branch` (absorbed into `$ship-pr` + `$merge-cleanup` as `long-rest`)

Extracted from `skills/finishing-a-development-branch/SKILL.md` at commit
`eaab678` before any rewriting, per the rewrite spec §5. Rows are observable
behaviours, not wording.

Verdicts are the three from unit 3:

- **ADD** — must be written at a destination in this unit.
- **CARRIED** — already stated at the named destination, with the evidence
  quoted. Verify, do not restate.
- **DROP** — deliberately deleted, with a reason.

## The finding that shapes this unit

This skill implements a **different integration model** from the one this repo's
pipeline uses. It asks the operator to choose among *merge locally*, *push and
open a PR*, *keep the branch*, and *discard the work*. The pipeline has exactly
one integration path — `$build-tdd` → `$review-loop` → `$simplify-changes` →
`$ship-pr` → `$merge-cleanup` — and three of those four options do not exist
anywhere in it:

- **Merge locally** is forbidden outright. `CLAUDE.md`: "Never commit to `main`.
  Branch, open a pull request". The skill's own Step 4 says to drop the option
  where the base branch is protected, so it drops itself here.
- **Keep as-is** and **discard** are the absence of the pipeline, not steps in
  it. `$build-tdd` already states the boundary: "neither mode presents an
  integration menu and neither takes a merge, push, or discard."

So the menu, its option bodies, and the tables restating them are not behaviours
this repo lost — they are behaviours it never had. What is worth extracting is
the **worktree teardown** knowledge underneath the menu, which is real, hard-won,
and only partly present at the destinations.

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | Verify the project's tests pass before taking any integration action | CARRIED | `$ship-pr` §1 — "Before the first push, run the **full** local check suite once (not just the focused tests for the files you touched)". Stronger than this skill's single test command |
| 2 | On failing tests, stop — do not merge or open a PR | CARRIED | `$ship-pr` §3.2 — "If a required check fails, inspect the failure, fix it, run relevant local guardrails, push, and restart the loop", and the exit condition in §3.4 that only green + `CLEAN`/`MERGEABLE` satisfies |
| 3 | Determine the base branch rather than assuming `main` | CARRIED | `$ship-pr` preamble — "`BASE_BRANCH` and guardrail commands are already recorded from `$preflight`. If running standalone, discover them first" |
| 4 | Detect a linked worktree by comparing `git rev-parse --git-dir` against `--git-common-dir`, both resolved with `pwd -P` | CARRIED | `$build-tdd` pocket dimension — the same two-line `GIT_DIR`/`GIT_COMMON` block, plus the submodule check this skill lacks |
| 5 | A detached HEAD needs a branch created before the work can be published | ADD | `$ship-pr`. `$build-tdd` detects it and defers — "detached means a branch has to be created at finish time" — and finish time is now `$ship-pr`, which currently says only "Push the branch" and has no branch to push |
| 6 | Where the harness created the workspace, prefer its own workspace-exit tool over `git worktree remove` | ADD | `$merge-cleanup`. `$build-tdd` warns about exactly this on the creation side — "running `git worktree add` behind it creates phantom state it cannot see" — and the teardown side is the same hazard with nothing said about it |
| 7 | Run `git worktree prune` after removal, to clear stale registrations | ADD | `$merge-cleanup`. Its step 6 prunes **remote-tracking branches**, which is `git remote prune` — a different command clearing different state. Nothing there prunes worktree registrations |
| 8 | Remove the worktree before deleting the branch it holds | CARRIED | `$merge-cleanup` — "Worktree removal comes before branch deletion because a branch checked out in a worktree cannot be deleted at all — the reverse order refuses every time it matters" |
| 9 | `cd` to the main checkout before removing a worktree, because the command misbehaves from inside the worktree being removed | CARRIED | `$merge-cleanup` step 1 — "you are standing in the directory step 2 removes… `git worktree remove .` succeeds and takes your working directory with it" |
| 10 | Do not remove a worktree you did not create | CARRIED | `$merge-cleanup` step 2 and the paragraph below it — "Step 2's scoping is load-bearing, not a formality. A worktree another agent created belongs to that agent, and merging its pull request does not prove it has stopped" |
| 11 | Do not clean up the worktree merely because a PR now exists — it is needed to iterate on review feedback | CARRIED | Structural, and stronger than a rule: `$ship-pr` contains no cleanup at all, and every teardown step lives in `$merge-cleanup` under "After a merge (yours or the user's)" |
| 12 | Never force-push without an explicit request | CARRIED | `$ship-pr` §1 — "once a branch is pushed to a shared remote the harness blocks force-push and interactive rebase"; `$merge-cleanup` — "never rebase a pushed branch: force-push is denied" |
| 13 | Verify success before removing anything | CARRIED | `$merge-cleanup` — the entire teardown sits under "After a merge", and its serial-merge rule adds "Never merge an unmergeable PR on the strength of previously-green checks" |
| 14 | Decide worktree provenance by testing whether its path sits under `../<repo>-worktrees/` or a legacy nested `.worktrees/`/`worktrees/` | DROP | **This test is wrong in this pipeline and would cause the incident row 10 exists to prevent.** `$build-tdd` directs *every* agent to place its worktree under the `../<repo>-worktrees/` sibling root, so a path prefix match proves only that some adept agent created it — not that *this run* did. Adopting it would return `OURS=yes` for a peer's live worktree. `$merge-cleanup`'s "this run created" is the correct test, and its unknown case is already conservative: leave it alone and record it as deferred |
| 15 | Present exactly four integration options — merge locally, push and PR, keep as-is, discard — and never an open-ended "what next?" | DROP | The pipeline has one path. See the finding above |
| 16 | Drop the local-merge option where the base branch is protected, renumbering the rest | DROP | Consequence of row 15. `CLAUDE.md` forbids committing to `main`, so the option is dropped permanently rather than conditionally |
| 17 | Present a reduced three-option menu on a detached HEAD | DROP | Consequence of row 15. The substantive part of the detached-HEAD case — that a branch must be created — is row 5 |
| 18 | Merge locally: `cd` to the main root, checkout base, pull, merge, re-run tests on the merged result, then delete the branch | DROP | No local-merge path exists. The merged-result concern survives as `mergeStateStatus` `CLEAN`, which `$ship-pr` §3.3 already insists on over green checks alone: "checks run on the branch head, not the merge result" |
| 19 | After a local merge, do not push the base branch as a follow-on | DROP | Consequence of row 18 — there is no local merge to follow on from, and `CLAUDE.md` forbids the push independently |
| 20 | Discard: list the branch, commits and worktree, require the operator to type `discard`, then force-delete | DROP | No discard path exists. The only branch deletion in the pipeline is `$merge-cleanup` step 5, "Delete the **merged** local branch", so the destructive act this confirmation guards — throwing away unmerged commits — is not reachable from it |
| 21 | Keep-as-is: report the branch name and worktree path and change nothing | DROP | The absence of an action is not an action |
| 22 | Announce the skill and the resolved mode at start | DROP | A ritual, not a behaviour. Dropped in units 1–3 for the same reason |
| 23 | Carry a "Dispatched mode — no human in the turn" section resolving caller-vs-human before anything else | DROP | Spec §1: these sections "exist solely because a first-party wrapper calls it", and the caller/callee split is gone. `$ship-pr` and `$merge-cleanup` are wrappers themselves; each already carries its own **Caller contract** |
| 24 | Carry a Quick Reference table mapping each option to merge/push/keep-worktree/cleanup | DROP | Restates rows 15–21, all dropped |
| 25 | Carry a Common Mistakes list (nine entries) | DROP | Restatement. **Condition:** confirm each entry maps to a row above before deleting — the fold-then-delete check that rescued two clauses in unit 2. Verified: test verification → 1; open-ended questions → 15; cleanup after PR → 11; delete-before-remove → 8; remove from inside → 9; harness-owned worktrees → 6, 10; unresolved path compare → 4, 14; menu with nobody present → 23; no discard confirmation → 20 |
| 26 | Carry a Red Flags list (nine Never, eight Always) | DROP | Restatement. **Same condition, verified:** failing tests → 1, 2; merge without verifying → 13; delete without confirmation → 20; force-push → 12; remove before confirming merge → 13; clean up others' worktrees → 10; remove from inside → 9; menu in dispatched mode → 23; push base after merge → 19. Always: resolve mode → 23; verify tests → 1; detect environment → 4; exact option count → 15; typed confirmation → 20; cleanup for options 1 & 4 → 11; `cd` first → 9; `worktree prune` → 7 |

**Totals:** 26 rows — 3 ADD, 10 CARRIED, 13 DROP.

Thirteen of twenty-six behaviours describe an integration model this repo does
not use, and ten of the remaining thirteen were already stated at a destination.
Three sentences are owed: a detached HEAD needs a branch before it can be pushed,
a harness-created workspace is torn down with the harness's own tool, and
`git worktree prune` is not `git remote prune`.

The most useful row is **14**, which is not a deletion for tidiness. Carrying
that path test forward would have imported a rule that returns "ours" for other
agents' live worktrees — the exact failure `$merge-cleanup` already spends a
paragraph preventing.
