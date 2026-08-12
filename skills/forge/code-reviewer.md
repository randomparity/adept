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

    ## Git Range to Review

    The branch starts at [BASE_SHA] and ends at [HEAD_SHA].

    ```bash
    # what moved
    git diff --stat [BASE_SHA]..[HEAD_SHA]
    # and how
    git diff [BASE_SHA]..[HEAD_SHA]
    ```

    ## Read-Only Review

    Treat this checkout as read-only: the working tree, the index, HEAD and
    every branch stay exactly as you found them. Reading history is
    unrestricted — `git show`, `git diff` and `git log` all leave the checkout
    alone. When you genuinely need another revision's files laid out on disk,
    give that revision a directory of its own rather than moving this one:
    `git worktree add /tmp/review-[SHA] [SHA]`.

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
    finding too — report it as one.

    ## Output Format

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

    Each entry gives its `file:line`, the defect, the reason it matters, and —
    where that is not already obvious — the remedy.

    ### Recommendations
    [Worth doing to the code, the design, or the way this was built; not
    defects, and not obligations.]

    ### Assessment

    **Ready to merge?** [Yes | No | With fixes]

    **Reasoning:** [one or two sentences, technical]

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
- `[BASE_SHA]` — the commit the branch left from
- `[HEAD_SHA]` — the commit it ends on

**What comes back:** Strengths, Issues (Critical / Important / Minor),
Recommendations, Assessment — and a merge verdict.

## Example Output

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
