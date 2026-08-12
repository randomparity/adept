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
review. The final review uses the same call with the branch's own endpoints, and
the base is stated once so the two places that need it cannot drift: it is the
branch's fork point from `BASE_BRANCH` — `git merge-base HEAD <BASE_BRANCH>` —
not `HEAD` at the moment the build phase started. Those differ whenever anything
already landed on the branch before the first task, which in this pipeline is
the normal case: `$spellcraft` commits the spec, ADR, and plan there first. The
fork point is what makes this the whole-branch review its own Context and ADR
0007 describe, and it is the same base `$trial-loop` reviews against at `$quest`
step 6. `HEAD` is taken after the last task's fix cycle closed.

Base resolution is stated here and nowhere else, so it cannot acquire a
precedence order by accident. The controller **recomputes** the merge-base at
dispatch time from `BASE_BRANCH` — the value `$attunement` discovered, which
`SKILL.md` already treats as the source for the guardrail commands. If it has no
such value it asks. It does not default to `main`, which is a guess that
produces a plausible-looking package of the wrong range on every repo naming its
default branch something else, and it does not carry a base forward from earlier
in the run, because a rebase moves the fork point and leaves a recorded value
pointing at a commit no longer on the branch.

Recomputing is why this design records no base anywhere: a value derived on
demand from something `$attunement` already froze cannot go stale between the
first task and the last, which a written-down copy can.

What this buys is determinism and fewer round trips rather than fewer tokens:
the range is the controller's own known-good one instead of whatever the
reviewer types, the commits and per-file stat arrive with the hunks, and `-U10`
means a hunk's end is visible without opening the tree. `-U10` is strictly more
input than a default `git diff`; the saving is in what the reviewer does *not*
have to go and read.

`code-reviewer.md`'s `## Git Range to Review` section becomes
`## The change you are judging`, naming `[DIFF_FILE]`. What crosses over from
the task reviewer's equivalent section is the *delivery*, clause by clause, and
the distinction matters enough to spell out rather than say "the same rules":

- **Crosses:** open the package once; its wide context lines *are* the files as
  they now stand; the package **is** the diff, so do not re-derive it — the
  package-missing rebuild below is the only sanctioned exception, and it is
  disclosed.
- **Does not cross:** "it is the whole of what you are judging", "resist opening
  one on the side", and "Stay out of the rest of the codebase". These read as
  delivery rules and are scoping rules, which is precisely why importing the
  section wholesale would be a silent narrowing.

The first list's third clause is what makes R1 falsifiable. Removing the
*instruction* to run `git diff` is not the same as removing the *permission*:
without a clause saying the package is the diff, a reviewer that ran one anyway
would be breaking nothing.

This is the one review whose value is seeing what a task-scoped reviewer could
not: the plan it was built against, the call sites of a contract the branch
changed, the documentation that went stale. The section keeps the package as
where the change is delivered and says outright that this reviewer may read
beyond it for a named reason, recording the reason when it does.

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
`final-review-<base7>..<head7>.md` — so the two artifacts of one dispatch sit
beside each other under the same name, and a reader who has one can find the
other. It carries no non-overwriting guarantee: the controller clears the path
before dispatching, so a second review of an unchanged range replaces the first.

The slot is named `[REVIEW_FILE]` rather than `[REPORT_FILE]` because both
sibling templates already use the latter, and in `task-reviewer-prompt.md` it
means *the implementer's report you read*. One name carrying two opposite
obligations across three templates a controller fills in the same session is a
collision worth spending a word on.

Everything the template's `## Output Format` section currently describes —
Strengths, the three severity buckets, Recommendations, Assessment — goes to
that file unchanged, including the triage of the ledger's Minor findings that
`SKILL.md` already hands the final reviewer — that list is an *input* to the
dispatch and stays one; only its answer moves. This is a change of destination,
not of rubric.

Three things are added to the file, all of them disclosures the controller and
the fix subagent would otherwise have no way to see:

