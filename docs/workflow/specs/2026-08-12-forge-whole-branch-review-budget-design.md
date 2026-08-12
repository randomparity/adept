# Forge's whole-branch review gets a token budget

Design for issue [#46](https://github.com/randomparity/adept/issues/46).
Decision record: [ADR 0005](../../adr/0005-whole-branch-review-package-and-report.md).

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

Two costs follow. The reviewer's own context absorbs an unbounded
`git diff BASE..HEAD` with no wide context around the hunks, so a hunk whose end
it cannot see sends it into the tree. And the controller's context absorbs the
entire review — Strengths, three severity buckets, Recommendations, Assessment —
which then stays resident and is re-read on every later turn of the build.

## Requirements

- **R1** — The whole-branch reviewer is handed a review-package path produced by
  `skills/forge/scripts/review-package BASE HEAD`, rather than running
  `git diff --stat` and `git diff` itself.
- **R2** — The whole-branch reviewer writes its detailed review to a report file
  at a path the controller supplies.
- **R3** — The reviewer's inline return message carries a hard cap, the way
  `implementer-prompt.md` caps its return.
- **R4** — `SKILL.md`'s final-review dispatch step tells the controller to
  generate the package and supply both paths, and its final-fix dispatch step
  hands the fix subagent the report path rather than a findings list the
  controller had to read.
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

`code-reviewer.md`'s `## Git Range to Review` section becomes
`## The change you are judging`, naming `[DIFF_FILE]` and carrying the same
three rules the task reviewer's equivalent section carries: open the package
once, treat its wide context lines as the files as they now stand, and rebuild
with `git diff --stat` / `git diff` only if the package is missing.

The `## Read-Only Review` section stays. It is a safety rule about the checkout,
not about diff delivery, and the worktree escape hatch is the sanctioned way to
lay another revision out on disk.

### The report file (R2)

The controller supplies `[REPORT_FILE]`. Its path lives in the `$forge`
workspace that `scripts/sdd-workspace` resolves — the same directory the briefs,
implementer reports, and review packages already occupy, and the only place a
write is covered by the self-ignoring `.gitignore` that keeps this phase's
artifacts out of `git status` and out of the PR diff.

The path is keyed to the same abbreviated range as the package —
`final-review-<base7>..<head7>.md` — so a re-review after a fix wave writes
alongside its predecessor instead of over it, matching what `review-package`
already does for the same reason.

Everything the template's `## Output Format` section currently describes —
Strengths, the three severity buckets, Recommendations, Assessment — goes to
that file unchanged. This is a change of destination, not of rubric.

### The bounded return (R3)

Fifteen lines, the same cap `implementer-prompt.md` sets, so the skill states
one number rather than two. The message carries:

- the verdict — `Ready to merge? Yes | No | With fixes`;
- the counts, by grade: `Critical N, Important N, Minor N`;
- one line per Critical finding — its `file:line` and what is broken — and
  nothing at all when there are none;
- one line for any place the fault lies in the plan rather than in the code
  following it, because that is the finding the controller cannot act on by
  dispatching a fix;
- where the report file is.

Where the Critical lines alone would breach fifteen, the reviewer gives the two
most severe, the count of the rest, and says it truncated — a silent truncation
would read as a shorter list of Criticals than the branch has.

The plan-fault line is the one item that is not merely a summary of the report.
`SKILL.md` already singles that case out ("Where a finding and the plan
disagree, neither one wins by default and neither is yours to overrule: put both
in front of the human and ask which holds"), and it is the one outcome whose
next action is a question to a human rather than a fix dispatch. Leaving it only
in the report would mean the controller could not tell a fix-and-continue from a
stop-and-ask without opening the file.

### The controller side (R4)

Three edits in `skills/forge/SKILL.md`:

1. The final-review dispatch instruction (currently "After the last task,
   dispatch the whole-branch review with `code-reviewer.md`, on the most capable
   model") gains the package-generation step and the two paths, and names the
   branch base explicitly — the endpoint noted before the *first* task, not the
   per-task base, which is the mistake the per-task loop's own step 5 warns
   about in the other direction.
2. The final-fix instruction (currently "send **one** fix subagent with the
   complete list") hands over the report path instead of a list. A list the
   controller has to hold is exactly the resident cost this change removes.
3. The `### Never` bullet "Dispatch a task reviewer without a review-package
   file" widens to any reviewer, since after this change both reviewer
   dispatches require one.

### Testing (R5)

Nothing here is testable by an automated assertion, and by anatomy rule 4
nothing in this repository may assert on prose. The verification is `just verify`
— which covers link resolution (`check-skill-shape.sh` rule 5), the public-safety
scan, and the record gate — plus a read of the changed templates against the
task reviewer's equivalent sections, since "the same mechanics as the task
reviewer" is a claim only a reader can settle.

## Consequences

- The controller's context after the final review holds a verdict, counts, and
  two paths instead of a full review. The findings are not lost; they are one
  file read away, and the party that needs them in full is the fix subagent,
  which reads the file directly.
- A human who wants to read the final review reads it out of the workspace
  rather than out of the transcript. That directory is gitignored and local, so
  the review does not survive the worktree — acceptable, because it never
  survived a compaction either.
- `code-reviewer.md` and `task-reviewer-prompt.md` end up structurally parallel:
  same package section, same read-only rule, same report-and-cap contract. That
  parallel is what makes the remaining difference — task scope versus branch
  scope — the only thing a reader has to hold.

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
permission. The one adjacent property is that the review package and report file
land in the gitignored `.agent/` workspace rather than in a commit, which
narrows what reaches a PR diff rather than widening it.
