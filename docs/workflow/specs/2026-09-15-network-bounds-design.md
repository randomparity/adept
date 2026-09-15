# Network bounds for shipped executables — design

## Problem

Four shipped executables make `git` and `gh` calls across fourteen call sites with no bound, so an
unreachable remote hangs an unattended worker (#379). #379 requires the fix reach all four rather
than one, and nothing here records the bound, the mechanism, or what a breach reports. Without that
record the three applier issues (#384, #386, #387) each invent an answer. This unit writes the
record and changes no executable.

## Scope

One ADR at `docs/adr/0068-a-timeout-is-not-an-answer.md` and one reference at
`references/network-bounds.md`, together deciding: one recorded convention rather than one shared
implementation; a trap-free background-poll-kill-reap mechanism on a Bash 3.2 floor; 30 s per
single request and 120 s per whole paginated invocation; a timed-out write reported as
indeterminate and never retried; a timeout classified in each executable's own existing exit
vocabulary; and GNU coreutils explicitly not becoming a dependency.

`skills/return-to-town/SKILL.md` gains one relative link to the reference, satisfying
`scripts/check-skill-shape.sh` rule 5. `.claude-plugin/plugin.json` goes to `5.10.0`. No
executable, test, or ADR index row changes. Deferrals carried: none.

### Failure model

- **Actors and deployments** — a local operator running `just verify`; CI running `just ci`; the
  three applier runs that read the reference. No runtime actor: this unit ships no code.
- **Invariants at stake** — `docs/adr/` is append-only once merged, so a wrong bound is corrected
  only by a superseding record; three downstream pull requests implement this contract verbatim.
- **Accepted failure classes** — prose that reads two ways: not machine-checkable, and CLAUDE.md
  anatomy rule 4 forbids a gate asserting on it. A bound later found wrong: bounded cost, corrected
  by a superseding record. Aggregate per-run wall time: unbounded here, stated in the ADR.
- **Covered elsewhere** — applying the convention to any executable (#384, #386, #387); the
  `rate_limited` marker misnaming a timeout (#387); `references/dispatch-liveness.md:55`'s own
  `timeout(1)` exposure (unowned, reported as a follow-up).

## Success

1. Both records exist and decide all four questions in #382's *Expected* list.
2. `just records` accepts ADR 0068 and reports no `W-INDEX-TABLE`.
3. Rule 5 resolves the new reference link.
4. `.claude-plugin/plugin.json` reads `5.10.0`.
5. The classification each executable adopts matches that executable's actual taxonomy at
   `15fd217`, not an assumed shared one.

## Validation

- **ADR 0068 conforms to the `adr` record profile** (criterion 2). Mode: `focused-test`. Red: drop
  `## Consequences` and `just records` reports `E-SECTION-MISSING`. Green: `just records`.
- **The reference link resolves** (criterion 3). Mode: `focused-test`. Red: rename the reference and
  `just test skill-shape` reports `reference link does not resolve`. Green: `just test skill-shape`.
- **The manifest version is well-formed** (criterion 4). Mode: `focused-test`. Red: write `5.10`
  and the gate rejects the form. Green: `just version-check`.
- **The convention's prose content** (criteria 1 and 5). Mode: `task-test-not-applicable`. No
  executable consumes the reference's sentences, and CLAUDE.md anatomy rule 4 forbids a gate that
  greps prose — the predecessor that did produced false reds and was deleted.