- **A first line naming the delivery used** — the package, or the `git diff`
  rebuild. The rebuild clause is a silent escape hatch back to the unbounded
  inline diff, and no before-check can close it, because it fires inside the
  reviewer after the check has run. A line that says which one was used is what
  makes the fallback visible at all.
- **A label on plan-fault findings**, the literal string **`plan-mandated`**,
  reused from `task-reviewer-prompt.md`, which already labels its equivalent
  case that way. The count in the return and the fix subagent's instruction both
  key on that exact string, so the three cannot drift apart. A label is not the
  severity vocabulary the charter freezes.
- **The reason for any read beyond the package**, recorded where it is taken.
  The section that permits the excursion is the one that has to ask for its
  reason, or the permission is unbounded.

### The bounded return (R3)

Fifteen lines, the same cap `implementer-prompt.md` sets, so the skill states
one number rather than two. The message carries exactly three things:

- the verdict — `Ready to merge? Yes | No | With fixes`;
- the counts — `Critical N, Important N, Minor N, plan-mandated N`;
- where the review file is.

`plan-mandated N` is a **subset** of the graded counts, not a fourth grade: a
plan-fault finding is graded like any other and carries the label as well, the
way `task-reviewer-prompt.md` grades its equivalent Important *and* labels it.
So the three grades still sum to the finding total, and a return reading
`Important 2, plan-mandated 2` describes two findings, not four.

A reviewer that could not write the file returns the literal first line
**`WRITE_FAILED`** and the reason, instead of a verdict — a status token rather
than a fourth verdict value, so it cannot be confused with a merge judgment. A
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

Five edits in `skills/forge/SKILL.md`:

