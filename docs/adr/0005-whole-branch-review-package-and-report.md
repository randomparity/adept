# 0005 — The whole-branch review returns a verdict, not a review

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
over as **files**, not pasted text", and "Every reviewer dispatch ends with the
same report contract, so you get a bounded verdict rather than the whole review."
Issue #46 asks for the template to be brought under that rule.

The question this record settles is not whether to bound it, but *what the
controller still needs inline* once the review lives in a file. The controller's
next action after this review is one of three: dispatch a single fix subagent,
ask the human which of a finding and the plan holds, or proceed. It has to pick
one without reading the review.

## Decision

The whole-branch reviewer is handed a `[DIFF_FILE]` built by
`scripts/review-package BASE HEAD` and a `[REPORT_FILE]` under the
`scripts/sdd-workspace` directory, both keyed to the abbreviated commit range so
a re-review after a fix wave writes new files rather than over the ones it
should be compared against. The full review goes to the report file with its
rubric, severity vocabulary, and section structure unchanged.

The return message is capped at fifteen lines — the same number
`implementer-prompt.md` uses, so the skill states one cap rather than two — and
carries exactly five things: the merge verdict; the finding counts by grade; one
line per Critical finding, or none where there are none; one line for any place
the fault lies in the plan rather than the code; and the report path. Where the
Critical lines alone would breach the cap, the reviewer names the two most
severe, counts the rest, and says it truncated.

The controller hands the report path to the fix subagent rather than a findings
list it had to read first.

The plan-fault line is the reason the return is a fixed five-item shape rather
than a line budget the reviewer fills as it sees fit. It is the only outcome
whose next action is a question to a human, and it is not recoverable from a
verdict and a count.

## Consequences

- The controller's post-review context is a verdict, two counts, and two paths.
  The findings reach the party that acts on them — the fix subagent — by path.
- The final review is no longer readable from the transcript. It is in the
  gitignored workspace, which does not survive the worktree. This is a real
  loss, and a small one: an inline review did not survive a compaction either,
  and the report file survives one.
- `code-reviewer.md` and `task-reviewer-prompt.md` become structurally parallel,
  leaving task-scope-versus-branch-scope as the only difference a reader carries.
- A reviewer that ignores the cap is not detected by anything. Anatomy rule 4
  forbids a gate that asserts on prose, and the cap is prose in a template. The
  identical cap in `implementer-prompt.md` has the same property.

## Considered & rejected

**Cap the return but keep the inline `git diff`.** Rejected: it fixes the
controller's cost and leaves the reviewer's. An unbounded diff with no context
around the hunks is what sends the reviewer into the tree to see a hunk's end —
the specific waste the `-U10` package exists to remove, and the more expensive
half, since this dispatch runs on the most capable model.

**Package the diff but keep the review inline.** Rejected for the mirror reason:
the review is the part that stays resident in the controller's context and is
re-read on every later turn of the build. The reviewer's cost is paid once; the
controller's is paid repeatedly.

**Let the reviewer return whatever fits in fifteen lines.** Rejected: a line
budget with no shape loses the plan-fault case, which reads like an ordinary
finding and is the one outcome the controller must not answer with a fix
dispatch. Naming the five items costs nothing and makes the omission visible.

**Have the reviewer return the full review and let the controller write it to a
file.** Rejected: the review passes through the controller's context on the way,
which is the entire cost being removed. Report-file indirection only works when
the subagent writes it.

**Drop the whole-branch review; `$trial-loop` reviews the branch at `$quest`
step 6 anyway.** Rejected: it is not this issue's question, and the two are not
substitutes — the whole-branch review judges the branch against *the plan it was
built from*, which `$trial-loop` is never given. Removing a review to avoid
budgeting it also trades a bounded cost for an unbounded risk.

**Give the report file a fixed name.** Rejected: `review-package` already keys
its default destination to the range, and for the stated reason — a re-review
after a fix wave must not overwrite the reading it is meant to be compared
against. A second artifact of the same review, keyed differently, would lose
that on the half that holds the findings.

## Provenance

Decided while designing the implementation of issue #46
(`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`).
