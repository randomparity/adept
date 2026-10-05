# Standing repair authority locations — issue #446

Charter: issue #446 `WORK:SCOPE` token `q446-9cd57ba0`; operator-approved exclusions are
retained there. Design denominator: 100 changed lines (S). Decision:
[ADR 0081](../../adr/0081-standing-repair-authority-locations.md), extending ADR 0064.

## Problem

quest-log accepts the `## Standing repair authority` section only in a tracked root
`AGENTS.md` or `CLAUDE.md`. A plugin repository keeps its Claude instructions in
`.claude/CLAUDE.md`, so it cannot opt in through the file it uses.

## Scope

- `skills/quest-log/SKILL.md`, *Standing repair authority*: state the three accepted paths,
  the regular-tracked-file rule, exactly-once across their union, and the declaring file as
  the recorded source; replace "The root file" with the declaring instruction file.
- `docs/workflow/specs/2026-09-13-standing-repair-authority-design.md`: one pointer line to
  ADR 0081 under its title. The body is untouched.
- `.claude-plugin/plugin.json`: 7.4.0 → 7.5.0.
- Unchanged, checked: `skills/quest/SKILL.md`, `skills/campaign/SKILL.md`, and
  `skills/sort-board/SKILL.md` name the instruction-file blob or path without restating
  locations; `skills/return-to-town/SKILL.md` names only the live standing policy. All
  already cover the new path.
- Ownership: quest-log keeps the rule; no caller migrates and no path becomes obsolete.

## Failure model

1. Actors and deployments: an unattended quest or campaign worker reading a repository's
   protected base; a maintainer approving policy PRs.
2. Invariants and assets: no repair gains authority without one maintainer-approved section
   bound to its blob on the protected base; the duplicate check spans all three paths.
3. Accepted failure classes: a repository with the section in two accepted files loses
   standing authority until one is removed — fail closed by design; a section under a
   different heading level is not a declaration — held by the existing heading rule; a
   policy-admitted repair merged into `.claude/CLAUDE.md` that restores an approved blob is
   ADR 0064's existing replay residual, and no repository here declares the section, so no
   policy's surfaces predate this location.
4. Covered elsewhere: tracker resolution reading `AGENTS.md` (excluded; separate issue);
   nested or user-level instruction paths (excluded; future ADR).

### Threat model

- Boundary widened: the base-branch policy read now includes `.claude/CLAUDE.md`. No
  boundary is added.
- Actor: a repair actor with branch or PR write access who could edit any tracked file.
- Control: the read is of the protected base revision only, and approval binds the declaring
  file's blob, so a branch edit to `.claude/CLAUDE.md` grants nothing; a duplicate across
  paths fails closed, so a second copy cannot override an approved one; a symlink entry
  declares nothing, so one file cannot be counted twice through a link.
- Out of scope: a compromised maintainer approval or protected-branch bypass — ADR 0064.

## Success

1. quest-log names exactly `AGENTS.md`, `CLAUDE.md`, and `.claude/CLAUDE.md` as accepted.
2. Exactly-once, blob-bound approval, base-only read, and fail-closed conditions read as in
   ADR 0064, with the duplicate rule spanning those three paths.
3. `just verify`, `just plugin-check`, and `just version-check` exit 0.

## Validation

- quest-log rule text: `task-test-not-applicable` — Markdown policy prose with no executable
  consumer; anatomy rule 4 forbids asserting on it. Checked by reading against ADR 0081.
- ADR 0081 record shape: `focused-test` — `just records` validates the record format; red if
  a required section is missing, green at exit 0.
- Plugin version: `focused-test` — `just version-check` exits 0 at 7.5.0.
