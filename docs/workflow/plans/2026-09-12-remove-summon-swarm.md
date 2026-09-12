# Implementation plan — remove summon-swarm

Goal: retire the unused Codex-specific skill from newly installed plugin copies and current
documentation for issue #349.

Architecture: delete the sole tracked skill file so harness discovery no longer sees the
invocation; remove the two current user-facing descriptions; advance the one plugin version
source to 5.0.0. This adds no replacement path or executable code.

Tech stack: Markdown, JSON, repository guardrail scripts.

Expected implementation size: 190–230 changed lines (M) — one skill deletion, two prose rows,
and one JSON value, excluding design artifacts.

## Global constraints

- Repository is public; use `$WORK` for checkout references in committed plans and specs.
- `CLAUDE.md` requires a major plugin version for a removed skill; the reserved value is 5.0.0.
- Preserve historical ADRs and dated specs and plans, generic forge and campaign worker
  orchestration, and existing issue state for #345, #343, #344, and #347.
- Add no replacement fleet abstraction, dependency, or prose-assertion test.
- Run `just verify` bare. CI uses `just ci`.

## Files

| Path | Responsibility |
|---|---|
| `skills/summon-swarm/SKILL.md` | Delete the retired discoverable skill |
| `README.md` | Remove its current grouped advertisement |
| `docs/cheatsheet.md` | Remove its current skill row |
| `.claude-plugin/plugin.json` | Advance the distribution version to 5.0.0 |

## Task 1 — retire the shipped contract

This is one task because the deleted skill, current documentation, and version are one plugin
distribution contract. Creates no file. Modifies the four paths in the file map.

### Interfaces

Consumes: harness discovery of `skills/<name>/SKILL.md` and the plugin version field, both
documented in `CLAUDE.md`. Produces: a 5.0.0 plugin tree without the retired invocation.

### Verification

- Skill discovery — `Mode: focused-test`: `test ! -e skills/summon-swarm/SKILL.md` exits 1
  before the edit; after deletion, the same command exits 0. The
  structural, link, and distribution checks run in `just verify`.
- Plugin version — `Mode: focused-test`: the current manifest reads 4.7.2 before the edit;
  `just version-check` exits 0 after setting 5.0.0. CI compares it to the base ref.
- README and cheatsheet — `Mode: task-test-not-applicable`: these are human-readable prose
  with no executable consumer; inspect the edited rows directly, following anatomy rule 4.
- Historical records and generic workers — `Mode: task-test-not-applicable`: this is an
  unchanged-file boundary verified in the diff; no task-specific test can prove prose was not
  edited more directly than the changed-file list.

### Steps

1. Confirm the file and old version with `test -e skills/summon-swarm/SKILL.md` and
   `cat .claude-plugin/plugin.json`; expect the file to exist and version 4.7.2.
2. Delete `skills/summon-swarm/SKILL.md`; expect `test ! -e` to exit 0.
3. Remove only the `summon-swarm` clause from README's Build & review row and the
   `summon-swarm` row from the cheatsheet; expect both tables to remain legible.
4. Set the JSON version to `5.0.0`; expect `just version-check` to exit 0.
5. Run `just verify` bare; expect exit 0. Read `git diff --check` and the changed-file list;
   expect only the four implementation paths plus this spec and plan.
6. Commit the verified change with a conventional subject. A revert restores the prior skill
   and advertisements; an installed copy picks up the restored contract on a newer version.

### Acceptance criteria

The skill is absent from the shipped tree and current advertisements, the manifest declares
5.0.0, `just verify` passes, and the historical and generic surfaces are unchanged.
