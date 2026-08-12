# Implementation plan — forge's whole-branch review gets a token budget

**Goal.** Bring `$forge`'s whole-branch reviewer dispatch under the same
review-package and report-file discipline its two sibling dispatches already
use, so the review is delivered as a file and the reviewer returns a bounded
verdict instead of the whole review.

**Architecture.** Two Markdown files change and nothing else. `skills/forge/code-reviewer.md`
is a dispatch prompt template — text copied into a subagent prompt with its
placeholders filled — and it gains a diff-package input, a review-file output,
and a capped return. `skills/forge/SKILL.md` is the controller's own
instructions, and it gains the steps that produce those two paths, verify them,
and hand the review file on to the fix subagent. No script, no gate, no test
fixture, no new file.

**Tech stack.** Markdown only. The repository's guardrails are `just` recipes
driving `shellcheck`, `shfmt`, `rg`, `jq`, `actionlint`, `zizmor`, `prek`, and
the repo's own shell gates.

**Source documents.** Spec:
`docs/workflow/specs/2026-08-12-forge-whole-branch-review-budget-design.md`.
Decision record: `docs/adr/0007-whole-branch-review-package-and-report.md`.
Issue: <https://github.com/randomparity/adept/issues/46>.

## Global Constraints

These bind every task. They are transcribed from the spec and the charter; use
the exact values.

1. **Only two files may change:** `skills/forge/code-reviewer.md` and
   `skills/forge/SKILL.md`. Creating any file — a script, a fixture, a helper,
   a second template — violates the charter and `CLAUDE.md` anatomy rules 1 and 2.
2. **`scripts/review-package`, `task-reviewer-prompt.md`, and
   `implementer-prompt.md` are not modified.** They are the correct contrast
   state this change moves toward, and the charter excludes them.
3. **The severity vocabulary is frozen.** The template grades findings
   `Critical`, `Important`, `Minor` — those literal words, unchanged. ADR 0003
   and `skills/gauntlet/SKILL.md`'s severity mapping read them.
4. **Three literal strings are load-bearing** and must appear character for
   character wherever they are used:
   - `plan-mandated` — the label on a finding whose fault lies in the plan
     rather than the code. Reused from `task-reviewer-prompt.md`.
   - `WRITE_FAILED` — the return's first line when the reviewer could not write
     the review file.
   - `delivery: package` / `delivery: rebuilt diff` — the review file's first
     line, naming which diff the reviewer actually had.
5. **The return cap is fifteen lines**, the same number
   `implementer-prompt.md` already states.
6. **Placeholders in `code-reviewer.md`** after this change:
   `[DESCRIPTION]`, `[PLAN_OR_REQUIREMENTS]`, `[DIFF_FILE]`, `[REVIEW_FILE]`,
   `[BASE_SHA]`, `[HEAD_SHA]`, `[SHA]`. `[BASE_SHA]` and `[HEAD_SHA]` stay
   because the package-missing rebuild clause needs them.
7. **The base is the fork point.** Wherever `SKILL.md` names the whole-branch
   review's base, it is `git merge-base HEAD <BASE_BRANCH>`, recomputed at
   dispatch time, with `BASE_BRANCH` being the value `$attunement` recorded.
   Never `HEAD` at the start of the build phase, never a value carried forward,
   never a default of `main`.
8. **Line width:** wrap prose at 80 columns, matching both files as they stand.
9. **Guardrail command:** `just verify`. Run it before each commit. It must exit
   0. Do not pipe it, do not append `|| true` — its exit status is the verdict.
10. **Commits:** conventional commits, imperative mood, subject ≤ 72 characters,
    one logical change per commit. Never commit to `main`; this work is on
    `feat/forge-reviewer-token-budget-46`.
11. **Nothing in this repository may assert on prose** (anatomy rule 4). Do not
    add a gate, grep, or test that checks for any sentence introduced here.

## File map

| File | Action | Answerable for |
|---|---|---|
| `skills/forge/code-reviewer.md` | modify | the reviewer's own instructions: what it is handed, where its review goes, what it sends back |
| `skills/forge/SKILL.md` | modify | the controller's instructions: producing and verifying the two paths, and routing the findings afterwards |

