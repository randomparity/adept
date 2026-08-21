# Implementation plan — campaign deferral rescore

Goal: `$campaign` re-reads every issue it deferred against merged `HEAD` before reporting
drained, and applies any priority change as a rationale-bearing comment plus label flip behind
operator confirmation.

Decision: `docs/adr/0026-campaign-rescores-its-deferrals.md`; design:
`docs/workflow/specs/2026-08-21-campaign-deferral-rescore-design.md`.

## Global constraints

- **Instruction-only change.** No script, dependency, label family, or persistent classifier
  state; the contract lives entirely in `skills/campaign/SKILL.md`.
- Preserve: decline semantics (no Queue row, no enqueue), manifest-computable drained check,
  comments-not-body-rewrites.
- Annotation format follows the quest-log convention: whole-line HTML markers, complete-block
  sentinel, latest-complete-wins.
- Public repo: no host paths or private detail anywhere in the diff.
- Version bump per ADR 0022 in `.claude-plugin/plugin.json`.
- Guardrail: `just verify`, run bare.

## Changes

| file | change |
|---|---|
| `skills/campaign/SKILL.md` | (1) manifest schema gains `## Deferrals` with validation and dated Outcomes entries; (2) step 7 records declines in the ledger and runs the rescore pass — stale-score reset against dated merge entries, per-issue source reads at merged `HEAD`, operator-gated `WORK:RESCORE` comment then label flip — before handing to step 8; (3) step 8's drained definition and final report gain the rescore conjunct and outcomes |

## Verification

- `just verify` green on the branch.
- Read-back pass over the edited skill: each of issue #183's three preserve-constraints
  traceable to specific edited text; no contradiction with existing steps 3/4/6/8 contracts.
