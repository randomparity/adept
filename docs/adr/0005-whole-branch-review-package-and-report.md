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
`scripts/sdd-workspace` directory, both keyed to the abbreviated commit range, so
the review file is named the way the package beside it already is. The slot is
`[REVIEW_FILE]` rather than the siblings' `[REPORT_FILE]`, which in
`task-reviewer-prompt.md` means *the implementer's report you read* — one name
for two opposite obligations across three templates a controller fills in the
same session. The full review goes to `[REVIEW_FILE]` with its rubric, severity
vocabulary, and section structure unchanged, and plan-fault findings are labelled
there so the count below is checkable against the file it summarises.

Writing `[REVIEW_FILE]` is the single write the template's `## Read-Only Review`
rule exempts, and the template says so: that exact supplied path, and nothing
else in the checkout — tracked or ignored, the controller's own ledger included.
Left unreconciled, the template would carry an instruction to write and a rule
forbidding it.

The return message is capped at fifteen lines — the same number
`implementer-prompt.md` uses, so the skill states one cap rather than two — and
carries exactly three things: the merge verdict; the counts, by grade and of
findings that put the fault in the plan rather than the code; and the
review-file path. No per-finding lines of any kind: the party that acts on a
finding is the fix subagent, which is handed the path. A reviewer that could not
write the file returns that instead of a verdict, since a shape with no failure
value forces a reviewer with nothing to report into reporting something.

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
file means the return is discarded and the reviewer re-dispatched **once**;
a second failure stops and is reported, rather than dispatching again.

## Consequences

- The controller's post-review context is a verdict, two counts, and two paths.
  The findings reach the party that acts on them — the fix subagent — by path.
- **The review now reaches the controller by assertion.** A reviewer that
  returns `Critical 2` and writes nothing is indistinguishable, from the
  controller's side, from one that wrote a full report; an inline review could
  not fail that way. The existence check discharges this, and it is a check, not
  a proof: a truncated or shallow report still passes it. The plan-fault count is
  the weakest link — it is the reviewer's own classification, and no controller
  check covers whether it matches the labelled findings in the file.
- On a `Yes` verdict nobody reads the review file, so `SKILL.md`'s Minor-triage
  obligation produces an answer nobody sees: the ledger's Minor findings and the
  reviewer's triage of them are discarded unread. Accepted rather than
  explained away — the alternative is a fourth return item, which is the shape
  growth this decision spent its argument bounding, for findings that by
  definition do not hold a merge.
- The final review is destroyed with the worktree, where an inline review
  persisted in the session transcript. Its readers during the run — the fix
  subagent, and a human who opens it — can reach it while the worktree exists.
- `code-reviewer.md` and `task-reviewer-prompt.md` converge on the same package
  section and read-only rule, but their **return shapes now differ**: the branch
  reviewer writes a file and returns a verdict, while the task reviewer's message
  still is its review. That leaves two near-duplicate templates kept in sync by
  reading rather than by any mechanism; merging them would mean editing
  `task-reviewer-prompt.md`, which issue #46 excludes.
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

**Keep the review inline** — either wholesale, or by having the reviewer return
it and the controller write the file. Rejected in both variants: the review is
the part that stays resident in the controller's context and is re-read on every
later turn of the build, and it stays resident whether or not the controller then
saves it. Report-file indirection only works when the subagent does the writing.

**Let the reviewer return whatever fits in fifteen lines**, or conversely
**enumerate findings in it** — one line per Critical, or per plan fault.
Rejected at both ends: a line budget with no shape loses the plan-fault case,
which reads like an ordinary finding and is the one outcome the controller must
not answer with a fix dispatch; an enumeration is the only unbounded thing that
could sit in a capped message, and would put cap and shape in conflict on exactly
the branches with the most to report. Naming three items costs nothing and makes
an omission visible.

**Persist the review where it outlives the worktree** — a PR comment, the way
`WORK:REVIEW` already carries a review summary. Rejected on surface, not on
merit: `$forge` runs before a PR exists, and issue #46's charter permits changes
to `code-reviewer.md` and `SKILL.md` only. It is the right question for a later
issue.

**Do nothing.** Rejected, but it is the cheapest option and worth stating why it
loses: the cost is invisible per-run — the build still works, and nothing goes
red — so it is paid on every party-mode run forever, on the most expensive
dispatch, in the phase where the controller's remaining context decides whether
the rest of the build survives.

## Provenance

Decided while designing the implementation of issue #46
(`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`).