## Task 1 — rewrite the whole-branch reviewer template

**Modifies:** `skills/forge/code-reviewer.md`
**Creates:** nothing
**Tests:** `just verify`

**Where this fits.** This is the reviewer's half of the change. Task 2 makes the
controller supply what this task now asks for. Do this one first: Task 2's
instructions refer to placeholders this task defines.

**Interfaces.**

- *Consumes from earlier tasks:* nothing; this is the first task.
- *Provides to Task 2:* the placeholder names `[DIFF_FILE]` and `[REVIEW_FILE]`,
  the literal `WRITE_FAILED`, the literal `plan-mandated`, and the review file's
  first-line forms `delivery: package` and `delivery: rebuilt diff`. Task 2's
  `SKILL.md` text refers to all of these by exactly these spellings.

### Step 1.1 — read the current template and its sibling

Read `skills/forge/code-reviewer.md` in full, then read
`skills/forge/task-reviewer-prompt.md` lines 33–55 (its `## The change you are
judging` and read-only sections) and `skills/forge/implementer-prompt.md` lines
110–139 (its reporting and cap sections). Those two are the patterns this task
converges on. Do not edit either.

Expected: you can state, before editing, which clauses of the task reviewer's
package section are about *delivery* and which are about *scope*. Global
Constraint 4 and Step 1.3 depend on the distinction.

### Step 1.2 — replace the `## Git Range to Review` section

Find this section inside the fenced dispatch block:

```
    ## Git Range to Review

    The branch starts at [BASE_SHA] and ends at [HEAD_SHA].

    ```bash
    # what moved
    git diff --stat [BASE_SHA]..[HEAD_SHA]
    # and how
    git diff [BASE_SHA]..[HEAD_SHA]
    ```
```

Replace it with:

```
    ## The change you are judging

    The branch runs from [BASE_SHA] to [HEAD_SHA], packaged in [DIFF_FILE].

    Open that package once. Inside are the commits, a per-file stat, and every
    hunk with generous context around it, and those context lines *are* the
    files as they now stand. The package is the diff for this range: do not
    re-derive it. If the package is missing, rebuild it —
    `git diff --stat [BASE_SHA]..[HEAD_SHA]`, then
    `git diff [BASE_SHA]..[HEAD_SHA]` — and say so on the first line of your
    review file. A rebuilt diff carries narrower context than the package, and
    whoever reads the review needs to know which one you had.

    Unlike a task review, you are not confined to the package. This pass exists
    for what a task-scoped reviewer could not see: the plan the branch was built
    from, the call sites of a contract it changed, the documentation it left
    stale. Read beyond the package where the work requires it, and record in the
    review what you read and why.
```

The indentation is four spaces, matching every other line inside that fenced
block. Getting it wrong changes what the dispatch reads as prompt text.

### Step 1.3 — amend the read-only rule

Find:

```
    Treat this checkout as read-only: the working tree, the index, HEAD and
    every branch stay exactly as you found them. Reading history is
    unrestricted — `git show`, `git diff` and `git log` all leave the checkout
    alone. When you genuinely need another revision's files laid out on disk,
    give that revision a directory of its own rather than moving this one:
    `git worktree add /tmp/review-[SHA] [SHA]`.
```

Replace with:

```
    Treat this checkout as read-only with one exception: the review file at
    [REVIEW_FILE] is yours to write. Nothing else moves — not the working tree,
    the index, HEAD or any branch, and not any other file in the directory
    [REVIEW_FILE] sits in, which holds the controller's own working records.
    Reading never mutates anything, so `git show`, `git log` and history
    inspection are unrestricted; that is not licence to re-derive the diff you
    were handed. When you genuinely need another revision's files laid out on
    disk, give that revision a directory of its own rather than moving this
    one: `git worktree add /tmp/review-[SHA] [SHA]`.
```

The exemption is one named path, not the directory. The directory holds the
controller's progress ledger.

### Step 1.4 — add the plan-mandated label to Calibration

