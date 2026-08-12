# 0004 — Seek-quest occupancy signals and the cheat-sheet coverage gate

## Status

Accepted (2026-08-12)

## Context

Issue #56 asks for two things: a `$seek-quest` skill that recommends the next
`status:ready` issue to work, and a CI-backed structural check that fails when
a new user-facing skill is added without a matching entry in
`docs/cheatsheet.md`.

`$seek-quest` must exclude issues that are already occupied — assigned, being
worked on a branch, or covered by an open pull request — or blocked by an
unresolved dependency, even though they still carry `status:ready` (the label
can go stale; `$resurrection` is the between-runs repair for that, not
something `$seek-quest` can assume has just run). No skill in this repo
currently maps an issue number to a branch or PR outside `$resurrection`'s
narrower checks (merged-PR-closes and stale-`in-progress` detection), so this
skill needs its own detection rule, and it needs one precise enough not to
treat issue `#5` as occupied because branch `...-56` exists.

Separately, `scripts/check-skill-shape.sh` already inventories every skill
directory and, in its rule 4, scans `SKILL.md` files for backtick-wrapped
`` `$invocation` `` tokens to verify every referenced skill exists. The new
coverage gate needs the same kind of inventory-vs-reference comparison, just
pointed at `docs/cheatsheet.md` instead of at `skills/*/SKILL.md`.

## Decision

**Occupancy and blocked-dependency signals for `$seek-quest`.** A `status:ready`,
non-epic candidate is excluded from the ranking pool when any of:

