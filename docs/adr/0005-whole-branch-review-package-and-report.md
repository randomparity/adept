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
`scripts/review-package BASE HEAD` and a `[REVIEW_FILE]` under the
`scripts/sdd-workspace` directory, both keyed to the abbreviated commit range so
a re-review after a fix wave writes new files rather than over the ones it
should be compared against. The full review goes to `[REVIEW_FILE]` with its
rubric, severity vocabulary, and section structure unchanged.

The slot is `[REVIEW_FILE]`, not `[REPORT_FILE]`. Both sibling templates already
use `[REPORT_FILE]`, and in `task-reviewer-prompt.md` it means *the implementer's
report you read*. A controller filling all three templates would otherwise meet
one placeholder name carrying two opposite obligations.

That write is the one exemption to the template's `## Read-Only Review` rule, and
the template says so. The rule's scope is the tracked checkout — working tree,
index, HEAD, branches — and the gitignored `.agent/` workspace is outside it.
Left unreconciled, the template would carry an instruction to write and a rule
forbidding it, and which one a reviewer honours is not something this decision
should leave to chance.

The return message is capped at fifteen lines — the same number
`implementer-prompt.md` uses, so the skill states one cap rather than two — and
carries exactly three things: the merge verdict; the counts, by grade and of
findings that put the fault in the plan rather than the code; and the
review-file path. No per-finding lines of any kind: the party that acts on a
finding is the fix subagent, which is handed the path.

The plan-fault count is the reason the return is a fixed shape rather than a
line budget the reviewer fills as it sees fit. It is the only one of the
controller's three next actions whose trigger is invisible in a merge verdict
and a severity count, and the only one whose answer is a question to a human
rather than a dispatch. A count rather than a line keeps the shape bounded; the
controller that sees a non-zero one opens the file, which it must do anyway to
put both the finding and the plan in front of the human.

The controller hands the review-file path to the fix subagent rather than a
findings list it had to read first — and confirms the file exists and is
non-empty before acting on the return at all, because a review that arrives as a
path plus a count is a review the controller has not seen. A missing or empty
file means the return is discarded and the reviewer re-dispatched; the counts are
never acted on without the file behind them.

## Consequences

- The controller's post-review context is a verdict, two counts, and two paths.
  The findings reach the party that acts on them — the fix subagent — by path.
- **The review now reaches the controller by assertion.** A reviewer that
  returns `Critical 2` and writes nothing is indistinguishable, from the
  controller's side, from one that wrote a full report; an inline review could
  not fail that way. The existence-and-non-empty check in the Decision is what
  discharges this, and it is a check, not a proof: a truncated or shallow report
  still passes it.
- On a clean merge verdict the review file has no reader. That is also where
  `SKILL.md`'s Minor-triage obligation lands — the final reviewer triages the
  ledger's accumulated Minor findings against the merge bar, and on a `Yes` its
  triage said none of them hold, so those ledger entries close on the verdict
  alone. Accepted: a triage whose answer is "no action" needs no reader.
- The final review is no longer readable from the transcript, and the loss is
  larger than a straight move. An inline review persisted in the session
  transcript; the review file is destroyed with the worktree, since the `$forge`
  workspace is gitignored and local. Accepted on the grounds that the final
  review's readers are the fix subagent and, if anyone, a human during the run —
  both of whom can reach the file while the worktree exists — and that nobody
  reads a final review after the branch merges.
- `code-reviewer.md` and `task-reviewer-prompt.md` converge on the same package
  section and keep the same read-only rule, but their **return shapes now
  differ**: the branch reviewer writes a file and returns a verdict, while the
  task reviewer's message still is its review. That is deliberate — the task
  review is already bounded by its scope — and it leaves two near-duplicate
  templates that are kept in sync by reading rather than by any mechanism.
  Merging them would mean editing `task-reviewer-prompt.md`, which issue #46
  excludes.
- A reviewer that ignores the cap is not detected by anything. Anatomy rule 4
  forbids a gate that asserts on prose, and the cap is prose in a template. The
  identical cap in `implementer-prompt.md` has the same property.

## Considered & rejected

**Cap the return but keep the inline `git diff`.** Rejected: it leaves the
reviewer resolving its own range and reading a `-U3` diff, where a hunk whose end
it cannot see costs a tree excursion. The package is not a token saving on the
reviewer's side — `-U10` is strictly more input than `git diff`'s default — it
trades input tokens for determinism and fewer round trips: the controller's own
known-good range rather than whatever the reviewer types, commits and per-file
stat alongside the hunks, and a stated rebuild path when the package is missing.
It is also the delivery mechanism the task reviewer already uses, so keeping a
second one buys a divergence and nothing else.

**Package the diff but keep the review inline.** Rejected: the review is the part
that stays resident in the controller's context and is re-read on every later
turn of the build. The reviewer's cost is paid once; the controller's is paid
repeatedly.

**Let the reviewer return whatever fits in fifteen lines.** Rejected: a line
budget with no shape loses the plan-fault case, which reads like an ordinary
finding and is the one outcome the controller must not answer with a fix
dispatch. Naming the three items costs nothing and makes the omission visible.

**Enumerate findings in the return — one line per Critical, or per plan fault.**
Rejected: no controller decision needs the detail, since the fix dispatch reads
the file, and an enumeration is the only unbounded thing that could sit in a
capped message — it would put the cap and the shape in conflict on exactly the
branches with the most to report.

**Have the reviewer return the full review and let the controller write it to a
file.** Rejected: the review passes through the controller's context on the way,
which is the entire cost being removed. The indirection only works when the
subagent does the writing.

**Do nothing.** Rejected, but it is the cheapest option and worth stating why it
loses: the cost is invisible per-run — the build still works, and nothing goes
red — so it is paid on every party-mode run forever, on the most expensive
dispatch, in the phase where the controller's remaining context decides whether
the rest of the build survives.

**Give the review file a fixed name.** Rejected: `review-package` already keys
its default destination to the range, and for the stated reason — a re-review
after a fix wave must not overwrite the reading it is meant to be compared
against. A second artifact of the same review, keyed differently, would lose that
on the half that holds the findings.

## Provenance

Decided while designing the implementation of issue #46
(`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`).
