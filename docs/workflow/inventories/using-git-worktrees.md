# Behaviour inventory — `using-git-worktrees` (absorbed into `$build-tdd` as `pocket-dimension`)

Extracted from `skills/using-git-worktrees/SKILL.md` at commit `760c91a` before
any rewriting, per the rewrite spec §5. Rows are observable behaviours, not
wording. KEEP rows are the regression contract for the `pocket-dimension` mode.
DROP rows are deliberate deletions — the YAGNI filter of §5 — and must not
reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Detect existing isolation before creating anything, comparing `git rev-parse --git-dir` against `--git-common-dir` | KEEP | Creating a worktree inside a worktree is the failure this prevents, and the check is two commands |
| 2 | Guard that comparison with a submodule check (`git rev-parse --show-superproject-working-tree`) | KEEP | `GIT_DIR != GIT_COMMON` is also true in a submodule, so the naive check misfires there. This is a real bug fixed once and easily lost |
| 3 | On detecting isolation, report the path and whether HEAD is detached, then skip creation | KEEP | Detached HEAD changes what has to happen at finish time; the report is where that surfaces |
| 4 | Ask consent before creating a worktree, unless a preference is already declared | KEEP | It changes where the user's work lives; a declared preference is honoured without asking |
| 5 | Work in place and continue if the user declines | KEEP | Declining is an answer, not a blocker |
| 6 | Prefer the harness's native worktree tool over `git worktree add` | KEEP | `git worktree add` behind a harness that manages worktrees creates phantom state the harness cannot see |
| 7 | Refuse the native tool when it would nest the worktree inside the repository tree, and fall back to `git worktree add` at an external path | KEEP | The exception that makes row 6 safe rather than absolute |
| 8 | Never place a worktree inside the working copy — not `.worktrees/`, not `worktrees/`, not under `.codex/`, not any subdirectory, and not fixed by a `.gitignore` entry | KEEP | Whole-tree tooling walks it and fails your commit on another agent's in-flight code; not all such tools honour `.gitignore`. This is the rule the whole skill is built around |
| 9 | Choose the directory by priority: explicit instruction, then an existing `../<repo>-worktrees/` sibling root, then that path as the default | KEEP | Predictable placement, and it is what `$ship-pr`/`$merge-cleanup` later use to decide a worktree is ours |
| 10 | Override even an explicit instruction that names a path inside the repo, and say so | KEEP | Row 8 outranks row 9; without this the priority list quietly defeats the rule |
| 11 | Verify after creation that the worktree resolves outside the repo root, and relocate if not | KEEP | The check that makes rows 8–10 evidenced rather than intended |
| 12 | On a sandbox permission denial, say the sandbox blocked it and work in place | KEEP | Distinguishes an environment refusal from a mistake, and names the degraded mode instead of failing silently |
| 13 | Auto-detect and run project setup for the languages present | KEEP | A worktree without dependencies fails its baseline for a reason that is not the code |
| 14 | Verify a clean test baseline before implementing | KEEP | Without it, a pre-existing failure gets attributed to this change |
| 15 | On a failing baseline: interactive, report and wait; dispatched with authority that explicitly addresses the failure, follow it; dispatched without, return a blocker | KEEP | The three-way branch is the point — generic autonomy language is not authority to proceed past a red baseline |
| 16 | Report the ready state: path, test count, what is about to be implemented | KEEP | The handoff the execution modes read |
| 17 | Announce the skill at start | DROP | A mode inside a document does not announce itself |
| 18 | Carry a `## Mode` section establishing interactive-vs-dispatched and the narrowness of written authority | DROP | §1: the mode apparatus exists because a caller dispatches this skill. Row 15 keeps the one behaviour that apparatus governed |
| 19 | Restate the steps as a Quick Reference table of 13 situation/action rows | DROP | A third statement of the same sequence. Any row whose content is not already in a step must be folded into that step before this table goes — the table is redundant, not wrong |
| 20 | Restate them again as Common Mistakes with problem/fix pairs | DROP | A fourth statement. Same condition as row 19: fold, then delete |
| 21 | Restate them a fifth time as Red Flags "Never"/"Always" lists | DROP | Same condition as rows 19 and 20. Between them these three tables are 70 lines restating 100 lines of steps |

**Totals:** 21 rows — 16 KEEP, 5 DROP.

Rows 19–21 carry a condition rather than a plain deletion: the tables restate
the steps, but a restatement occasionally carries a clause the step omitted.
Fold anything not already in a step into that step, then delete the table. Check
this explicitly rather than assuming redundancy — that assumption is how a rule
disappears while every gate stays green.
