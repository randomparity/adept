# Park-composer decision — design

## Problem

Issue #381 asks for a decision, not code: whether `$quest`'s park path gains a `WORK:TRAJECTORY`
composer, in a record superseding or extending ADR 0066. #381's premise — zero observed park failures,
so anatomy rule 2's *performed inconsistently* limb is unavailable — is contradicted by issue #390,
which measures the omission on every hand-written block of one issue. The record must re-argue rule 2
on that evidence and settle four questions: shape, an unreachable handshake, the relaxed branch-state
refusal, and `status:` label ownership.

## Scope

One new record, `docs/adr/0069-the-park-path-stays-prose.md`, extending ADR 0066 rather than
superseding it, plus the campaign-reserved `.claude-plugin/plugin.json` bump to `5.11.2`. No index
row: `docs/adr/README.md` carries no table and the adr record profile warns `W-INDEX-TABLE` when one
appears. No executable ships, so this is a clean extension of the `docs/adr` convention with no
ownership transition and no caller migration. Read but unchanged: ADR 0066,
`skills/return-to-town/scripts/publish-handoff`, `skills/quest/SKILL.md`, `skills/quest-log/SKILL.md`,
`skills/resurrection/SKILL.md`, and `references/merge-gate.md`.

### Failure model

Actors and deployments:
- a maintainer reading `docs/adr/` to learn whether the park path has a composer;
- the `records` CI job and the `just records` local gate, reading the file's structure.

Invariants and assets at stake:
- ADR 0066 stays byte-unchanged — merged, append-only, and not superseded here;
- record numbering: 0069 is assigned, not derived, so no sibling row's number is taken.

Accepted failure classes:
- a reader disagreeing with the verdict — the record states its ground and what would reopen it;
- the park path keeping the sentinel-omission exposure — accepted in the record's Consequences. The
  `status:` label bounds the parked state in an ordinary park, though latest-complete-wins returns
  an earlier block as current rather than none; unbounded in an interrupted park. Routed to #390.

Covered elsewhere:
- the hand-write instruction-shape defect on every hand-composed `WORK:*` surface, park included — #390;
- closing #380's two remaining children — the campaign orchestrator.

## Success

1. The record settles each of #381's four questions explicitly, including where one does not discriminate.
2. It re-argues anatomy rule 2 without 0066's four-failure evidence, weighing #390's.
3. It names which ADR 0066 judgments survive and which do not, citing rather than restating.
4. `just verify` and `just records` pass; `.claude-plugin/plugin.json` reads `5.11.2`.

## Validation

- Contract: the record's structural shape — required sections, H1 number, unique number — and ADR 0066's
  append-only immutability. Mode: `focused-test`. Case: `.github/scripts/check-records.sh`, `adr` profile.
  Red: delete a required section heading, observe `E-SECTION-MISSING`; gut a line of 0066, observe
  `E-REWRITE`. Green: `just records`.
- Contract: the manifest version rule. Mode: `focused-test`. Case: `scripts/check-plugin-version-test.sh`.
  Red: leave the version at the base ref's value, observe the gate refuse. Green: `just version-check` —
  locally rules 1 and 2 only, the strictly-greater rule needing CI's `BASE_SHA`.
- Contract: the record's argument, Success 1 to 3. Mode: `task-test-not-applicable`. Reason: CLAUDE.md
  anatomy rule 4 forbids a gate asserting on prose, so a decision's soundness has no machine-checkable
  observation; the design review and the gate above bind it.
