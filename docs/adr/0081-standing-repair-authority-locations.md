# 0081 Standing repair authority reads every accepted instruction location

## Status

Accepted (2026-10-05)

## Context

[ADR 0064](0064-standing-repair-authority-is-base-bound.md) accepts a standing repair
authority section only in a tracked root `AGENTS.md` or `CLAUDE.md`. A repository that is
also a Claude Code plugin with source `./` cannot keep a root `CLAUDE.md`: strict plugin
validation warns that it is not loaded as project context, so this repository moved its
instructions to `.claude/CLAUDE.md` ([issue #442](https://github.com/randomparity/adept/issues/442)).
Such a repository could opt in only through an `AGENTS.md` it does not otherwise use.

## Decision

Extend ADR 0064's location rule; every other ADR 0064 guarantee stands unchanged. The
accepted locations are exactly three repo-relative paths on the protected base revision:
`AGENTS.md`, `CLAUDE.md`, and `.claude/CLAUDE.md`. Only a regular tracked file at one of
those paths is read. A symlink entry is not instruction content and declares nothing; the
file it points at is read only if that file is itself at an accepted path.

The `## Standing repair authority` section must occur exactly once across the union of
those files. None means no opt-in. More than one, within one file or across files, is a
duplicate and fails closed. The authority's source is the one file that holds the section:
a worker records its path and Git blob ID, and maintainer approval binds that blob as in
ADR 0064. Adding the section to a second accepted location on the base therefore revokes
standing authority until one copy is removed.

## Consequences

A plugin repository can opt in through the instruction file it actually uses. A branch
edit to the new location grants nothing, because the read stays on the protected base and
the approval stays bound to the declaring file's blob. A policy whose permitted surfaces
cover `.claude/` now covers an authority location: a repair it admits there could restore
an earlier approved blob of the declaring file. ADR 0064 names no control for that replay
at the root locations either; this record accepts it for `.claude/CLAUDE.md` on the same
terms and leaves a rule barring repairs to accepted locations to a follow-up. Instruction
files elsewhere — nested
directories, `CLAUDE.local.md`, user-level files — still declare nothing.

## Considered & rejected

- **Do nothing; such a repository opts in through a root `AGENTS.md`.** judgment: it forces a
  second instruction file whose rules can drift from the one the harness loads.
- **Accept any file Claude Code loads as instructions.** judgment: nested and personal files
  scatter authority beyond what a maintainer reviews as repository policy.
- **Let one location take precedence when several declare the section.** judgment: a second
  copy could silently override an approved one; failing closed keeps one reviewable source.
