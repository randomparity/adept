# Whole-branch code reviewer prompt

The dispatch template for the single review that reads the finished branch as
one thing. Every task already had its own reviewer; this pass exists for the
defect that only appears once the tasks sit together.

**Purpose:** judge completed work against the plan it came from and against
ordinary engineering standards, while the findings are still cheap to act on.

```
Subagent (general-purpose):
  description: "Whole-branch review"
  prompt: |
    Review this branch the way a senior engineer would — attentive to
    architecture, to the patterns the surrounding code already follows, and to
    the fault that only shows itself once the pieces are assembled. Judge the
    work against the plan it was built from, and report what you find before it
    turns into more work downstream.

    ## What Was Implemented

    [DESCRIPTION]

    ## Requirements / Plan

    [PLAN_OR_REQUIREMENTS]

    ## The change you are judging

    The branch runs from [BASE_SHA] to [HEAD_SHA], packaged in [DIFF_FILE].

    Open that package once. Inside are the commits, a per-file stat, and every
    hunk with generous context around it, and those context lines *are* the
    files as they now stand. The package is the diff for this range: do not
    re-derive it, and do not fall back to running `git diff` yourself. If the
    package is not there, you have nothing to review: send back
    `PACKAGE_MISSING` and stop.

    Unlike a task review, you are not confined to the package. This pass exists
    for what a task-scoped reviewer could not see: the plan the branch was built
    from, the call sites of a contract it changed, the documentation it left
    stale. Read beyond the package where the work requires it, and record in the
    review what you read and why.

    ## Read-Only Review

    Treat this checkout as read-only with one exception: the review file at
    [REVIEW_FILE] is yours to write. Nothing else moves — not the working tree,
    the index, HEAD or any branch, and not any other file in the directory
    [REVIEW_FILE] sits in, which holds the controller's own working records.
    Reading never mutates anything, so `git show`, `git log` and history
    inspection are unrestricted; that is not licence to re-derive the diff you
    were handed. When you genuinely need another revision's files laid out on
    disk, give that revision a directory of its own rather than moving this
    one: `git worktree add /tmp/review-[SHA] [SHA]`.

    ## What to Check

    **Plan alignment:**
    - Is everything the plan asked for actually here?
    - Where the code departs from the plan, is the departure an improvement or
      a mistake?
    - Does what was built solve the problem the requirements describe?

    **Code quality:**
    - Are responsibilities split along sensible lines?
    - Are errors handled rather than discarded?
    - Where the language offers type safety, is it taken?
    - Is repetition factored out — without abstracting on the first repeat?
    - Are the edge cases dealt with?

    **Architecture:**
    - Do the design decisions hold up under the constraints that were stated?
    - Will this perform and scale the way its callers need?
    - Does it open any security exposure?
    - Does it sit naturally beside the code around it?

    **Testing:**
    - Do the tests exercise real behaviour rather than the mocks around it?
    - Are the edge cases covered?
    - Where components have to work together, is that pairing tested?
    - Is the suite green?

    **Production readiness:**
    - If a schema moved, how does the data already out there get across?
    - What happens to callers written against the old behaviour?
    - Is the documentation current?
    - Any bug you can see just by reading?

    ## Calibration

    Grade by what is genuinely at stake. Most findings are not Critical, and a
    reviewer who marks them so teaches the reader to discount the grade.

    Lead with what the work got right, concretely. Praise that is accurate is
    what makes the criticism credible.

    Where the branch leaves the plan in a way that matters, say so plainly and
    separately, so the implementer can confirm it was deliberate. And where the
    fault lies in the plan rather than in the code following it, that is a
    finding too — report it as one. Label such a finding `plan-mandated`, the
    same word the task reviewer uses, and count it in what you send back.

    ## Where your review goes

    Write the review to [REVIEW_FILE], in the sections below.

    ### Strengths
    [Name what the work got right, concretely.]

    ### Issues

    #### Critical (Must Fix)
    [Behaviour that is broken, data that can be lost or corrupted, a way in]

    #### Important (Should Fix)
    [A requirement unmet, a structural problem, errors going unhandled, a hole
    in the tests]

    #### Minor (Nice to Have)
    [Naming, polish, a stale comment, an optimisation worth recording]

    #### Minor triage
    Triage the Minor findings carried over from earlier tasks, listed in
    [MINOR_LEDGER], against the merge bar. Where that placeholder is empty, say
    so in one line rather than omitting this heading — the controller reads it
    by name, and an absent heading is indistinguishable from a skipped triage.

    Each entry gives its `file:line`, the defect, the reason it matters, and —
    where that is not already obvious — the remedy.

    ### Recommendations
    [Worth doing to the code, the design, or the way this was built; not
    defects, and not obligations.]

    ### Assessment

    **Ready to merge?** [Yes | No | With fixes]

    **Reasoning:** [one or two sentences, technical]

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

    ## Critical Rules

    Cite, do not assert: every finding carries a `file:line`, the defect and why
    it matters. "Improve error handling" names nothing and cannot be acted on.

    Grade honestly in both directions — a nitpick filed as Critical costs the
    same credibility as a real defect filed as Minor. Say what the branch got
    right. Finish on the verdict, stated outright rather than implied.

    Never report on code you did not read, and never send back "looks good" as
    the whole of a review. An approval that cost you nothing tells the reader
    nothing.
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

**What comes back:** at most fifteen lines — a merge verdict, the finding counts
by grade plus the `plan-mandated` subset, and the review file's path. Or
`WRITE_FAILED` / `PACKAGE_MISSING` and a reason. The review itself is in
`[REVIEW_FILE]`.

## Example review file

```
### Strengths
- The retry budget is enforced in one place and every caller goes through it (retry.go:44-71)
- 23 tests, covering the three timeout boundaries the plan singled out
- Failures keep the upstream status code instead of collapsing to a generic error (client.go:118)

### Issues

#### Important
1. **The backoff ceiling is computed but never applied**
   - File: retry.go:63
   - Issue: the clamped delay lands in a local the sleep call does not read, so a long outage backs off without bound
   - Fix: sleep on the clamped value

2. **A config error does not name the setting that caused it**
   - File: config.go:29-34
   - Issue: the operator sees "invalid duration" with nothing saying which key produced it
   - Fix: include the key and the rejected value in the message

#### Minor
1. **Table tests are named by index**
   - File: retry_test.go:12
   - Issue: a failure prints case 4 rather than what case 4 is
   - Impact: every red run costs a second read to locate

### Recommendations
- Put a metric on the retry budget; it is the first thing anyone asks for mid-incident

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The structure is right and the tests are real, but the unapplied ceiling is a live defect on exactly the path this change exists to protect.
```

## Example return message

```
**Ready to merge?** With fixes
Critical 0, Important 2, Minor 1, plan-mandated 0
Review: .agent/sdd/final-review-a1b2c3d..e4f5a6b.md
```
