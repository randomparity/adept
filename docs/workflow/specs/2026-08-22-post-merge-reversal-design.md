# Post-merge reversal (`$counterspell`) — design

Date: 2026-08-22 · Issue: #51 · ADR: [0031](../../adr/0031-counterspell-owns-post-merge-reversal.md)

## Goal

A defined path for "a merged PR turned out bad": judge the damage, choose revert vs.
fix-forward, write truthful tracking state, and move the urgent fix through a pipeline
whose review is compressed but never skipped.

## User and trigger

The operator (or a campaign orchestrator) invokes `$counterspell <PR-number>` when a PR
has already merged to the base branch and is believed bad. Secondary trigger:
`$return-to-town`, when an operator reports a merge it just recorded as bad, routes here.

## Inputs

- The offending PR number. Resolved once via
  `gh pr view <N> --json state,mergedAt,headRefOid,baseRefOid,closingIssuesReferences,body,title`.
  A PR whose `state` is not `MERGED` does not belong on this path: `OPEN` belongs to its
  own quest's pipeline; `CLOSED` unmerged needs no reversal. Stop and say so.
- The originating issue(s): the PR's closing references plus any issue linked in its body.
- The repository's known attunement facts (base branch, guardrail commands) — assumed
  present; `$counterspell` re-verifies the base branch name but not the whole preflight.

## Procedure

1. **Judge liveness of the damage.** What did the merge break, and is it live? Evidence:
   base-branch CI status after the merge, behavior an installed plugin copy consumes,
   test failures reproducible at `origin/BASE_BRANCH`. If nothing is live — caught before
   anyone consumed it — do not use this path; file or reopen the tracking issue and run
   normal `$quest`. Urgency is the justification for the reduced pipeline, and without
   damage it buys nothing.
2. **Read reversal cost.** From the originating issue's `risk:` label when present;
   otherwise derive from the taxonomy criteria in the quest-log skill and record the
   derivation in the run's annotation. Never write a `risk:` label (human-read invariant).
3. **Choose disposition** per the ADR matrix: revert / fix-forward / revert-plus-follow-up.
4. **Write tracking state**: reopen the original issue when the PR failed its own
   acceptance criteria; otherwise file a new grounded regression issue referencing the
   bad PR. Post `WORK:*` annotations naming the disposition and evidence.
5. **Run the reduced pipeline** per the ADR: hotfix branch off `origin/BASE_BRANCH`,
   claim protocol on the working issue, build (for a pure revert: the mechanical git
   steps, verified against the evidence that convicted the PR), mandatory `$trial-loop`
   with iteration budget 2, security pass only under quest's relevance test, guardrails,
   `$deliver` with a `revert:`/`hotfix:` prefixed title and a body carrying the bad PR
   number, disposition rationale, tracking link, acceptance criteria, and
   `Closes #<working issue>`; then `$return-to-town` default hand-off.

## Error handling

- **Not merged / wrong state** → stop with the snapshot values; no writes.
- **Revert conflicts requiring judgment** → abandon the revert route, fall back to
  fix-forward, note the conflict in the tracking annotation.
- **Revert touches append-only records** → exclude `docs/adr/` (and other record paths)
  from the revert; restore them from the pre-revert commit.
- **A review finding requires a design decision** → the change has outgrown the reduced
  pipeline: park per the quest-log exit edges and hand the tracking issue to full
  `$quest`.
- **No originating issue can be identified** → file the regression issue first (it
  becomes the working issue); never work unclaimed.

## Testing and verification

This change ships instructions, not code; the guardrail suite is the test surface:

- `just ci` green (includes `shape-check`: new skill directory + frontmatter, rule 6
  cheatsheet reference for `counterspell`; `records` gate over the new ADR;
  `version-check`; `plugin-check`).
- Behavioral check of the gate: confirm `scripts/check-skill-shape.sh` passes with the
  new skill present and would fail if the cheatsheet row were dropped (mutate, run,
  revert).
- Cross-reference integrity: every `` `$skill` `` invocation referenced in the new
  SKILL.md resolves to an existing skill (rule 4), and relative links resolve (rule 5).

## Acceptance criteria

1. ADR 0031 exists with Status/Context/Decision/Consequences/Considered & rejected,
   tagged rejection grounds, assigned number 0031.
2. `skills/counterspell/SKILL.md` implements the procedure above.
3. `skills/quest-log/SKILL.md` connects the risk taxonomy's reversal-cost reasoning to
   its executor.
4. `skills/return-to-town/SKILL.md` routes an operator-reported bad merge to
   `$counterspell` while keeping `MERGED` conclusive for cleanup.
5. `docs/cheatsheet.md` references `counterspell` in a way that satisfies shape rule 6.
6. Plugin version bumped MINOR; conventional commits; PR body carries acceptance
   criteria and `Closes #51`; `just ci` green.
