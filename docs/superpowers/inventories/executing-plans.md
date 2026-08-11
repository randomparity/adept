# Behaviour inventory — `executing-plans` (absorbed into `$build-tdd` as `cast`)

Extracted from `skills/executing-plans/SKILL.md` at commit `760c91a` before any
rewriting, per the rewrite spec §5. Rows are observable behaviours, not wording.
KEEP rows are the regression contract for the `cast` mode. DROP rows are
deliberate deletions — the YAGNI filter of §5 — and must not reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Read the plan before starting anything | KEEP | The mode is "execute this plan"; skipping the read is executing something else |
| 2 | Review the plan critically for questions and concerns before the first task | KEEP | A defect in the plan costs one fix here and one per task later |
| 3 | Raise those concerns before executing rather than discovering them mid-task | KEEP | The half of row 2 that makes it useful; a noted-but-unraised concern changes nothing |
| 4 | Create a todo per plan task, so progress is tracked outside the conversation | KEEP | Conversation memory does not survive compaction; this is the cheap version of `party`'s ledger |
| 5 | Mark each task in-progress before working it and complete only after its verifications pass | KEEP | "Complete" claimed before the verification ran is the false-green this repo exists to prevent |
| 6 | Follow the plan's steps exactly, since they are already bite-sized | KEEP | The plan phase spent its effort on that granularity; improvising past it discards the work |
| 7 | Run the verifications the plan specifies, not a substitute | KEEP | A different check is not the check the plan reasoned about |
| 8 | Stop on a genuine blocker — missing dependency, failing test, unclear instruction, repeated verification failure — rather than guessing past it | KEEP | Guessing past a blocker produces work that looks done and is not |
| 9 | Return to the plan review when the plan itself changes or the approach needs rethinking | KEEP | Otherwise an amended plan is executed against a stale reading of it |
| 10 | Never start implementation on `main`/`master` without explicit consent | KEEP | Repo policy independently, and the one irreversible mistake in this mode |
| 11 | Announce the skill and its resolved mode at start | DROP | A mode inside a document does not announce itself, and the mode it announced does not survive |
| 12 | Carry a "Dispatched mode — no human in the turn" section | DROP | §1: the section exists only because `$build-tdd` calls this skill. The call is gone |
| 13 | Terminate in `finishing-a-development-branch` and present an integration menu | DROP | `$build-tdd` is not the end of the pipeline; `$review-loop`, `$simplify-changes`, `$ship-pr` and `$merge-cleanup` follow and own integration. The source's own dispatched mode already deletes this |
| 14 | Open by telling the reader to prefer `subagent-driven-development` where subagents are available | DROP | That choice is now `$build-tdd`'s mode selection, made before either mode's body is read. A mode that argues against itself in its own first line is the caller/callee split talking |
| 15 | Carry an Integration list naming `using-git-worktrees`, `$design`, and `finishing-a-development-branch` as required sibling skills | DROP | Two of the three are modes of this same document after this unit; the list describes a topology that no longer exists |

**Totals:** 15 rows — 10 KEEP, 5 DROP.