The `## Calibration` section already ends with a paragraph beginning "Where the
branch leaves the plan in a way that matters". Append to that paragraph:

```
    Label such a finding `plan-mandated`, the same word the task reviewer uses,
    and count it in what you send back.
```

Do not change the rest of Calibration.

### Step 1.5 — turn `## Output Format` into the review file's shape

Rename the section heading `## Output Format` to `## Where your review goes` and
insert this immediately under the new heading, before the existing `###
Strengths` line:

```
    Write the review to [REVIEW_FILE]. Its first line names the delivery you
    had — `delivery: package` or `delivery: rebuilt diff` — and the review
    follows under it, in the sections below.
```

Leave `### Strengths`, `### Issues`, the three severity buckets, `###
Recommendations`, `### Assessment`, and the `**Ready to merge?**` /
`**Reasoning:**` lines exactly as they are. The rubric is frozen by Global
Constraint 3.

Then, under the `#### Minor (Nice to Have)` bucket's existing description, add:

```
    Where the controller handed you a list of Minor findings carried over from
    earlier tasks, triage it here against the merge bar.
```

### Step 1.6 — add the bounded return

Immediately after the `### Assessment` block and before `## Critical Rules`,
insert a new section:

```
    ## What you send back

    Fifteen lines at most. The review is in the file; this message is only what
    the controller needs to choose its next move:

    - **Ready to merge?** Yes | No | With fixes
    - the counts: `Critical N, Important N, Minor N, plan-mandated N`. The
      plan-mandated findings are a subset of the graded ones and not a fourth
      grade, so `Important 2, plan-mandated 2` describes two findings, not four.
    - where the review file is

    Nothing else. No findings, no summary of them, no preamble, no account of
    your method. Whoever acts on a finding reads the file.

    If you could not write the review file, send back `WRITE_FAILED` as the
    first line and the reason on the second, instead of a verdict. Do not report
    a verdict whose evidence you were unable to record.
```

### Step 1.7 — update the three trailing blocks

These sit outside the fenced dispatch block and currently contradict what the
template now does.

Replace the `**Placeholders:**` list with:

```
**Placeholders:**
- `[DESCRIPTION]` — what was built, in a sentence or two
- `[PLAN_OR_REQUIREMENTS]` — what it was supposed to do: a plan path, the task
  text, or the requirements themselves
- `[DIFF_FILE]` — REQUIRED. Where the review package was written.
  `scripts/review-package BASE HEAD` prints a path unique to that range, and the
  package's contents never pass through the controller's own context.
- `[REVIEW_FILE]` — REQUIRED. Where the reviewer writes the review. The
  controller clears this path before dispatching and reads it afterwards.
- `[BASE_SHA]` — the branch's fork point from the base branch
- `[HEAD_SHA]` — the commit it ends on
```

Replace the `**What comes back:**` line with:

```
**What comes back:** at most fifteen lines — a merge verdict, the finding counts
by grade plus the `plan-mandated` subset, and the review file's path. Or
`WRITE_FAILED` and a reason. The review itself is in `[REVIEW_FILE]`.
```

Change the `## Example Output` heading to `## Example review file`, and add
after that example a second, short one:

```
## Example return message

```
**Ready to merge?** With fixes
Critical 0, Important 2, Minor 1, plan-mandated 0
Review: .agent/sdd/final-review-a1b2c3d..e4f5a6b.md
```
```

### Step 1.8 — verify and commit

```sh
just verify
```

Expected: exit 0, ending with `check-skill-shape: 27 skills, all rules pass` and
`test: N suites passed`. If `check-skill-shape` reports a reference link that
does not resolve, you added a `../../references/` link — remove it; this task
adds none.

Read the whole file once more and confirm: no `[REPORT_FILE]` anywhere (that
placeholder belongs to the sibling templates and means the opposite thing); the
four-space indentation is unbroken inside the fenced block; and no
`git diff [BASE_SHA]..[HEAD_SHA]` survives outside the package-missing rebuild
clause.

