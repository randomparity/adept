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

The whole-branch reviewer is handed a diff package and a review-file path, both
produced by the controller. The full review goes to that file with its rubric,
severity vocabulary, and section structure unchanged, and plan-fault findings are
labelled there.

The return is bounded and carries three things: the merge verdict; the counts, by
grade and of findings that put the fault in the plan rather than the code; and
the review-file path. No per-finding lines of any kind.

It has two failure values instead of a verdict, one for each end of the
arrangement: the reviewer could not write its file, or the package it was handed
was not there. A shape with no failure value forces a party with nothing to
report into reporting something, and the two ends need it symmetrically. The
inherited "rebuild the diff yourself if the package is missing" clause is
**removed** rather than kept and disclosed: it is a standing hatch back to the
unbounded inline diff, on the input side, of exactly the kind this record rejects
on the output side. A reviewer with no package has nothing to review and says so.

The plan-fault count is why the return is a fixed shape rather than a line budget
the reviewer fills as it sees fit. What it buys is narrow and worth naming: on a
`No` or `With fixes` verdict the controller opens the file anyway, so the count
tells it nothing it will not shortly read. The case it exists for is a `Yes`
carrying a plan fault — a branch that merges cleanly while the reviewer thinks
the plan, not the code, was wrong. Without the count that verdict is
indistinguishable from an ordinary clean one and the finding is never seen.

The controller hands the review-file path to the fix subagent rather than a
findings list it read first, and tells that subagent to return a labelled
plan-fault finding rather than fix it — `SKILL.md` reserves that call for the
human, and after this change the fix subagent is the only party reading the
findings.

The controller verifies the two artifacts rather than trusting them: the package
before the dispatch, the review file after it. A review that arrives as a path
and a count is one the controller has not seen, and `review-package` is known to
exit 0 on a failed write (issue #36).

The mechanics — the exact invocation, the workspace directory, the placeholder
name, the cap's value, the check sequence, and the retry rule — live in
`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`,
which can be corrected as they drift.

## Consequences

- The controller's post-review context is a verdict, two counts, and two paths.
  The findings reach the party that acts on them by path.
- **The reviewer's input grows.** The package's wide context is strictly more
  than a default `git diff`, on the most capable model in the pipeline. What
  this change buys is a bounded, non-accumulating controller context and a
  deterministic range — not fewer tokens overall. Nothing bounds the package
  either: on a large branch the reviewer may read part of it and report on what
  it read, and no check here can tell that apart from a complete reading. The
  controller sees the byte count `review-package` prints, and this decision does
  not give it a threshold to act on — a number nobody could defend would be
  worse than none.
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
- The return's counts use the templates' own `Critical / Important / Minor`
  grades, which ADR 0003 fixes and `$gauntlet` converts at the boundary. A count
  carried outward — into `$trial-loop` or a `WORK:REVIEW` summary — still needs
  that conversion.
- A reviewer that ignores the cap is not detected by anything. Anatomy rule 4
  forbids a gate that asserts on prose, and the cap is prose in a template. The
  identical cap in `implementer-prompt.md` has the same property.

## Considered & rejected

**Cap the return but keep the inline `git diff`.** Rejected: it leaves the
reviewer resolving its own range and reading a narrow diff, where a hunk whose
end it cannot see costs a tree excursion. The package is the delivery mechanism
the task reviewer already uses; keeping a second one buys a divergence and
nothing else.

**Keep the review inline** — either wholesale, or by having the reviewer return
it and the controller write the file. Rejected in both variants: the review is
what stays resident in the controller's context and is re-read on every later
turn, and it stays resident whether or not the controller then saves it.

**Let the reviewer return whatever fits in the cap**, or conversely **enumerate
findings in it.** Rejected at both ends: a line budget with no shape loses the
plan-fault case; an enumeration is the only unbounded thing that could sit in a
capped message, and would put cap and shape in conflict on exactly the branches
with the most to report.

**Prove the review is this run's with a token** the controller mints and the
reviewer echoes, as `$trial-loop` does. Rejected as the more expensive of two
unequal options: the token is the stronger guarantee, but it costs a fourth
return item and a new reviewer obligation, where clearing the path before the
dispatch costs one controller-side step and leaves the reviewer's contract
alone. The residual is that a review is destroyed by a re-review of the same
range, which nothing in this design reads twice.

**Let a reviewer that cannot write the file return its review inline instead.**
Rejected: it saves one re-dispatch and opens a standing escape hatch from the
budget, on the exact path where a reviewer has the most to say.

**Keep the inherited package-missing rebuild clause and disclose when it fires**
— a line in the review file naming which diff the reviewer had, and a controller
check that reads it. Rejected on the same reasoning as the entry above, which it
mirrors: it is the input-side hatch, and denying one while keeping the other
would need an argument nobody has. Closing it also deletes the disclosure line,
the check that reads it, and the ledger note recording it — three mechanisms that
existed only to make the hatch visible. `task-reviewer-prompt.md` keeps its own
rebuild clause and this record does not touch it; a task review that falls back
re-derives one task's diff, where this one re-derives the whole branch.

**Persist the review where it outlives the worktree** — a PR comment, as
`WORK:REVIEW` does. Rejected on surface, not merit: `$forge` runs before a PR
exists, and issue #46's charter permits changes to `code-reviewer.md` and
`SKILL.md` only.

**Unify the two reviewer return shapes first**, so the branch reviewer is
budgeted as part of one contract rather than diverging from its sibling.
Rejected on surface, not merit: that is issue #45, and this charter reaches
neither `task-reviewer-prompt.md` nor the shared vocabulary it would settle.

**Do nothing.** Rejected, but it is the cheapest option and worth stating plainly
what it costs and does not: total tokens may well *rise* under this change, as
the Consequences above concede. What it removes is a full review resident in the
controller's context and re-read on every remaining turn of the build — an
invisible per-run cost, on the most expensive dispatch, in the phase where the
controller's remaining context decides whether the rest of the build survives.

## Provenance

Decided while designing the implementation of issue #46
(`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`).
Numbered 0007 rather than the next free number on `main`:
`origin/feat/release-stage-decision-50` already carries an unmerged `0005`, and
issue #66 records a second unmerged `0005` from issue #55's branch. The number
assumes those two resolve to 0005 and 0006 as they merge; if one never lands,
`docs/adr/` carries a gap until this record is renumbered down. Issue #72 owns
that reconciliation — it is nobody's by default, which is why it is written down
here rather than left as an inference.
