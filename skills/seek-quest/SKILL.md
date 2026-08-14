---
name: seek-quest
description: "Rank the status:ready GitHub issue queue and recommend the next issue to work, excluding untriaged, occupied, or blocked candidates. Use when asked to pick the next issue, choose what to work on next, or select from the ready backlog before running $quest."
---
# Recommend the Next Ready Issue

Rank the `status:ready` GitHub issue queue and recommend the top candidate for
`$quest`. **Read-only** — this skill writes nothing to GitHub, git, or the
filesystem. It never invokes `$quest` or `$sort-board`; recommending and acting
are separate explicit steps, and this skill only recommends.

Input: an optional caller-supplied risk allowlist and/or effort allowlist
(e.g. "risk:night-safe only", "effort S or M"). No input narrows nothing.

## Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` →
   `owner/name`; pass `--repo <owner/name>` on every subsequent `gh` call.

2. **Fetch the open queue.**
   `gh issue list --repo <owner/name> --state open --json number,title,labels,assignees,createdAt,body --limit 500`.
   If exactly 500 rows return, warn that the sweep is truncated at the limit
   rather than treating it as the complete backlog.

3. **Classify.**
   - Drop every `epic`-labeled issue.
   - **Untriaged**: no `status:*` label at all, or `status:needs-triage`.
   - **Ready pool**: `status:ready`.
   - Everything else (`status:in-progress`, `status:in-review`,
     `status:awaiting-merge`, `status:blocked`, `status:needs-human`) takes
     no further part below.

4. **Triage-freshness checkpoint.** If the untriaged set is non-empty, report
   its count and issue numbers, then ask exactly one question with two
   options: *"Run `$sort-board` on these first"* or *"Continue ranking the
   ready-only pool now."* Never run `$sort-board` yourself either way. If the
   user picks "continue," carry `ready-only: true` into the report. If the
   untriaged set is empty, continue with `ready-only: false`.

5. **Eligibility filter — completeness.** From the ready pool, keep only
   issues carrying exactly one label in each of `priority:*`, `risk:*`, and
   `effort:*`. Report (but do not rank) any ready issue failing this, naming
   the dimension and how: `#N ready but incompletely classified (missing
   risk:)` for zero labels in a dimension, `#N ready but ambiguously
   classified (two priority: labels)` for more than one.

6. **Eligibility filter — occupancy and blocked-dependency.** Apply these
   signals to what remains from Step 5:
   - Drop any issue whose `assignees` array is non-empty.
   - Fetch branches once: `git ls-remote --heads origin` (or `git branch -a`
     if no `origin` remote is configured). For each surviving candidate
     issue number `N`, drop it if any branch name ends in `-N` anchored to
     end-of-string (a hyphen immediately followed by the digits of `N` and
     nothing after — this is what `$quest`'s `feat/<slug>-<issue-number>`
     convention guarantees, and the anchor is what keeps `#5` from matching
     `...-56` or `...-156`).
   - Fetch open PRs once:
     `gh pr list --repo <owner/name> --state open --json number,body,headRefName --limit 200`.
     If exactly 200 rows return, warn that PR occupancy detection is
     truncated at the limit. For each surviving candidate `N`, drop it if
     any open PR's body contains, case-insensitively and at a word boundary
     (so "discloses" does not match `closes`), one of `close`, `closes`,
     `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`,
     followed by optional whitespace, then `#N` and a non-digit character or
     end of string. The optional whitespace matches `$deliver`'s own
     `Closes #<issue-number>` convention, and the trailing boundary keeps
     `#5` from matching a body that says `closes #56`. Also drop it if any
     PR's `headRefName` matches the same anchored branch-suffix rule as
     above.
   - For each surviving candidate, scan its `body` line by line for the
     `quest-log` dependency contract's three states:
     - **No line begins `Blocked by #`.** This check passes.
     - **At least one line is a canonical whole-line `Blocked by #M`
       record** (case-sensitive, no leading/trailing content, decimal
       digits after `#`). Resolve every referenced `M` with
       `gh issue view M --repo <owner/name> --json state`. Drop the
       candidate unless every canonical reference resolves closed.
     - **A line begins exactly `Blocked by #` but fails that grammar.**
       Malformed and holds the issue blocked regardless of any other
       canonical line present: drop the candidate.
     Only the first branch allows the candidate through; the other two fail
     closed.
   - Report every dropped issue with its reason (`assigned`, `branch
     <name>`, `PR #<n>`, or `blocked by #<m>`) — nothing is silently
     dropped.

7. **Apply caller constraints, then rank.** Drop any remaining candidate
   whose `risk:`/`effort:` value is not in a supplied allowlist; no supplied
   constraint means no filter on that dimension. Sort what remains by
   `priority:` ascending numeric order (`P0` most urgent, `P3` least), then
   by `createdAt` ascending (oldest first) as the first tie-break, then by
   issue `number` ascending as the final tie-break (`createdAt` is not
   guaranteed unique for batch-created issues; `number` always is).

8. **Empty-queue and revalidation gates.** Revalidation here rechecks only
   status label and `Blocked by #N` resolution — it does not re-fetch
   assignees, branches, or PRs. An assignment or a new branch/PR opened
   against a candidate in the window between Step 6 and this step is not
   caught here; it surfaces instead as a duplicate-branch conflict if
   `$quest` is started on that candidate afterward.
   - If the ranked list from Step 7 is empty, direct the user to
     `$sort-board` regardless of whether the untriaged set was empty —
     `$sort-board` also re-evaluates `status:blocked` candidates for
     cleared dependencies, so it is the right next step whether the empty
     pool comes from untriaged, blocked, or unclassified issues. Point at
     whatever Step 3/5/6 dropped as the reason.
   - Otherwise, walk the ranked list from the top. For each candidate,
     re-run Step 6's status/dependency checks via a fresh
     `gh issue view <candidate> --repo <owner/name> --json labels,body`.
     Keep a candidate that survives as one of the report's surviving
     candidates; drop and note why one that doesn't. Continue until three
     candidates survive or the ordering is exhausted — a demoted winner is
     backfilled from further down the list, not just dropped from the
     count. If revalidation leaves zero survivors, fall back to the first
     gate above.

9. **Report.** Present the surviving ranked candidates (up to three) as
   `#N — title (priority:P_, risk:_, effort:_, created <date>)`, name the
   winner explicitly (the first survivor), and give a one-line ordering
   rationale. When `ready-only: true`, prefix the recommendation with "best
   among currently ready issues (N untriaged issues were not considered)."
   State that invoking `$quest <winner>` is a separate, explicit next
   action — this skill does not do it.

## Hard constraints

- `gh`, `git ls-remote`/`git branch`, and `Read` only — no `gh issue edit`,
  no comments, no labels, no branches created, no file writes, no invoking
  `$quest` or `$sort-board`.
- Explicit `--json` fields on every `gh` read; no unbounded `gh issue list`
  without `--limit` and a truncation check.
- Every exclusion in Steps 5–6 is reported with its reason; nothing is
  silently dropped from the candidate pool.
- Ground every ranking claim in label data or issue text actually read —
  never infer priority, risk, or effort beyond what a label states.
- Fail stop, not silent, on a `gh`/`git` command in Steps 1–2, 6, or 8 that
  could not run (auth failure, rate limit, no network, no `origin` remote).
  Report which command failed and its error text rather than treating the
  failure as a zero-result success.
