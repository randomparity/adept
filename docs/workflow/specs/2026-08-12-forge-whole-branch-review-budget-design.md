# Forge's whole-branch review gets a token budget

Design for issue [#46](https://github.com/randomparity/adept/issues/46).
Decision record: [ADR 0007](../../adr/0007-whole-branch-review-package-and-report.md).

## Problem

`$forge`'s **party** mode runs three kinds of dispatch, and two of them are
budgeted:

| Dispatch | Diff delivery | Return |
|---|---|---|
| implementer (`implementer-prompt.md`) | n/a | detail to `[REPORT_FILE]`, message capped at fifteen lines |
| task reviewer (`task-reviewer-prompt.md`) | `[DIFF_FILE]` from `scripts/review-package` | the message *is* the report, every line a verdict, a cited finding, or a check |
| whole-branch reviewer (`code-reviewer.md`) | raw `git diff --stat` + `git diff`, run by the reviewer | the whole review, inline, uncapped |

The third is the most expensive of the three — it runs on the most capable
model, over the whole branch rather than one task — and it is the only one with
no budget at all. `SKILL.md` already asserts the opposite of what the template
does: "Hand artifacts over as **files**, not pasted text" and "Every reviewer
dispatch ends with the same report contract, so you get a bounded verdict rather
than the whole review."

Two costs follow, and they are different in kind. On the reviewer's side the
diff is whatever range it resolves itself, at `git diff`'s default three lines
of context, so a hunk whose end it cannot see costs a tree excursion. On the
controller's side the entire review — Strengths, three severity buckets,
Recommendations, Assessment — lands in context and stays resident, re-read on
every later turn of the build.

## Requirements

- **R1** — The whole-branch reviewer is handed a review-package path produced by
  `skills/forge/scripts/review-package BASE HEAD`, rather than running
  `git diff --stat` and `git diff` itself.
- **R2** — The whole-branch reviewer writes its detailed review to a file at a
  path the controller supplies.
- **R3** — The reviewer's inline return message carries a hard cap, the way
  `implementer-prompt.md` caps its return.
- **R4** — `SKILL.md`'s final-review dispatch step tells the controller to
  generate the package and supply both paths, verify both files, and hand the
  fix subagent the review-file path rather than a findings list the controller
  had to read.
- **R5** — `just verify` is green.

Out of scope, per the frozen charter on issue #46: the review rubric and its
`Critical / Important / Minor` severity vocabulary (ADR 0003 and
`skills/gauntlet/SKILL.md`'s severity mapping read those literal words);
`scripts/review-package` itself; `task-reviewer-prompt.md` and
`implementer-prompt.md`; and any new script or supporting file.

## Design

### The package (R1)

The controller already runs `scripts/review-package BASE HEAD` before every task
review. The final review uses the same call with the branch's own endpoints —
the base the branch left from, and `HEAD` after the last task's fix cycle
closed. The script keys its default destination to the abbreviated range, so a
re-review after a fix wave writes a new file rather than overwriting the reading
it should be compared against.

What this buys is determinism and fewer round trips rather than fewer tokens:
the range is the controller's own known-good one instead of whatever the
reviewer types, the commits and per-file stat arrive with the hunks, and `-U10`
means a hunk's end is visible without opening the tree. `-U10` is strictly more
input than a default `git diff`; the saving is in what the reviewer does *not*
have to go and read.

`code-reviewer.md`'s `## Git Range to Review` section becomes
`## The change you are judging`, naming `[DIFF_FILE]` and carrying the same
three rules the task reviewer's equivalent section carries: open the package
once, treat its wide context lines as the files as they now stand, and rebuild
with `git diff --stat` / `git diff` only if the package is missing.

Those three are delivery rules, and only those three cross over. The task
reviewer's *scoping* rule — "Stay out of the rest of the codebase" — does not,
and the section says so. This is the one review whose value is seeing what a
task-scoped reviewer could not: the plan it was built against, the call sites of
a contract the branch changed, the documentation that went stale. Importing the
package while quietly importing task scope with it would narrow the review this
change is supposed to leave intact.

The `## Read-Only Review` section stays but gains one clause. It is a safety
rule about the checkout, not about diff delivery, and the worktree escape hatch
is the sanctioned way to lay another revision out on disk — but as written it
says the working tree stays exactly as found, and R2 now asks the reviewer to
write a file into it. The rule names the exemption as the supplied
`[REVIEW_FILE]` path and nothing else, tracked or ignored: the same directory
holds the controller's own progress ledger, so exempting the workspace rather
than the one path would hand a reviewer write access to it. Left as it is, the
template would instead carry an instruction to write and a rule forbidding it.

### The review file (R2)

The controller supplies `[REVIEW_FILE]`. Its path lives in the `$forge`
workspace that `scripts/sdd-workspace` resolves — the same directory the briefs,
implementer reports, and review packages already occupy, and the only place a
write is covered by the self-ignoring `.gitignore` that keeps this phase's
artifacts out of `git status` and out of the PR diff.

The path is keyed to the same abbreviated range as the package —
`final-review-<base7>..<head7>.md` — so a re-review after a fix wave writes
alongside its predecessor instead of over it, matching what `review-package`
already does for the same reason.

The slot is named `[REVIEW_FILE]` rather than `[REPORT_FILE]` because both
sibling templates already use the latter, and in `task-reviewer-prompt.md` it
means *the implementer's report you read*. One name carrying two opposite
obligations across three templates a controller fills in the same session is a
collision worth spending a word on.

Everything the template's `## Output Format` section currently describes —
Strengths, the three severity buckets, Recommendations, Assessment — goes to
that file unchanged. This is a change of destination, not of rubric. The one
addition is a label on plan-fault findings, so the plan-fault count in the
return is checkable against the file it summarises; the template's Calibration
section already asks for those findings, and `task-reviewer-prompt.md` already
labels its equivalent ("plan-mandated"). A label is not the severity vocabulary
the charter freezes.

### The bounded return (R3)

Fifteen lines, the same cap `implementer-prompt.md` sets, so the skill states
one number rather than two. The message carries exactly three things:

- the verdict — `Ready to merge? Yes | No | With fixes`;
- the counts — `Critical N, Important N, Minor N`, and how many findings put the
  fault in the plan rather than in the code following it;
- where the review file is.

A reviewer that could not write the file returns that instead of a verdict. A
shape with no failure value forces a reviewer with nothing to report into
reporting something.

No per-finding lines of any kind. The controller's next action is one of three —
dispatch a fix subagent, ask the human which of a finding and the plan holds, or
proceed — and the party that needs a finding's detail is the fix subagent, which
is handed the path. An enumeration would also be the one unbounded item in a
capped message, putting the cap and the shape in conflict on exactly the
branches with the most to report.

The plan-fault count is the one number that is not a summary of severity.
`SKILL.md` singles that case out ("Where a finding and the plan disagree,
neither one wins by default and neither is yours to overrule: put both in front
of the human and ask which holds"), and it is the one outcome whose next action
is a question to a human rather than a fix dispatch — invisible in a merge
verdict and a severity count. A controller seeing a non-zero count opens the
file, which it has to do anyway to put the finding and the plan side by side.

### The template's trailing blocks

`code-reviewer.md` ends with three blocks that describe the dispatch from
outside it, and all three go stale under R1–R3 unless the same change edits
them: the `**Placeholders:**` list gains `[DIFF_FILE]` and `[REVIEW_FILE]` and
keeps `[BASE_SHA]` / `[HEAD_SHA]`, which the rebuild clause still needs;
`**What comes back:**` is rewritten to the bounded return; and `## Example
Output` is labelled as what lands in the review file, since after this change it
is no longer an example of what comes back. A template whose footer contradicts
its body is worse than one that never had a footer.

### The controller side (R4)

Six edits in `skills/forge/SKILL.md`:

1. The final-review dispatch instruction (currently "After the last task,
   dispatch the whole-branch review with `code-reviewer.md`, on the most capable
   model") gains the package-generation step and the two paths, and names the
   branch base explicitly — the endpoint noted before the *first* task, not the
   per-task base, which is the mistake the per-task loop's own step 5 warns
   about in the other direction.
2. The same step adds the file checks. **Before dispatching:** the package is
   non-empty, because `review-package` reports success and exits 0 when its
   destination write fails (issue #36) and the template's rebuild clause then
   falls back to an inline `git diff` — silently restoring exactly what this
   change removes. Also before dispatching, the controller removes any file
   already at the review-file path. **After:** that path exists and is non-empty.
   Cleared-before plus present-after is what makes the review this run's rather
   than a leftover from a resumed session at the same range; existence alone
   cannot tell the two apart, and leaving a legitimately occupied path
   undefined would be worse than either. On the after-check failing, the
   controller discards the return and re-dispatches once, then stops and reports
   rather than dispatching again. That blind retry is for the *silent* failure;
   a reviewer that returned the write-failure value has already named the
   problem, so the controller changes something — a different path, or it stops
   and reports — rather than re-running an identical dispatch. `SKILL.md` already
   applies the same discipline to implementer reports ("Confirm the report has
   all three before re-dispatching the reviewer").
3. The final-fix instruction (currently "send **one** fix subagent with the
   complete list") hands over the review-file path instead of a list, and says
   what in that file binds the subagent: Critical and Important findings are to
   be fixed, Minor findings and Recommendations are not — Recommendations are
   the template's own "not defects, and not obligations" — and a finding
   labelled as a plan fault is returned to the controller rather than fixed.
   The list the controller used to hand over carried that filtering implicitly,
   because the controller had read the review and chose what to send. A path
   carries none of it, and `SKILL.md` reserves the plan-versus-finding call for
   the human ("put both in front of the human and ask which holds").
4. "Every reviewer dispatch ends with the same report contract, so you get a
   bounded verdict rather than the whole review" narrows to what will be true:
   the whole-branch reviewer returns a bounded verdict and a path, while the task
   reviewer's message is still its report. The sentence is already overstated
   today; this change makes the overstatement load-bearing, since it is the rule
   the whole-branch template is being brought under. Merging the two return
   shapes belongs to issue #45.
5. The `### Never` bullet "Dispatch a task reviewer without a review-package
   file" widens to any reviewer, since after this change both reviewer
   dispatches require one.
6. The `### Durable progress` section adds the branch base to what the ledger
   records, written before the first task is dispatched. The final review's
   package is keyed to that base, and nothing currently writes it down: the
   per-task loop notes a base per task, and the ledger's completion lines carry
   per-task ranges. Recovering it from Task 1's line is inference, and the whole
   point of that section is that a controller which lost its conversation memory
   reads the ledger instead of remembering. A base recovered wrongly produces a
   package that looks plausible and shows the reviewer the wrong branch.

### Testing (R5)

Nothing here is testable by an automated assertion, and by anatomy rule 4
nothing in this repository may assert on prose. The verification is `just verify`
— which covers link resolution (`check-skill-shape.sh` rule 5), the public-safety
scan, and the record gate — plus a read of the changed templates against the
task reviewer's equivalent sections, since "the same mechanics as the task
reviewer" is a claim only a reader can settle.

## Consequences

Recorded in [ADR 0007](../../adr/0007-whole-branch-review-package-and-report.md),
which owns them — the reviewer's input growing under `-U10`, the review reaching
the controller by assertion, the Minor triage discarded unread on a `Yes`
verdict, the review file's destruction with the worktree, and the two templates
still returning different shapes.

## Not an AI-surface change requiring an eval plan

These files are dispatch prompt templates, which is an AI surface, and the
design changes one. There is no eval plan here, and that is deliberate: the
change alters where the model's output is *written*, not what it is asked to
judge or how it is graded. The rubric, severity vocabulary, and calibration
guidance are all explicitly out of scope and unchanged, so the failure modes an
eval plan would score — grading accuracy, citation quality, verdict
correctness — have no new exposure. The one new observable behavior, the
fifteen-line cap, is checked the way the identical cap in
`implementer-prompt.md` is checked: by reading the return.

## Not a security-relevant change

No trust boundary moves. Nothing here parses untrusted input, handles a secret,
builds a command from a non-literal, changes a dependency, or widens a
permission. The one adjacent property is that the review package and review file
land in the gitignored `.agent/` workspace rather than in a commit, which
narrows what reaches a PR diff rather than widening it.
