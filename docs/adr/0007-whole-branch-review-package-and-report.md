# 0007 — The whole-branch review returns a verdict, not a review

## Status

Accepted (2026-08-12)

## Context

`$forge`'s party mode dispatches three kinds of subagent. The implementer writes
its detail to a report file and returns fifteen lines. The task reviewer reads a
diff package built by `scripts/review-package` and returns a message where every
line is a verdict, a cited finding, or a check it performed. The whole-branch
reviewer — the last dispatch, on the most capable model, over the entire branch
— runs `git diff BASE..HEAD` itself and returns the complete review inline:
Strengths, three severity buckets, Recommendations, and Assessment.

`SKILL.md` already states the rule the third dispatch breaks — "Hand artifacts
over as **files**, not pasted text". Issue #46 asks for the template to be
brought under it.

The question this record settles is not whether to bound it, but *what the
controller still needs inline* once the review lives in a file. The controller's
next action is one of three: dispatch a single fix subagent, ask the human which
of a finding and the plan holds, or proceed. It has to pick one without reading
the review.

## Decision

The whole-branch reviewer is handed a diff package built by
`scripts/review-package BASE HEAD` and a review-file path under the
`scripts/sdd-workspace` directory, both keyed to the abbreviated commit range so
the review file is named the way the package beside it already is. The review
file's placeholder gets a name of its own rather than the siblings'
`[REPORT_FILE]`, which in `task-reviewer-prompt.md` means the implementer's
report the reviewer *reads*. Writing that one supplied path is the single write
the template's read-only rule exempts — not the workspace around it, which holds
the controller's own ledger.

The full review goes to the file with its rubric, severity vocabulary, and
section structure unchanged, and plan-fault findings are labelled there.

The return message is capped at fifteen lines — the number
`implementer-prompt.md` already uses — and carries three things: the merge
verdict; the counts, by grade and of findings that put the fault in the plan
rather than the code; and the review-file path. No per-finding lines of any
kind. A reviewer that could not write the file returns that instead of a
verdict; a shape with no failure value forces a reviewer with nothing to report
into reporting something.

The plan-fault count is why the return is a fixed shape rather than a line
budget the reviewer fills as it sees fit. It is the only one of the controller's
three next actions whose trigger is invisible in a merge verdict and a severity
count, and the only one answered by a question to a human rather than a
dispatch. A count keeps the shape bounded; a controller seeing a non-zero one
opens the file, which it must do anyway to put the finding and the plan side by
side.

The controller hands the review-file path to the fix subagent rather than a
findings list it read first, and tells that subagent to return a labelled
plan-fault finding rather than fix it — `SKILL.md` reserves that call for the
human, and after this change the fix subagent is the only party reading the
findings. It also verifies the two files rather than trusting them: the package
is non-empty before the dispatch, the review-file path is absent before it and
present and non-empty after. Absence-before plus presence-after is what makes
the review this run's rather than a leftover; a review that arrives as a path and
a count is one the controller has not seen. On failure it re-dispatches once,
then stops and reports.

The mechanics that implement this live in
`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`,
which can be corrected as they drift. This record holds only what was decided.

## Consequences

- The controller's post-review context is a verdict, two counts, and two paths.
  The findings reach the party that acts on them by path.
- **The reviewer's input grows.** `-U10` is strictly more than `git diff`'s
  default `-U3`, on the most capable model in the pipeline. What this change
  buys is a bounded, non-accumulating controller context and a deterministic
  range — not fewer tokens overall.
- **The review reaches the controller by assertion.** The file checks discharge
  the crude failures; they are checks, not proofs, and a truncated or shallow
  report passes them. The plan-fault count is the weakest link — the reviewer's
  own classification, which no controller check verifies against the file.
- On a `Yes` verdict nobody reads the review file, so `SKILL.md`'s Minor-triage
  obligation produces an answer nobody sees: the ledger's Minor findings and the
  reviewer's triage of them are discarded unread. Accepted rather than explained
  away — the alternative is a fourth return item, which is the shape growth this
  decision spent its argument bounding, for findings that by definition do not
  hold a merge.
- The final review is destroyed with the worktree, where an inline review
  persisted in the session transcript. Its readers during the run can reach it
  while the worktree exists.
- The two reviewer templates still return different shapes — the branch reviewer
  a verdict and a path, the task reviewer its whole review. `SKILL.md`'s claim
  that every reviewer dispatch returns a bounded verdict is narrowed to what is
  true rather than left overstated. Merging the shapes is issue #45's.
- A reviewer that ignores the cap is not detected by anything. Anatomy rule 4
  forbids a gate that asserts on prose, and the cap is prose in a template. The
  identical cap in `implementer-prompt.md` has the same property.

## Considered & rejected

**Cap the return but keep the inline `git diff`.** Rejected: it leaves the
reviewer resolving its own range and reading a `-U3` diff, where a hunk whose end
it cannot see costs a tree excursion. The package is the delivery mechanism the
task reviewer already uses; keeping a second one buys a divergence and nothing
else.

**Keep the review inline** — either wholesale, or by having the reviewer return
it and the controller write the file. Rejected in both variants: the review is
what stays resident in the controller's context and is re-read on every later
turn, and it stays resident whether or not the controller then saves it.

**Let the reviewer return whatever fits in fifteen lines**, or conversely
**enumerate findings in it.** Rejected at both ends: a line budget with no shape
loses the plan-fault case; an enumeration is the only unbounded thing that could
sit in a capped message, and would put cap and shape in conflict on exactly the
branches with the most to report.

**Prove freshness with a run token** the controller mints and the reviewer echoes,
as `$trial-loop` does. Rejected as the more expensive of two equivalents:
absence-before plus presence-after gives the same guarantee entirely on the
controller's side, without a fourth return item or a new reviewer obligation.

**Let a reviewer that cannot write the file return its review inline instead.**
Rejected: it saves one re-dispatch and opens a standing escape hatch from the
budget, on the exact path where a reviewer has the most to say.

**Persist the review where it outlives the worktree** — a PR comment, as
`WORK:REVIEW` does. Rejected on surface, not merit: `$forge` runs before a PR
exists, and issue #46's charter permits changes to `code-reviewer.md` and
`SKILL.md` only.

**Do nothing.** Rejected, but it is the cheapest option and worth stating why it
loses: the cost is invisible per run — the build still works, nothing goes red —
so it is paid on every party-mode run forever, on the most expensive dispatch, in
the phase where the controller's remaining context decides whether the rest of
the build survives.

## Provenance

Decided while designing the implementation of issue #46
(`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`).
Numbered 0007 rather than the next free number on `main`: `origin/feat/release-stage-decision-50`
already carries an unmerged `0005`, and issue #66 records a second unmerged `0005`
from issue #55's branch.
