---
name: divination
description: "Estimate a GitHub issue's blast radius, risk, complexity, and decomposition before implementation. Use when asked to scope an issue, assess whether it fits one pull request, or provide grounded sizing to issue and work workflows."
---
# Scope a GitHub Issue

Estimate the size and risk of issue **#<issue-number>** before any work starts. **Read-only** —
this skill writes nothing to GitHub, git, or the filesystem. Its output feeds
`$quest` and `$bounty`'s decomposition.

## Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` → `owner/name`;
   pass `--repo <owner/name>` on every `gh` call.
2. **Read the issue.** `gh issue view <issue-number> --repo <owner/name> --json
   title,body,labels,comments`. Follow any linked issues/PRs named in the body.
3. **Locate the implicated code.** From the issue's nouns and any `file:line` references,
   use `Grep`/`Glob` to find the files and modules the change would touch. Do not guess
   beyond what the text and code support.
4. **Assess and report** (to the user only — no writes; the hand-off to `$quest` is
   **in-session only**, since nothing is persisted for a later session or a dispatched
   subagent to read):
   - **Blast radius** — the files/modules affected, and whether the change is local or
     cross-cutting.
   - **Change hazards** — call out any of: migrations, auth/permissions, public API/contract,
     concurrency, data loss/irreversibility, external services. "none" is a valid result.
   - **Complexity** — `S` (one or two files, no contract change), `M`, or `L` (broad or
     cross-cutting).
   - **Decompose verdict** — "one PR" or "split", and if split, a proposed sub-issue
     breakdown a human can act on.

## Hard constraints

- Read-only: no `gh issue edit`, no comments, no labels, no branches, no file writes.
- Explicit `--json` fields on every `gh` read.
- Ground every claim in the issue text or the code you actually read.
