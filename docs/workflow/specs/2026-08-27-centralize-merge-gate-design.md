# Centralized merge gate — design (issue #242)

Charter: `WORK:SCOPE` token `q242-1d2e17b9` on issue #242. Decision record:
[ADR 0042](../../adr/0042-centralize-the-merge-gate.md).

## Goal

Replace the three inline copies of ADR 0035's four-part commit-bound merge gate with one
reference that `campaign`, `quest`, and `return-to-town` consult at their existing merge
boundary.

## Design

`references/merge-gate.md` receives the complete shared block currently beginning at
`### The merge gate`, retitled as a standalone reference without changing its normative
content. Each consumer replaces only that copied block with a direct relative link and an
instruction to apply the referenced gate at the same point in its workflow.

The surrounding skill-specific text remains local: campaign orchestration, quest handoff,
return-to-town authorization and cleanup, and restock PR-only behavior do not move. The
reference itself retains the issue-backed scope and restock exception so a consumer cannot
mistake the common gate for the separate dependency-PR path.

## Alternatives

- Keep the copies: best locality, but preserves the undetectable drift issue.
- Generate copies: preserves locality but adds generated artifacts and a generation step.
- One reference: smallest surface and reuses the repository's checked link convention.

## File responsibilities

- `references/merge-gate.md`: sole normative copy of the four-part gate.
- `skills/campaign/SKILL.md`: links the gate from campaign's merge step.
- `skills/quest/SKILL.md`: links the gate from quest's merge-handoff step.
- `skills/return-to-town/SKILL.md`: links the gate from the authorized merge path.
- `.claude-plugin/plugin.json`: minor version bump because a reference is added and three
  skill contracts gain centralized merge-gate guidance.

## Failure handling and verification

A missing reference is rejected by `just shape-check`. Review verifies that extraction is
byte-faithful in normative meaning, that no second operational gate remains in the reference
or its three skill consumers, and that each link appears at the former execution point.
Historical ADRs and design records explain decisions but are not executable workflow copies.
`just verify` supplies the full repository proof.
No test compares prose, as required by anatomy rule 4.

## Scope and constraints

- Preserve ADR 0035's behavior, commands, failure taxonomy, issue-backed scope, and restock
  exception.
- Do not change other workflow contracts or add executable machinery.
- Supported targets remain x86_64 and arm64; shell examples retain the repository's Bash
  3.2-compatible conventions.
- Base branch: `main`. Guardrails: `just shape-check` focused; `just verify` full.

## Acceptance criteria

1. The complete operational four-part gate exists in exactly `references/merge-gate.md`;
   `campaign`, `quest`, and `return-to-town` contain links rather than copies. Historical
   ADRs and design records are outside this operational uniqueness inventory.
2. All three named skills link it at their existing gate boundary.
3. `just shape-check` and `just verify` pass without a prose assertion.
4. The plugin version is bumped according to ADR 0022.
