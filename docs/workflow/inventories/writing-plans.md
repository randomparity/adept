# Behaviour inventory — `writing-plans` (absorbed into `$design` as `inscribe`)

Extracted from `skills/writing-plans/SKILL.md` at commit `7e7f969` before any
rewriting, per the rewrite spec §5. Rows are observable behaviours, not wording.
KEEP rows are the regression contract for the `inscribe` phase. DROP rows are
deliberate deletions — the YAGNI filter of §5 — and must not reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Write for an engineer with zero repo context and unknown taste | KEEP | The premise that makes every other rule in the phase necessary |
| 2 | Map which files are created and modified, and each one's responsibility, before defining tasks | KEEP | This is where decomposition is actually decided |
| 3 | Prefer smaller focused files; split by responsibility, not by technical layer | KEEP | Repo standard, and it makes edits more reliable |
| 4 | Follow established patterns in an existing codebase rather than restructuring unilaterally | KEEP | Same discipline as `council` row 10 |
| 5 | Right-size a task to the smallest unit carrying its own test cycle and worth a reviewer's gate | KEEP | The rule that stops both 20-task busywork and 3-task monoliths |
| 6 | Fold setup, config, scaffolding, and docs into the task whose deliverable needs them | KEEP | Corollary of row 5; prevents orphan setup tasks |
| 7 | Split tasks only where a reviewer could reject one and approve its neighbour | KEEP | The operational test for row 5 |
| 8 | End every task with an independently testable deliverable | KEEP | What makes a task reviewable at all |
| 9 | Make each step one action of roughly 2–5 minutes | KEEP | Bite-sized granularity; a step that spans an hour is a task |
| 10 | Order steps as failing test → confirm it fails → minimal implementation → confirm it passes → commit | KEEP | TDD, and the "confirm it fails" step is the one people skip |
| 11 | Start the plan with a fixed header: goal, architecture, tech stack, global constraints | KEEP | Global constraints bind every task implicitly; without the block they are re-derived per task |
| 12 | Copy project-wide requirements into Global Constraints verbatim, with exact values | KEEP | A paraphrased version floor is a wrong version floor |
| 13 | Give each task exact file paths, an Interfaces block naming what it consumes and produces, and complete code in every step | KEEP | A context-free implementer cannot infer a signature |
| 14 | Refuse named placeholder patterns — "TBD", "add appropriate error handling", "similar to Task N", references to undefined types | KEEP | Enumerated failures, not a vague exhortation; this is why the list is a list |
| 15 | Repeat code rather than cross-referencing another task, since tasks are read out of order | KEEP | The one place DRY is deliberately not applied, and the reason is stated |
| 16 | Self-review the finished plan for spec coverage, placeholders, and type-name consistency across tasks | KEEP | Catches the `clearLayers()`/`clearFullLayers()` class before an implementer hits it |
| 17 | Add a task when self-review finds a spec requirement with no task | KEEP | Makes row 16 actionable rather than advisory |
| 18 | Suggest splitting into one plan per subsystem when the spec spans several | KEEP | The plan-level counterpart of `council` row 2 |
| 19 | Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` | KEEP | Durable artifact; `$design`'s context checkpoint depends on it |
| 20 | Announce the skill and its resolved mode at start | DROP | Same as `council` row 14 |
| 21 | Carry a "dispatched workflow mode" section defining caller-owned sequencing | DROP | §1: exists only because `$design` calls this skill |
| 22 | Consume and carry forward an eight-field scope charter from the caller | DROP | No skill boundary is crossed any more; `$design` holds the charter once |
| 23 | Offer the user a choice between subagent-driven and inline execution at the end | DROP | `$build-tdd` picks the execution mode from what the plan looks like; the source's own dispatched mode already deletes this |
| 24 | Note that an isolated worktree should have been created by `using-git-worktrees` | DROP | Workspace setup belongs to `$build-tdd` per §1's disposition table |
| 25 | Name `subagent-driven-development` or `executing-plans` as the required next skill | DROP | Both are absorbed into `$build-tdd` in a later unit; naming them here would be a phantom reference the moment that lands |
| 26 | Give every verification step the exact command and the output to expect from it | KEEP | Found by the completeness check against `## Remember`, which rows 1–25 did not cover. "Run the tests" cannot be checked by the implementer or the reviewer; a named command with a stated expected result can. Appended rather than inserted so the row numbers this plan already cites stay stable |

**Totals:** 26 rows — 20 KEEP, 6 DROP.
