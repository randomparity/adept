# Network bounds for shipped executables — design

## Problem

Five shipped callers make eighteen unbounded `git` and `gh` invocations, so an unreachable remote
hangs an unattended worker (#379). #379 requires the fix reach those callers rather than one, and
nothing here records the bound, the mechanism, or what a breach reports. Without it the appliers
(#384, #386, #387) each invent an answer. This unit writes the record only.

## Scope

One ADR at `docs/adr/0068-a-timeout-is-not-an-answer.md` and one reference at
`references/network-bounds.md`. Between them they settle #382's four questions: whether the
convention is shared, the bound and how writes differ, what a breach reports, and whether GNU
coreutils becomes a dependency. The ADR carries the reasoning and evidence; the reference carries
the idiom, bound, write rule and per-caller classification.

`skills/return-to-town/SKILL.md` gains one relative link to the reference, satisfying
`scripts/check-skill-shape.sh` rule 5. `.claude-plugin/plugin.json` goes to `5.10.0`. No
executable, test, or ADR index row changes. Deferrals carried: none.

### Failure model

- **Actors and deployments** — a local operator running `just verify`; CI running `just ci`; the
  applier runs that read the reference. No runtime actor: this unit ships no code.
- **Invariants at stake** — `docs/adr/` is append-only once merged, so a wrong bound needs a
  superseding record; the record's claims about five files are implemented verbatim downstream.
- **Accepted failure classes** — prose that reads two ways: not machine-checkable, and anatomy rule
  4 forbids a gate asserting on it; the reference names a misfit-report route instead. A wrong
  bound: bounded cost, superseded later. Aggregate wall time and four-copy drift: stated, unbounded.
- **Covered elsewhere** — applying the convention: #384, #386, #387. The `rate_limited` marker
  misnaming a timeout: #387. **Unowned**, reported as follow-ups: `github.sh:78`, and
  `dispatch-liveness.md:55`'s `timeout(1)` exposure.

## Success

1. Both records exist and decide all four questions in #382's *Expected* list.
2. `just records` accepts ADR 0068 and reports no `W-INDEX-TABLE`.
3. Rule 5 resolves the new reference link.
4. `.claude-plugin/plugin.json` reads `5.10.0`.
5. Every caller enumerated, and the exit vocabulary each is assigned, matches that file at
   `15fd217` — including the two the issue's evidence did not name.

## Validation

- **ADR 0068 conforms to the `adr` record profile** (criterion 2). Mode: `focused-test`. Red: drop
  `## Consequences` and `just records` reports `E-SECTION-MISSING`. Green: `just records`.
- **The reference link resolves** (criterion 3). Mode: `focused-test`. Red: rename the reference and
  `just test skill-shape` reports `reference link does not resolve`. Green: `just test skill-shape`.
- **The manifest version is well-formed** (criterion 4). Mode: `focused-test`. Red: write `5.10` and
  the gate rejects the form. Green: `just version-check`.
- **The enumeration and classification table are true of the tree** (criteria 1 and 5). Mode:
  `task-test-not-applicable`. The contract is a correspondence between a prose row and a
  script's exit paths; no executable consumes the table, and a gate grepping it would be the prose
  assertion rule 4 forbids. It was established by reading each file's invocation and exit lines at
  `15fd217`; the grounding commands sit in the ADR's `Considered & rejected`.