1. The final-review dispatch instruction (currently "After the last task,
   dispatch the whole-branch review with `code-reviewer.md`, on the most capable
   model") gains the package-generation step and the two paths, and names the
   branch base as the fork point defined under R1 — not the per-task base, which
   is the mistake the per-task loop's own step 5 warns about in the other
   direction.
2. The same step adds the file checks. **Before dispatching:** the package is
   real, judged on what `review-package` prints — a non-zero commit count and a
   non-zero byte count — because it reports success and exits 0 when its
   destination write fails (issue #36), and the template's rebuild clause then
   falls back to an inline `git diff`, silently restoring exactly what this
   change removes. A failed before-check does not dispatch: the controller
   reports it, and does not fall back. Then it removes any file already at the
   review-file path. **After:** that path exists, is non-empty, and its first
   line names the delivery the reviewer used. The controller is already at the
   path to stat it, so reading one line costs one line of context and makes the
   `git diff` fallback visible on every verdict rather than only when something
   else happens to open the file — a disclosure nobody is directed to read is
   not a disclosure.
   Cleared-before plus present-after is what makes the review this run's rather
   than a leftover from a resumed session at the same range; existence alone
   cannot tell the two apart, and leaving a legitimately occupied path
   undefined would be worse than either. On the after-check failing, the
   controller discards the return and re-dispatches once, then stops and reports
   rather than dispatching again. That blind retry is for the *silent* failure.
   A reviewer that returned `WRITE_FAILED` has already named a reason, and the
   reason decides: where it names the path, the controller retries once at a
   second path inside the same `scripts/sdd-workspace` directory — and nowhere
   else, or the single-named-path containment the read-only rule rests on stops
   being true on the retry. Where it names the directory or the permission, a
   different path cannot help, so the controller stops on the first failure and
   names the workspace as the blocker.

   A stop here means the branch reaches the rest of the pipeline with no
   whole-branch review, and the controller says exactly that rather than closing
   the phase quietly. `SKILL.md` already
   applies the same discipline to implementer reports ("Confirm the report has
   all three before re-dispatching the reviewer").
3. The final-fix instruction (currently "send **one** fix subagent with the
   complete list") hands over the review-file path instead of a list, and says
   what in that file binds the subagent: Critical and Important findings are to
   be fixed, Minor findings and Recommendations are not — Recommendations are
   the template's own "not defects, and not obligations" — and a finding
   labelled `plan-mandated` is returned to the controller rather than fixed.
   The list the controller used to hand over carried that filtering implicitly,
   because the controller had read the review and chose what to send. A path
   carries none of it, and `SKILL.md` reserves the plan-versus-finding call for
   the human ("put both in front of the human and ask which holds").

   The same item states when the dispatch fires and in what order, because the
   verdict and the counts can disagree and because the two triggers overlap by
   construction — `plan-mandated` findings are a subset of the graded ones:

   - a non-zero `plan-mandated` count goes to the human **first**, and the fix
     wave waits on the answer, because a fix dispatched before it would be the
     controller overruling a call `SKILL.md` reserves for the human;
   - that answer **partitions** the labelled findings: the ones the human
     upholds join the fix wave, the ones the human overrules are dropped and
     recorded as overruled. Waiting is what makes the answer usable — a wave
     that ignored it would leave an upheld Critical unassigned to anybody;
   - one fix subagent then goes out against the unlabelled findings plus the
     upheld labelled ones, graded Critical or Important, whatever the merge
     verdict says — and only if that set is non-empty, since a dispatch with
     nothing in it still costs a full context build;
   - a `No` or `With fixes` carrying no graded findings is a return the
     controller opens the file for rather than acting on, since the two halves
     of it cannot both be right.

   What happens after the fix subagent reports is `SKILL.md`'s existing business
   and this change does not touch it. An earlier draft mandated a re-review here
   in order to justify the range-keyed filename under R2 — reasoning backwards
   from a naming choice to a new full dispatch nothing in the charter asks for.
   The filename stands on the reason given there instead.
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
There is deliberately no seventh edit adding the branch base to the progress
ledger. An earlier draft had one, on the reasoning that a controller which lost
its conversation memory must read the base rather than remember it — sound, but
answered better by recomputing it, which is what R1 now specifies. A recorded
base is a copy that can go stale; a recomputed one cannot, and it needs no
recovery rule for a ledger written before this change.

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
design changes one. There is no eval plan here, and that is deliberate — but the
reason is not that the change adds no model behavior. It adds six:

| New behavior | How it is checked |
|---|---|
| writing the review file at the supplied path | the controller's cleared-before / present-and-non-empty check |
| naming the delivery used on the file's first line | the controller reads that line as part of the after-check |
| returning `WRITE_FAILED` and a reason instead of a verdict | by reading the return |
| labelling plan-fault findings `plan-mandated` | not checked |
| counting graded and `plan-mandated` findings in the return | not checked against the file |
| recording the reason for a read beyond the package | not checked |
| holding the return under the cap | not checked — the cap is prose in a template, as in `implementer-prompt.md` |

The rubric, the severity vocabulary, and the calibration guidance are out of
scope and untouched, so what an eval plan scores most directly — grading
accuracy, citation quality, verdict correctness — is not being altered by
design. That is not the same as no exposure, and claiming so would be false: the
reviewer's *evidence base* does change, from a diff it derives itself to a
package it is handed, and this design does not measure what that does to the
findings. Four of the seven rows are unchecked, all of them the reviewer's
self-report about its own work, which ADR 0007 records as the weakest link
rather than claiming a check covers it. An eval harness for a prompt template's
self-report would be a larger apparatus than the thing it grades, and outside
this issue's charter.

## Not a security-relevant change

No trust boundary moves. Nothing here parses untrusted input, handles a secret,
builds a command from a non-literal, or changes a dependency.

One permission does widen, and it is worth naming rather than waving away: a
subagent that was previously read-only on the checkout gains a write. It is
contained by being a single named path — the supplied `[REVIEW_FILE]`, not the
workspace around it, which is why the read-only rule is amended to that one path
and not to the directory holding the controller's ledger. The actor is a
subagent this session dispatched, not an untrusted party, and both the package
and the review file land in the gitignored `.agent/` workspace rather than in a
commit, which narrows what reaches a PR diff rather than widening it.
