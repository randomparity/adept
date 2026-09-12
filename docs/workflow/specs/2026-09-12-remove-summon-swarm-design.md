# Remove the unused summon-swarm skill — issue #349

## Problem

The plugin still installs and advertises `summon-swarm`, a Codex-specific fleet skill the
operator does not use. Its public invocation remains discoverable even though the requested
workflow is the existing vendor-neutral worker orchestration.

## Scope

Delete `skills/summon-swarm/SKILL.md`, remove its current advertisements from `README.md` and
`docs/cheatsheet.md`, and set `.claude-plugin/plugin.json` to `5.0.0`. The skill directory has
one tracked file. No replacement skill, alias, fleet abstraction, or new dependency is added.
Historical ADRs and dated specs and plans remain as records. Generic forge and campaign worker
orchestration remains intact. Existing issues #345, #343, #344, and #347 remain unchanged.

The plugin loader discovers `skills/<name>/SKILL.md` from the tree. Deleting the file removes the
invocation from a newly installed 5.0.0 copy; removing the two user-facing rows prevents a
current reader from being directed to a skill that no longer ships. The major version follows
the repository's removal rule in `CLAUDE.md` and ADR 0022.

## Success

1. A 5.0.0 plugin tree contains no `skills/summon-swarm/` entry or active user-facing reference
   to its invocation.
2. README and cheatsheet continue to describe the remaining skills without a broken link or
   discovery entry.
3. Historical records and generic worker orchestration are unchanged.
4. Existing structural, link, distribution, version, and full repository guardrails pass.

## Failure model

- **Actors and deployments:** Plugin consumers install a copied repository through Claude Code
  or Codex; readers consult the current README and cheatsheet.
- **Invariants and assets:** A removed invocation must not be advertised as installable; the
  plugin version must advance by a major number so an update can reach an installed copy.
- **Accepted failure classes:** Historical mentions can name the retired skill because they
  describe prior design decisions, not current invocation instructions.
- **Covered elsewhere:** The repository's shape, link, distribution, plugin, and version gates
  cover install structure. Owners of #345, #343, #344, and #347 own backlog reconciliation.

## Validation

- Skill discovery — `focused-test`: before deletion, `test ! -e
  skills/summon-swarm/SKILL.md` exits 1; after deletion, the same command exits 0. Run the existing
  structural, link, and distribution gates through `just verify`.
- Plugin version — `focused-test`: before the edit, `scripts/check-plugin-version.sh` sees
  4.7.2; after the edit, `just version-check` exits 0 with 5.0.0 and CI checks it against base.
- Current prose — `task-test-not-applicable`: no executable consumer validates the wording of
  README or cheatsheet; inspect the two edited rows and their links directly. The repository
  explicitly forbids tests that assert on prose.
- Historical and generic scope — `task-test-not-applicable`: preserving unrelated records and
  instructional prose is verified by reviewing the changed-file list and diff.
