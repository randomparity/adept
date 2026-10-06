# Implementation plan — standing repair accepted-location bar

Goal: implement `docs/workflow/specs/2026-10-06-standing-repair-location-bar-design.md` for
issue #448.

Architecture: one normative paragraph and two clauses in quest-log's *Standing repair
authority*, one-clause pointers in quest and campaign, and a version bump. No executable code.

Tech stack: Markdown, JSON, repository guardrail recipes.

Expected implementation size: 15–25 changed lines (S) — 7 new quest-log lines plus two
amended sentences, five amended pointer sentences, one JSON value; design artifacts excluded.

## Global constraints

- Public repository: no absolute paths, hosts, or user names in committed text.
- `.claude-plugin/plugin.json` version is exactly 7.6.0 (assigned; never derive or increment).
- Anatomy rule 4: no gate asserts Markdown wording. Do not edit ADR 0064, ADR 0081,
  `references/merge-gate.md`, `skills/sort-board/SKILL.md`, `skills/bounty/SKILL.md`, or
  `skills/return-to-town/SKILL.md`.
- Run gates bare: `just verify`, `just plugin-check`, `just version-check`, `just records`.

## Files

| Path | Change |
|---|---|
| `skills/quest-log/SKILL.md` | Bar paragraph; recheck list and merge predicate apply it |
| `skills/quest/SKILL.md` | Admission sentence and built-diff recheck name the bar |
| `skills/campaign/SKILL.md` | Policy provenance, pending move, pre-merge holds name the bar |
| `.claude-plugin/plugin.json` | `"version": "7.5.0"` → `"7.6.0"` |

## Task 1 — accepted-location bar and version

### Interfaces

Consumes ADR 0082. Callers refer to the rule by the name "quest-log's accepted-location bar";
the quest-log paragraph opens with the bold lead **Accepted locations are outside every policy
(ADR 0082).** so that name resolves.

### Verification

- Skill prose: `task-test-not-applicable` — policy prose with no executable consumer; anatomy
  rule 4 forbids a wording assertion. Read each edit against ADR 0082.
- Plugin version: `focused-test` — `BASE_SHA=$(git rev-parse origin/main) just version-check`
  exits 1 before the bump, 0 after.
- ADR record: `focused-test` — `just records` exits 0.

### Steps

1. In `skills/quest-log/SKILL.md`, after the paragraph ending "do not create a separate policy
   or approval store.", insert a blank line and:

   ```markdown
   **Accepted locations are outside every policy (ADR 0082).** A repair whose diff adds,
   edits, removes, or renames `AGENTS.md`, `CLAUDE.md`, or `.claude/CLAUDE.md` receives no
   standing-policy admission and no policy-bound merge, whatever the policy's permitted
   surfaces say; it takes the ordinary per-repair gate. Compare exact repo-relative paths in
   `git diff --no-renames --name-only <base>...<head>`, which lists both sides of a rename and
   mode-only changes. Before a diff exists, a packet whose frozen `surface` (a campaign row's
   file scope) names or could match one of those paths is not admitted.
   ```

2. In the same section, after "immediately before the final commit-bound merge gate.", add
   "Each recheck applies the accepted-location bar, to the packet surface until a diff exists
   and to the actual diff after."
3. In the policy-bound merge predicate, replace "the actual diff fits the frozen packet," with
   "the actual diff fits the frozen packet and touches no accepted location,".
4. In `skills/quest/SKILL.md`, after "exact** proposed exclusion/owner set." add "A packet whose
   frozen `surface` could reach an accepted instruction location is never admitted
   (quest-log's accepted-location bar)." Replace "Recheck the built diff after review before"
   with "Recheck the built diff after review, including that bar, before".
5. In `skills/campaign/SKILL.md`: end the policy-provenance list "exact exclusion/owner set
   and class fit" with "; a repair under quest-log's accepted-location bar has no class fit";
   change "its exact exclusions/owners; read the row back" to "its exact exclusions/owners
   under quest-log's accepted-location bar; read the row back"; in the pre-merge holds, add
   "a path at an accepted instruction location," after "a new path outside the packet,".
6. Run `BASE_SHA=$(git rev-parse origin/main) just version-check`; expect exit 1. Set the
   version to `7.6.0`; rerun; expect exit 0.
7. Run `just records` and `just plugin-check`; expect exit 0 each. `just verify` is run by the
   managed pre-push hook at push; run it bare if the hook is absent. Commit as
   `docs(quest-log): bar standing repairs at instruction locations`.

Rollback: revert the commit; no state outside the tree changes.