```sh
git add skills/forge/code-reviewer.md
git commit -m "feat(forge): budget the whole-branch reviewer's diff and return"
```

**Acceptance criteria.**

- `skills/forge/code-reviewer.md` names `[DIFF_FILE]` as the diff's source and
  contains no instruction to run `git diff` other than the package-missing
  rebuild.
- It instructs the reviewer to write the review to `[REVIEW_FILE]`, first line
  `delivery: package` or `delivery: rebuilt diff`.
- It caps the return at fifteen lines carrying exactly three items, and defines
  `WRITE_FAILED`.
- It labels plan-fault findings `plan-mandated` and counts them as a subset.
- The read-only rule exempts `[REVIEW_FILE]` alone, not its directory.
- `Critical` / `Important` / `Minor` are unchanged.
- The Placeholders list, the "What comes back" line, and the examples agree with
  the body.
- `just verify` exits 0.

## Task 2 — make the controller supply and verify the two paths

**Modifies:** `skills/forge/SKILL.md`
**Creates:** nothing
**Tests:** `just verify`

**Where this fits.** Task 1 changed what the reviewer is asked for. This task
changes the controller that dispatches it, so the two agree.

**Interfaces.**

- *Consumes from Task 1:* the placeholders `[DIFF_FILE]` and `[REVIEW_FILE]`,
  and the literals `WRITE_FAILED`, `plan-mandated`, `delivery: package`,
  `delivery: rebuilt diff` — all spelled exactly as Task 1 wrote them.
- *Provides to later tasks:* nothing; this is the last task.

### Step 2.1 — rewrite the final-review dispatch instruction

Find, in `### The per-task loop`, the paragraph after step 8:

```
After the last task, dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model. The per-task
reviews are task-scoped by design and cannot see a defect that spans tasks.
```

Replace it with:

```
After the last task, dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model. The per-task
reviews are task-scoped by design and cannot see a defect that spans tasks.

Its base is the branch's fork point — `git merge-base HEAD <BASE_BRANCH>`,
recomputed here rather than carried forward, with `BASE_BRANCH` the value
`$attunement` recorded. Not the commit the build phase started from: anything
already on the branch, a committed spec and plan included, belongs to the
branch this review is judging. Recompute rather than reuse, because a rebase
moves the fork point. If `BASE_BRANCH` is unknown, ask — do not default to
`main`, which yields a plausible-looking package of the wrong range in every
repository that names its default branch anything else.

Then produce the two paths and check them:

1. `scripts/review-package <fork-point> HEAD` for `[DIFF_FILE]`. It prints a
   commit count and a byte count; both must be non-zero before you dispatch.
   The script exits 0 even when its destination write fails, and the template's
   package-missing clause would then have the reviewer rebuild the diff
   inline — restoring the cost this whole arrangement removes. On a zero count,
   report it and stop; do not dispatch and do not fall back.
2. `[REVIEW_FILE]` is `<workspace>/final-review-<base7>..<head7>.md`, in the
   directory `scripts/sdd-workspace` prints. Remove anything already at that
   path before dispatching, so that a file there afterwards is this dispatch's
   and not a leftover from a resumed session.
3. After the reviewer returns, that path must exist, be non-empty, and open with
   `delivery: package`. `delivery: rebuilt diff` means the reviewer never had
   the package — record that in the ledger, because it changes what the review
   was able to see.

A missing or empty file means the return is not evidence: discard it and
re-dispatch once, then stop and report. That single blind retry is for a silent
failure. A reviewer that returned `WRITE_FAILED` has already named a reason:
where it names the path, retry once at a second path in the same workspace
directory and nowhere else; where it names the directory or a permission, a
different path cannot help, so stop and report the workspace as the blocker. A
stop here means the branch goes on to the rest of the pipeline with no
whole-branch review, and you say so rather than closing the phase quietly.
```

### Step 2.2 — rewrite the final-fix instruction

Find, in `### What goes in a dispatch`:

```
If the **final** review returns findings, send **one** fix subagent with the
complete list; per-finding fixers each rebuild context and re-run suites, and one
real session's final-review wave cost more than all its tasks combined.
```

