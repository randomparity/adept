# Seek-quest: recommend the next ready issue

## Summary

Add `skills/seek-quest/SKILL.md`, a read-only skill that ranks the
`status:ready` GitHub issue queue and recommends the top candidate for
`$quest`. Add a structural CI gate that fails when a skill directory exists
with no corresponding mention in `docs/cheatsheet.md`, and document
`$seek-quest` there.

This is an instruction-only skill (anatomy rule 1) — no new script backs the
ranking logic itself; the only executable addition is the cheat-sheet
coverage rule folded into the existing `scripts/check-skill-shape.sh` (per
[ADR 0004](../../adr/0004-seek-quest-occupancy-signals-and-cheatsheet-gate.md)).

## Non-goals

- `$seek-quest` never triages, labels, assigns, comments, or edits any issue.
  It is exactly as read-only as `$divination`.
- It never invokes `$quest`. Recommending and acting are separate explicit
  steps (issue criterion #11).
- It does not replace `$resurrection`'s label-reconciliation sweep; occupancy
  detection here is a point-in-time filter for ranking, not a repair.

## Requirements traceability

| # | Source (issue #56 "Expected") | Where satisfied below |
|---|---|---|
| 1 | Read the complete open queue; classify state before ranking | Steps 1–3 |
| 2 | Report untriaged count/IDs; ask triage-first vs. ready-only | Step 4 |
| 3 | Never auto-triage; label result "best among ready" when continuing | Step 4, Step 9 |
| 4 | No ready issues → direct to `$sort-board` | Step 8 |
| 5 | Eligibility: non-epic, `status:ready`, complete priority/risk/effort | Step 5 |
| 6 | Exclude assigned/occupied/blocked issues | Step 6 |
| 7 | Accept caller risk/effort constraints | Step 7 |
| 8 | Deterministic ordering: priority, then oldest creation date | Step 7 |
| 9 | Revalidate winner's status and dependency lines before reporting | Step 8 |
| 10 | Report top three, name the winner, explain ordering | Step 9 |
| 11 | Read-only, stop after recommendation | Hard constraints |
| 12 | Empty eligible queue → actionable explanation | Step 8 |
| — | Document in `docs/cheatsheet.md` | "Cheat-sheet update" section |
| — | CI-backed structural coverage, structural only | "Coverage gate" section |

## `$seek-quest` skill body

### Steps

1. **Resolve repo.** `gh repo view --json nameWithOwner --jq .nameWithOwner` →
   `owner/name`; pass `--repo <owner/name>` on every subsequent `gh` call.

2. **Fetch the open queue.**
   `gh issue list --repo <owner/name> --state open --json number,title,labels,assignees,createdAt,body --limit 500`.
   If exactly 500 rows return, warn that the sweep is truncated at the limit
   rather than treating it as the complete backlog (same discipline as
   `$sort-board`/`$resurrection`).

3. **Classify.**
   - Drop every `epic`-labeled issue — epics sit outside the `status:`
     machine (`quest-log`).
   - **Untriaged**: no `status:*` label at all, or `status:needs-triage`.
   - **Ready pool**: `status:ready`.
   - Everything else (`status:in-progress`, `status:in-review`,
     `status:awaiting-merge`, `status:blocked`, `status:needs-human`) is
     neither untriaged nor ready and takes no further part below.

4. **Triage-freshness checkpoint.** If the untriaged set is non-empty, report
   its count and issue numbers, then ask exactly one question with two
   options: *"Run `$sort-board` on these first"* or *"Continue ranking the
   ready-only pool now."* Do not run `$sort-board` yourself either way — the
   first option is the user's cue to invoke it themselves and re-run
   `$seek-quest` after. If the user picks "continue," carry a
   `ready-only: true` flag into Step 9's report. If the untriaged set is
   empty, skip straight to Step 5 with `ready-only: false`.

5. **Eligibility filter — completeness.** From the ready pool, keep only
   issues carrying exactly one label in each of `priority:*`, `risk:*`, and
   `effort:*`. Report (but do not rank) any ready issue missing one of the
   three, e.g. `#N ready but incompletely classified (missing risk:)`.

6. **Eligibility filter — occupancy and blocked-dependency.** Apply
   [ADR 0004](../../adr/0004-seek-quest-occupancy-signals-and-cheatsheet-gate.md)'s
   signals to what remains from Step 5:
   - Drop any issue whose `assignees` array is non-empty.
   - Fetch branches once:
     `git ls-remote --heads origin` (or `git branch -a` if no `origin`
     remote is configured — use whichever the current checkout has). For
     each surviving candidate issue number `N`, drop it if any branch name
     ends in `-N` anchored to end-of-string (a hyphen immediately followed
     by the digits of `N` and nothing after).
   - Fetch open PRs once:
     `gh pr list --repo <owner/name> --state open --json number,body,headRefName --limit 200`.
     For each surviving candidate `N`, drop it if any open PR's body
     contains, case-insensitively and at a word boundary (so "discloses"
     does not match `closes`), one of `close`, `closes`, `closed`, `fix`,
     `fixes`, `fixed`, `resolve`, `resolves`, `resolved`, followed by
     optional whitespace, then `#N` and a non-digit character or end of
     string — the optional whitespace matches `$deliver`'s own
     `Closes #<issue-number>` convention, and the trailing boundary is the
     same one the branch-suffix rule uses, so `#5` cannot match a body that
     says `closes #56` — or if any PR's `headRefName` matches the same
     anchored branch-suffix rule as above.
   - For each surviving candidate, scan its `body` for a canonical
     whole-line `Blocked by #M` record per the `quest-log` contract
     (case-sensitive, no leading/trailing content, decimal digits after
     `#`). When at least one such line exists, resolve every referenced `M`
     with `gh issue view M --repo <owner/name> --json state`; drop the
     candidate if any referenced issue is not closed, open+missing, or
     unreadable (fail closed, matching `$sort-board`'s dependency guard). No
     canonical line at all means this check passes.
   - Report every dropped issue with its reason (`assigned`, `branch
     <name>`, `PR #<n>`, or `blocked by #<m>`), so an exclusion is never
     silent.

7. **Apply caller constraints, then rank.** If the invocation supplied a
   risk allowlist and/or effort allowlist (e.g. "risk:night-safe only",
   "effort S or M"), drop any remaining candidate whose `risk:`/`effort:`
   value is not in the supplied set. No supplied constraint means no filter
   on that dimension. Sort what remains by `priority:` ascending numeric
   order (`P0` most urgent, `P3` least — `b60205`/`d93f0b`/`fbca04`/`0e8a16`
   in that priority order per the repo's label descriptions), then by
   `createdAt` ascending (oldest first) as the tie-break. This ordering is
   total and requires no further tie-break: `createdAt` is unique per issue.

8. **Empty-queue and winner-revalidation gates.**
   - If Step 7's ranked list is empty and the untriaged set from Step 3 was
     non-empty, direct the user to `$sort-board` (`$seek-quest` never
     selects untriaged, blocked, or occupied work — criterion #4).
     If the untriaged set was also empty, state plainly that there is no
     ready-and-eligible work at all, and point at whatever Step 5/6 dropped
     as the reason (incomplete classification, occupancy, or blocked
     dependency) so the explanation is actionable rather than a bare "none
     found."
   - Otherwise, take the top-ranked candidate as the provisional winner and
     re-run exactly the checks Step 6 already ran for that one issue —
     current `status:` label and canonical `Blocked by #N` resolution — via
     a fresh `gh issue view <winner> --repo <owner/name> --json
     labels,body`. If the winner is no longer `status:ready` or now fails
     the dependency check, drop it, note why, and promote the next
     candidate from Step 7's ordering; repeat until a candidate survives
     revalidation or the list is exhausted (falling back to the first gate
     above if so).

9. **Report.** Present the top three surviving ranked candidates (fewer if
   fewer exist) as `#N — title (priority:P_, risk:_, effort:_, created
   <date>)`, name the winner explicitly, and give a one-line ordering
   rationale (`priority:P0 outranks priority:P1`; ties broken by
   `createdAt`). When `ready-only: true` from Step 4, prefix the
   recommendation with "best among currently ready issues (N untriaged
   issues were not considered)" rather than presenting it as the best issue
   in the whole queue. State that invoking `$quest <winner>` is a separate,
   explicit next action — this skill does not do it.

### Hard constraints

- `gh`, `git ls-remote`/`git branch`, and `Read` only — no `gh issue edit`,
  no comments, no labels, no branches created, no file writes, no invoking
  `$quest` or `$sort-board`.
- Explicit `--json` fields on every `gh` read; no unbounded `gh issue list`
  without `--limit` and a truncation check.
- Every exclusion in Steps 5–6 is reported with its reason; nothing is
  silently dropped from the candidate pool.
- Ground every ranking claim in label data or issue text actually read —
  never infer priority, risk, or effort beyond what a label states.

## Cheat-sheet update

Add `$seek-quest` to `docs/cheatsheet.md`:

- A new "Start here" row: `| I want the next issue to work, chosen for me |
  \`/seek-quest\` |`, positioned above the `/sort-board` row (selection comes
  after triage in the reading order, but before `/quest` since it feeds it).
- A new row in the "Planning & backlog" table: `| \`seek-quest\` | Rank the
  \`status:ready\` queue and recommend the next issue to run \`$quest\` on |`.
- A short cross-reference in the "Full lifecycle: `/quest`" prose noting that
  `$seek-quest` is how a caller without a specific issue number picks one
  before starting the lifecycle (one sentence — this is documentation, not a
  new lifecycle step; `$quest` itself is unchanged).

## Coverage gate

Implement as rule 6 in `scripts/check-skill-shape.sh`, appended after the
existing rule 5 (reference-link resolution), reusing the `$names` inventory
already built at the top of the script:

- For each name in `$names`, check that
  `docs/cheatsheet.md` contains the literal backtick-wrapped token
  `` `<name>` `` (`rg --no-config -qF -- "\`<name>\`" "$root/docs/cheatsheet.md"`,
  capturing and checking the exit status explicitly per the script's existing
  `>1`-is-a-real-failure discipline — never `|| true`).
- Report a missing name via the script's existing `report` helper:
  `"$name: not referenced in docs/cheatsheet.md"`.
- No wording, table-shape, or description-text assertion — membership only,
  per repository anatomy rule 4.

### Making the gate testable

`check-skill-shape.sh` currently hardcodes
`root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` — it always inspects
the real checkout and takes no arguments, so it cannot run against a
synthetic fixture tree today. `check-public-safety.sh` already establishes
the pattern this repo uses to make a gate fixture-testable: accept an
optional root positional argument, falling back to the script-relative
default when none is given. Apply the same shape here — change the existing
`root=` assignment to `root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`
— so `just shape-check` (called with no arguments) is unaffected, and a test
suite can pass a scratch directory. This is a mechanical extension of an
established convention, not a new one.

### Fixture coverage

No test suite exists yet for `check-skill-shape.sh` (no
`scripts/check-skill-shape-test.sh` is tracked). Add one, following
`check-ripgrep-config-test.sh`'s pattern: build a synthetic fixture tree
under a `mktemp -d` scratch root with its own `skills/*/SKILL.md` files and
its own `docs/cheatsheet.md`, invoke `check-skill-shape.sh <fixture-root>`,
and assert on exit status and reported reason. Cover:

1. A fixture skill directory with no cheat-sheet mention fails with the
   exact `not referenced in docs/cheatsheet.md` reason.
2. A fixture skill mentioned (backtick-wrapped) in the fixture cheat sheet
   passes.
3. A wording change elsewhere in the fixture `docs/cheatsheet.md` (e.g.
   rewording a table's description column) beside an already-referenced
   skill's token does not affect the verdict — proving the check is
   structural, not prose-sensitive.
4. The existing rules 1–5 still pass against a minimal valid fixture, so the
   new rule's fixture setup doesn't accidentally validate only rule 6.

Place the suite at `scripts/check-skill-shape-test.sh` (repo convention: a
gate's suite lives beside it in `scripts/`, per `CLAUDE.md`'s "guardrails ...
with its suite beside it").

## Testing

- `just verify` (records, commit-check, shape-check, ripgrep-config-check,
  plugin-check, test, actions-check) must pass with the new rule 6 and its
  fixtures included.
- `shape-check` on the current tree must continue to pass unmodified, since
  every existing skill already has a cheat-sheet mention (verified during
  design: all 26 current skill names already appear as backtick tokens in
  `docs/cheatsheet.md`).
- No automated test can exercise `$seek-quest`'s GitHub-facing ranking logic
  directly — it is prose instructions, not code (anatomy rule 1), and this
  repo's structural gates deliberately do not assert on skill prose
  (anatomy rule 4). Correctness of the ranking algorithm itself is
  established by this spec's traceability table and by `$trial-loop`'s
  adversarial review of the instructions during `$quest` step 6, the same
  verification path every other prose skill in this repo relies on.

## Global constraints (for the plan)

- Bash 3.2 is the floor for any shell touched by the new rule — no
  `mapfile`, no `readarray`, no associative arrays (repo-wide convention,
  restated here because `check-skill-shape.sh` is exactly this floor).
- `rg` invocations pass `--no-config`.
- Shell gate scripts capture `rg`'s exit status explicitly; `>1` is a real
  failure, not "no matches."
- `docs/cheatsheet.md` edits are additive rows/sentences — no restructuring
  of existing tables.
- The plugin has no installer; `tests/fixtures/` stays outside `skills/`.
