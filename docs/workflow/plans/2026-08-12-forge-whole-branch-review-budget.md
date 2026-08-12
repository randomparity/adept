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
   - `PACKAGE_MISSING` — the return's first line when the package the reviewer
     was handed was not there. There is deliberately no rebuild-it-yourself
     fallback; see Step 1.2.
5. **The return cap is fifteen lines**, the same number
   `implementer-prompt.md` already states.
6. **Placeholders in `code-reviewer.md`** after this change:
   `[DESCRIPTION]`, `[PLAN_OR_REQUIREMENTS]`, `[DIFF_FILE]`, `[REVIEW_FILE]`,
   `[MINOR_LEDGER]`, `[BASE_SHA]`, `[HEAD_SHA]`, `[SHA]`. `[BASE_SHA]` and `[HEAD_SHA]` stay
   because the template still names the range it is judging.
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
  and the literals `WRITE_FAILED`, `PACKAGE_MISSING`, and `plan-mandated`.
  Task 2's `SKILL.md` text refers to all of these by exactly these spellings.

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

    Before you open it, create [REVIEW_FILE] empty — *Where your review goes*
    says what that is for. Open the package once. Inside are the commits, a
    per-file stat, and every hunk with generous context around it, and those
    context lines *are* the
    files as they now stand. The package is the diff for this range: do not
    re-derive it, and do not fall back to running `git diff` yourself. If the
    package is not there, you have nothing to review: send back
    `PACKAGE_MISSING` and stop.

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
    Write the review to [REVIEW_FILE], in the sections below.

    You created that file empty before opening the package. If you could not,
    send `WRITE_FAILED` and stop there — discovering an unwritable path after
    the review is written throws away the whole of this dispatch, which is the
    most expensive one in the build.
```

The write is attempted first so an unwritable path costs nothing; the
instruction that makes it happen lives in Step 1.2's section, because that is
where the reviewer reaches it in time to obey. This paragraph states why, and a
reviewer reading top-down has already done it.

Leave `### Strengths`, `### Issues`, the three severity buckets, `###
Recommendations`, `### Assessment`, and the `**Ready to merge?**` /
`**Reasoning:**` lines exactly as they are. The rubric is frozen by Global
Constraint 3.

Then, after the `#### Minor (Nice to Have)` bucket and the `file:line` sentence
that follows the three buckets, add a fourth heading — a heading rather than a
paragraph under `#### Minor`, because the controller reads it by name:

```
    #### Minor triage
    Triage the Minor findings carried over from earlier tasks, listed in
    [MINOR_LEDGER], against the merge bar. Where that placeholder is empty, say
    so in one line rather than omitting this heading — the controller reads it
    by name, and an absent heading is indistinguishable from a skipped triage.

    These are carried over, not found by you: they do not count toward
    `Minor N`, which is your own findings on this branch.
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

    Two things replace the verdict rather than joining it. If you could not
    write the review file, send back `WRITE_FAILED` as the first line and the
    reason on the second. If the package was not at [DIFF_FILE], send back
    `PACKAGE_MISSING` the same way. Never report a verdict whose evidence you
    could not read, or could not record.
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
- `[MINOR_LEDGER]` — the Minor findings accumulated from the task reviews, for
  triage against the merge bar. `SKILL.md` already requires this handover; until
  now it had no named slot. Pass an explicit "none" when the ledger carried no
  Minor findings.
- `[BASE_SHA]` — the branch's fork point from the base branch
- `[HEAD_SHA]` — the commit it ends on
```

Replace the `**What comes back:**` line with:

```
**What comes back:** at most fifteen lines — a merge verdict, the finding counts
by grade plus the `plan-mandated` subset, and the review file's path. Or
`WRITE_FAILED` / `PACKAGE_MISSING` and a reason. The review itself is in
`[REVIEW_FILE]`.
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
`git diff [BASE_SHA]..[HEAD_SHA]` invocation survives anywhere in the file.

```sh
git add skills/forge/code-reviewer.md
git commit -m "feat(forge): budget the whole-branch reviewer's diff and return"
```

**Acceptance criteria.**

- `skills/forge/code-reviewer.md` names `[DIFF_FILE]` as the diff's source and
  contains no instruction to run `git diff` at all.
- It instructs the reviewer to write the review to `[REVIEW_FILE]`, and names
  `[MINOR_LEDGER]` as the carrier for the Minor list it triages.
- It caps the return at fifteen lines carrying exactly three items, and defines
  both `WRITE_FAILED` and `PACKAGE_MISSING`.
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
  and the literals `WRITE_FAILED`, `PACKAGE_MISSING`, and `plan-mandated` — all
  spelled exactly as Task 1 wrote them.
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
   This is artifact validation and not a workaround — any generation step can
   fail, and this file is the reviewer's entire input. On a zero count, report
   it and stop: do not dispatch.
2. `[REVIEW_FILE]` is `<workspace>/final-review-<base7>..<head7>.md`, in the
   directory `scripts/sdd-workspace` prints. Remove anything already at that
   path before dispatching, so that a file there afterwards is this dispatch's
   and not a leftover from a resumed session. `[MINOR_LEDGER]` is the Minor
   findings you have been accumulating; pass the literal `none` when there were
   none, so an empty triage is a stated result rather than a slot you left
   blank.
3. When the reviewer returns, `[REVIEW_FILE]` must exist and be non-empty. If
   you passed a non-empty `[MINOR_LEDGER]`, read that file's triage section
   whatever the verdict — the section, not the whole file — because on a `Yes`
   nothing else would ever read the answer you asked for.

A missing or empty file means the return is not evidence: discard it and
re-dispatch once, then stop and report. That single blind retry is for a
*silent* failure, where nothing says what went wrong. A reviewer that returned
`WRITE_FAILED` or `PACKAGE_MISSING` has already named the problem — stop on the
first one and report it. Do not retry at a second path: that would ask you to
classify the reviewer's free-text reason, and would hand it a second writable
location, which is the containment the template's read-only rule rests on. A
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
a hand-picked list did: Critical and Important findings are to be fixed;
Recommendations are not; and Minor findings are not *unless you name them in the
dispatch*, which is what you have just read the triage section to decide. A
finding labelled `plan-mandated` is likewise returned to you rather than fixed,
unless you name it as one the human has already upheld.

Order the two triggers: a non-zero `plan-mandated` count goes to the human
**before** the fix wave. Read those labelled findings out of `[REVIEW_FILE]`
first — that subset, not the whole file — and put each in front of the human
beside the plan text it disputes; a count alone asks them to rule on work they
have not seen. Then carry their answer into the dispatch by naming the upheld
findings. Nothing further is prescribed.
```

