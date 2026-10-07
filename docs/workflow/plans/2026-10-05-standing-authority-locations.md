# Implementation plan — standing repair authority locations

Goal: implement `docs/workflow/specs/2026-10-05-standing-authority-locations-design.md` for
issue #446.

Architecture: one prose edit to quest-log's *Standing repair authority* rule, one pointer line
in the 2026-09-13 spec, and a version bump. No executable code.

Tech stack: Markdown, JSON, repository guardrail recipes.

Expected implementation size: 15–25 changed lines (S) — about 14 quest-log lines rewritten,
one pointer line, one JSON value; design artifacts excluded.

## Global constraints

- Public repository: no absolute paths, hosts, or user names in committed text.
- `.claude-plugin/plugin.json` version is exactly 7.5.0 (assigned; never derive or increment).
- Anatomy rule 4: no test or gate asserts Markdown wording. Do not edit ADR 0064, the
  2026-09-13 spec body, `skills/quest-log/assets/tracker.sh`, or any other skill.
- Run gates bare: `just verify`, `just plugin-check`, `just version-check`, `just records`.

## Files

| Path | Change |
|---|---|
| `skills/quest-log/SKILL.md` | Location rule names three accepted paths and the declaring file |
| `docs/workflow/specs/2026-09-13-standing-repair-authority-design.md` | One pointer line |
| `.claude-plugin/plugin.json` | `"version": "7.4.0"` → `"7.5.0"` |

## Task 1 — location rule, pointer, and version

### Interfaces

Consumes ADR 0081's decision. Later readers rely on quest-log's heading
`### Standing repair authority` (unchanged; `skills/quest/SKILL.md` and
`skills/campaign/SKILL.md` refer to it by name).

### Verification

- quest-log rule: `task-test-not-applicable` — policy prose with no executable consumer;
  anatomy rule 4 forbids a wording assertion. Read the edited paragraph against ADR 0081.
- Plugin version: `focused-test` — before the bump, `BASE_SHA=$(git rev-parse origin/main)
  just version-check` exits 1 (version not greater than base); after it, exit 0.

### Steps

1. In `skills/quest-log/SKILL.md`, replace the two sentences beginning "A repository opts in
   only through one" with:

   ```markdown
   A repository opts in only through one `## Standing repair authority` section across its
   accepted instruction locations on its protected base branch: a regular tracked file at
   `AGENTS.md`, `CLAUDE.md`, or `.claude/CLAUDE.md` (ADR 0081). A symlink entry declares
   nothing. The section twice in one file or in two files is a duplicate. Read the live
   base version, not the repair branch or issue/PR prose.
   ```

2. In the same paragraph, replace "maintainer approval of the **exact instruction-file Git
   blob**" with "maintainer approval of the **exact Git blob of the file that holds it**", and
   replace "The root file is already the repository's instruction authority;" with "That
   instruction file is already the repository's instruction authority;".
3. Under the title of `docs/workflow/specs/2026-09-13-standing-repair-authority-design.md`,
   add the line `Location rule extended by [ADR 0081](../../adr/0081-standing-repair-authority-locations.md).`
   followed by a blank line.
4. Run `BASE_SHA=$(git rev-parse origin/main) just version-check`; expect exit 1.
5. Set `.claude-plugin/plugin.json` `version` to `7.5.0`; rerun step 4's command; expect exit 0.
6. Run `just records` and `just plugin-check`; expect exit 0 each. Commit as
   `docs(quest-log): accept .claude/CLAUDE.md for standing authority`.

Rollback: revert the commit; no state outside the tree changes.