- `assignees` on the issue is non-empty (GitHub's own assignment signal —
  `$quest` itself never sets one, so this catches only manually-assigned
  work, which is exactly the case issue #56 criterion 6 names);
- an open or remote-tracked branch's name ends in `-<issue-number>`, anchored
  to the end of the branch name so `#5` cannot match `...-56` or `...-156` —
  the hyphen immediately preceding the digits is what `$quest`'s
  `feat/<slug>-<issue-number>` convention guarantees;
- an open pull request's body contains a GitHub auto-link keyword
  (`close(s|d)`, `fix(es|ed)`, `resolve(s|d)`, case-insensitive) at a word
  boundary, followed by optional whitespace, then `#<issue-number>` and a
  non-digit character or end of string — the leading boundary keeps
  "discloses" or "unresolved" from matching the keyword as a substring, the
  optional whitespace matches `$deliver`'s own `Closes #<issue-number>`
  convention (a literal space between keyword and `#`), and the trailing
  boundary is the same one the branch-suffix rule uses, so `closes #5`
  cannot match a PR body that actually says `closes #56`; or its head
  branch matches the same anchored suffix rule as above;
- the issue's own body carries a canonical whole-line `Blocked by #N` record
  (the `quest-log` contract) whose referenced issue is not closed.

The last rule duplicates part of eligibility filtering into revalidation:
`$seek-quest` applies it once across the whole candidate pool before ranking,
and applies the same status/dependency check again — status label and
`Blocked by #N` resolution only, not a fresh assignee/branch/PR occupancy
sweep — to each candidate from the top of the ranked list immediately before
reporting, backfilling from further down the list when one no longer
passes, because ranking and reporting are not atomic — another session could
change a candidate's state in between. Pool-wide filtering keeps an
obviously-occupied-or-blocked issue out of the top three at all; the
narrower status/dependency revalidation catches a change that happens after
ranking but before the report is read (an assignment or a new branch/PR
opened in that window is not caught here, and surfaces instead as a
duplicate-branch conflict if `$quest` is then started on it — an accepted,
cheaply-recoverable gap, not a silent one). Neither pass substitutes for the
other.

**Cheat-sheet coverage gate.** Extend `scripts/check-skill-shape.sh` with a
rule 6: every name already collected in its skill inventory (`$names`) must
appear in `docs/cheatsheet.md` as a backtick-wrapped token `` `name` ``,
scanned with the same `rg` pattern class rule 4 already uses. No exemption
list. Every skill in this repository is directly invocable
(`/<skill-name>` or by name), so there is currently no category of
intentionally-undocumented skill for an exemption to serve — and one that
serves nothing yet is exactly the speculative feature this repo's anatomy
rules argue against. Should a genuinely internal, non-invocable skill class
ever appear, the exemption question is a decision for that change, not a
`TBD` slot reserved now.

## Consequences

- `$seek-quest`'s occupancy detection is coupled to `$quest`'s
  `feat/<slug>-<issue-number>` branch-naming convention; a future rename of
  that convention needs a matching update here. This is a documented
  cross-skill dependency, not a hidden one.
- False negatives are possible — a branch that does not follow the
  convention, or a PR that references the issue without an auto-link
  keyword, will not be detected as occupancy. The cost of a miss is a human
  starting `$quest` on an issue someone else already has a branch for, which
  surfaces immediately as a duplicate-branch conflict and costs no data;
  `$seek-quest`'s winner-only revalidation narrows but does not close this
  window, and closing it further is not worth a heavier detection rule for a
  cheaply-recoverable mistake.
- `check-skill-shape.sh` gains one more rule but no new script, no new
  dependency, and no second skill-inventory scan; `check-skill-shape.sh`
  remains the one place that owns "does the skill directory structure agree
  with what claims to reference it."
- The gate is a flat membership check with no wording assertion, consistent
  with anatomy rule 4 (nothing here greps for a sentence).

## Considered & rejected

**A separate `scripts/check-cheatsheet-coverage.sh`.** Rejected: it would
re-walk `skills/*` to rebuild the same inventory `check-skill-shape.sh`
already builds, adding a script whose only job is not duplicating logic the
existing one already has in scope.

**Require each skill name inside a specific Markdown table (e.g., under
"Phase skills")**, rather than anywhere in the document. Rejected:
`docs/cheatsheet.md` already spreads legitimate skill references across six
different tables (Start here, Full lifecycle prose, Phase skills, Planning &
backlog, Batch orchestration & hygiene, Retrospective & knowledge capture,
Conventions) by design — a skill's right home depends on what it does, and
pinning the check to one table's shape would fail on options the maintainer
correctly chose. Flat backtick-token membership is what rule 4 already
proved works with zero false positives on this tree.

**Un-anchored substring match for branch/PR occupancy** (e.g., `grep -- "-56"`
without end-of-string anchoring). Rejected: it falsely matches `#5` against
`feat/foo-56` and `feat/foo-156`; the trailing-hyphen anchor is required for
correctness, not an optional tightening.

**GitHub's native linked-issue signal** (the GraphQL
`closingIssuesReferences` field, or the REST timeline's cross-reference
events) instead of scanning PR bodies for auto-link keywords. This would
also catch a PR linked through the UI sidebar without a body-text keyword.
Rejected for this change: it needs a GraphQL call or a second REST endpoint
beyond the plain `gh pr list --json` read every other signal here uses,
for a case (sidebar-only linking with no keyword anywhere in the PR) that
`$quest`'s own PR-creation convention never produces. Worth revisiting if
sidebar-only linking turns out to be common in practice; not worth the extra
call to guard against a gap this repo's own tooling doesn't create.

**Skip the pool-wide `Blocked by #N` check and rely on `status:ready` alone.**
Rejected: criterion #6 in the issue explicitly requires excluding
dependency-blocked candidates from the pool, not just from the final winner,
and the label can be stale between a blocker's reopening and the next
`$sort-board`/`$resurrection` sweep.

**Do the winner-only revalidation and skip the pool-wide pass, or vice
versa.** Rejected for the reason given in the Decision section above: the two
checks close different windows and neither is a superset of the other.

## Provenance

Decided while designing the implementation of issue #56
(`docs/workflow/specs/2026-08-12-seek-quest-design.md`).