Both "unless you name it" clauses exist for the same reason, and it is why the
ordering paragraph follows them rather than standing alone. The list the
controller used to hand over was composed after it read the whole review, so a
triage-promoted Minor finding or a human-upheld plan fault could ride along in
it; a path carries neither. Without the escapes the two rules deadlock — the
wave carries a finding to a subagent instructed to hand it straight back. Keep
that reasoning here and out of `SKILL.md`, which is re-read on every run.

### Step 2.3 — narrow the overstated report-contract claim

Find, in `### What goes in a dispatch`:

```
Every reviewer dispatch ends with the same report contract, so you get a bounded
verdict rather than the whole review.
```

Replace with:

```
The whole-branch reviewer returns a bounded verdict and a path rather than the
review itself.
```

That sentence is overstated as it stands, and this change makes the
overstatement load-bearing — it is the rule the whole-branch template is being
brought under. Say nothing whatever about the *task* reviewer. Its message **is**
its report, so a sentence claiming neither reviewer returns a review would be
false; characterizing what bounds it, and reconciling the two return shapes, is
issue #45's.

### Step 2.4 — widen the `Never` bullet

Find, in `### Never`:

```
- Dispatch a task reviewer without a review-package file.
```

Replace with:

```
- Dispatch any reviewer without a review-package file.
```

### Step 2.4a — make the phase resumable through the ledger

The dispatch step in Step 2.1 clears `[REVIEW_FILE]` before dispatching. On a
resumed run that deletes a finished review in order to re-run it, so the same
step has to be able to tell a phase that already ran from one that never did.

Give the numbered list a first item that reads the ledger and a later one that
writes it:

```
1. **Read the ledger first.** No `Final review` line for this range: dispatch.
   A verdict line and no `closed` line: the review ran and its file is on disk,
   so resume at the fix wave — do not regenerate, do not clear, do not
   re-dispatch. Both lines: the phase is done.
```

```
5. **Append the ledger line once that check passes** — `Final review
   <base7>..<head7>: <verdict> (review <path>)` — and append a second,
   `Final review <base7>..<head7>: closed`, when the fix wave finishes. Two
   appends rather than an edit, because that is how every other line in that
   ledger is written. Writing the first here and not at the end is what protects
   the fix wave: a run that dies mid-wave otherwise leaves no line, and step 1
   would clear a finished review to re-run it. A dispatch that ends in a stop
   gets no line — there is no review file for a resume to skip to.
```

Three states, not two. A line written only at the very end leaves the fix-wave
window unprotected, which is the window a long final review is most likely to
die in.

The append follows the existence check rather than the reviewer's return, and
the two states are two lines rather than one line edited. Both for the same
reason: the line asserts that a review file is on disk and a resume skips the
dispatch on the strength of it, so it must not be written before that is known,
and it must not need a rewrite that the ledger's append-only convention has no
form for.

**Acceptance criteria.**

- Step 2.1's list opens with a ledger read distinguishing three states, and the
  append comes after the existence check and before the fix wave.
- Both ledger lines are given a literal shape, and closing the phase is a second
  append rather than an edit of the first.
- Nothing else in `SKILL.md`'s `### Durable progress` section changes; the
  per-task ledger lines keep their existing shape.

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
  clears `[REVIEW_FILE]` before dispatch, and checks existence and non-emptiness
  afterwards — plus a conditional read when the ledger carried Minor findings.
- The failure paths are stated: one blind retry for a silent failure, an
  immediate stop on `WRITE_FAILED` or `PACKAGE_MISSING`, and a stop that says
  outright the branch has no whole-branch review.
- The final-fix dispatch passes the path, states what binds the subagent, and
  orders the human question ahead of the fix wave.
- The report-contract sentence describes the whole-branch dispatch and makes no
  claim about the task reviewer.
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

| Spec §R4 item 6 — the ledger read and append | 2.4a |

Spec items with no task, checked deliberately: the spec's "On recording the
base" paragraph is a statement that nothing is to be done, and correctly has no
task. It is a different subject from item 6, which is about the review's own
completion rather than the base value.
