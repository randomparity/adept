# Contract-based task verification implementation plan

Goal: Let forge omit task-specific tests only when no meaningful executable or structural
contract exists, while preserving guardrails and whole-branch review.

Architecture: Spellcraft records one verification mode per material changed contract; forge
validates and routes those modes; the existing task brief carries them unchanged to the
implementer. The task report and forge ledger preserve the chosen evidence. No new helper or
dependency is introduced.

Tech stack: Markdown workflow instructions and JSON plugin manifest.
Expected implementation size: 95–160 changed lines (M) — summed from the per-file allocations in
the file map below.

## Global Constraints

- Bash 3.2 remains the shell floor; this change adds no executable shell.
- No automated gate may assert prose wording.
- A task-specific test is required for executable behavior or a machine-checkable structural
  contract, regardless of file type or task size.
- A non-applicability reason removes only the focused task test; `just verify` and the
  whole-branch review remain mandatory.
- Every repository change bumps `.claude-plugin/plugin.json`; this contract-only change is a
  patch bump.
- Base branch: `main`.
- Guardrail command: `just verify`.

## File map

- Modify `skills/spellcraft/SKILL.md` (20–35 lines): require a material-contract inventory and
  define each contract's verification decision.
- Modify `skills/forge/SKILL.md` (55–90 lines): validate and route per-contract modes across entry,
  Cast, Party, closure, dispatch, ledger, prohibitions, TDD, and durability sections.
- Modify `skills/forge/implementer-prompt.md` (15–25 lines): execute and report each contract's
  selected evidence.
- Modify `README.md` (4–8 lines): describe contract-based verification publicly.
- Modify `.claude-plugin/plugin.json` (1–2 lines): bump the patch version.

## Task 1 — Route task verification by observable contract

Files:

- Modify `skills/spellcraft/SKILL.md`.
- Modify `skills/forge/SKILL.md`.
- Modify `skills/forge/implementer-prompt.md`.
- Modify `README.md`.
- Modify `.claude-plugin/plugin.json`.

Interfaces:

- A plan task exposes a `Verification` inventory with one `Mode: focused-test` or
  `Mode: task-test-not-applicable` entry for every material changed contract.
- `task-brief` carries the block unchanged because it already copies the whole task section.
- A Party implementer report returns each contract's red-green evidence or exact
  non-applicability reason.
- Party progress uses the specification's exact summary line after validating the report once;
  Cast appends and reads back the specification's exact per-contract evidence lines.

Verification:

- Contract: Forge, Spellcraft, implementer-template, and README instruction behavior.
  - Mode: `task-test-not-applicable`.
  - Changed surface: normative workflow and public explanatory prose.
  - Reason: these edits add no executable behavior or machine-checkable structural contract; a
    focused task test could only pin wording. Existing structural guardrails and the required
    design, branch, and forge reviews still run but do not substitute for this reason.
- Contract: changed plugin trees increment the manifest version above the base version.
  - Mode: `focused-test`.
  - Red command: `BASE_SHA=$(git merge-base HEAD main) just version-check` before the manifest
    bump; expect exit 1 with `the tree differs from <base-sha> but the version did not increase:
    4.0.0 at the base ref, 4.0.0 here`.
  - Green command: the same command after the manifest bump; expect exit 0.

Steps:

1. Update Spellcraft's task-authoring rules to require a per-contract `Verification` inventory,
   define the evidence for each mode, require focused evidence to cover its named contract, and
   reject categorical or vague non-applicability reasons.
2. Update Forge's entry contract, Cast and Party execution, per-task closure, dispatch content,
   the specification's exact Party summary and Cast evidence lines, prohibitions, TDD, and
   durability sections so it validates and preserves every contract's selected mode without a
   new resume parser.
3. Update the implementer template to follow each selected mode, reject contradictions, and
   report red-green evidence or the exact confirmed non-applicability reason per contract.
4. Update README's build description and skill table to describe meaningful focused tests or a
   recorded non-applicability reason, with guardrails always required.
5. Run `BASE_SHA=$(git merge-base HEAD main) just version-check`; expect the red result named in
   Verification because the changed tree still declares `4.0.0`.
6. Bump `.claude-plugin/plugin.json` from `4.0.0` to `4.0.1`.
7. Run the same base-aware version command; expect exit 0.
8. Run `just verify`; expect every repository gate to pass with zero warnings.
9. Review the diff against the five acceptance checks in the specification and correct any
   missing route or stale universal-TDD claim in the changed surfaces.
10. Commit as `feat(forge): require evidence-based task verification`.

Acceptance:

- Each plan task carries one reviewable verification mode before implementation.
- Forge rejects unsupported omissions and does not invent prose-only tests.
- Testable structural and behavioral contracts still use red-green TDD.
- Reports and ledger entries identify the evidence actually used.
- Repository guardrails and whole-branch review remain unconditional.

## Rollback

Create a rollback PR that restores the previous workflow and README text, increments the plugin
version above the current release, and adds an ADR superseding 0054 and restoring the prior
decision. Preserve the merged ADR, specification, and plan as history, and run `just verify`.