Replace with:

```
If the **final** review returns findings, send **one** fix subagent and give it
the review file's path rather than a list — a list is the resident context cost
the review file exists to remove. Per-finding fixers each rebuild context and
re-run suites, and one real session's final-review wave cost more than all its
tasks combined.

Say in that dispatch what binds it, because a path carries none of the filtering
a hand-picked list did: Critical and Important findings are to be fixed, Minor
findings and Recommendations are not, and a finding labelled `plan-mandated` is
returned to you rather than fixed.

Order the two triggers, because they overlap — a `plan-mandated` finding is
graded like any other and carries the label as well:

1. A non-zero `plan-mandated` count goes to the human first, and the fix wave
   waits on the answer. Dispatching a fix before it would be you overruling a
   call reserved for the human.
2. That answer partitions the labelled findings: the upheld ones join the wave,
   the overruled ones are dropped and recorded as overruled.
3. Then one fix subagent, against the unlabelled findings plus the upheld
   labelled ones, graded Critical or Important — and only if that set is
   non-empty.

A `No` or `With fixes` carrying no graded findings at all is a return to open the
file for rather than act on: its two halves cannot both be right.
```

### Step 2.3 — narrow the overstated report-contract claim

Find, in `### What goes in a dispatch`:

```
Every reviewer dispatch ends with the same report contract, so you get a bounded
verdict rather than the whole review.
```

Replace with:

```
The whole-branch reviewer returns a bounded verdict and a path; the task
reviewer's message is still its report, bounded instead by the single task it
covers. Neither hands you a review to hold.
```

That sentence is overstated as it stands, and this change makes the
overstatement load-bearing — it is the rule the whole-branch template is being
brought under.

### Step 2.4 — widen the `Never` bullet

Find, in `### Never`:

```
- Dispatch a task reviewer without a review-package file.
```

Replace with:

```
- Dispatch any reviewer without a review-package file.
```

### Step 2.5 — verify and commit

```sh
just verify
```

Expected: exit 0, `check-skill-shape: 27 skills, all rules pass`. Rule 4 of that
gate scans `skills/*/SKILL.md` for backticked `$invocation` tokens and fails on
one that names no skill. This task introduces `` `$attunement` ``, which exists;
if the gate reports `$attunement is invoked but no such skill exists`, you have
misspelled it.

```sh
git add skills/forge/SKILL.md
git commit -m "feat(forge): produce and verify the whole-branch review's paths"
```

**Acceptance criteria.**

- The final-review dispatch names the fork point, recomputed, with the
  no-`BASE_BRANCH` and no-default-to-`main` rules stated.
- It requires a non-zero commit and byte count on the package before dispatch,
  clears `[REVIEW_FILE]` before dispatch, and checks existence, non-emptiness
  and the `delivery:` line afterwards.
- The failure paths are stated: one blind retry for a silent failure, a
  reason-gated retry for `WRITE_FAILED`, and an explicit stop that says the
  branch has no whole-branch review.
- The final-fix dispatch passes the path, states what binds the subagent, and
  orders the human question ahead of the fix wave with the partition rule.
- The report-contract sentence describes both dispatches truthfully.
- The `Never` bullet covers any reviewer.
- `just verify` exits 0.

## Rollback

Every change is text in two tracked Markdown files, on a feature branch, in two
commits. `git revert` on either commit restores that file. Nothing is generated,
nothing is cached, no state is written outside the repository, and no consumer
reads either file except a `$forge` run in progress.

## Self-review against the spec

| Spec requirement | Task |
|---|---|
| R1 — package instead of self-run `git diff` | 1.2, 2.1 |
| R2 — review written to a supplied path | 1.3, 1.5, 2.1 |
| R3 — hard cap on the return | 1.6, 1.7 |
| R4 — controller generates, verifies, and routes | 2.1, 2.2, 2.3, 2.4 |
| R5 — `just verify` green | 1.8, 2.5 |

Spec items with no task, checked deliberately: the spec's "no sixth edit adding
the branch base to the ledger" is a statement that nothing is to be done, and
correctly has no task.
