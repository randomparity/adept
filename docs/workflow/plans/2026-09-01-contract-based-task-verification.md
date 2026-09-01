# Contract-based task verification implementation plan

Goal: Let forge omit task-specific tests only when no meaningful executable or structural
contract exists, while preserving guardrails and whole-branch review.

Architecture: Spellcraft records one verification mode per material changed contract; forge
validates and routes those modes; the existing task brief carries them unchanged to the
implementer. The task report and forge ledger preserve the chosen evidence. No new helper or
dependency is introduced.

Tech stack: Markdown workflow instructions and JSON plugin manifest.
Expected implementation size: 125–215 changed lines (M) — summed from the per-file allocations in
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

- Modify `skills/spellcraft/SKILL.md` (25–45 lines): require a material-contract inventory and
  define each contract's verification decision.
- Modify `skills/forge/SKILL.md` (75–125 lines): validate and route per-contract modes across
  entry, Cast, Party, closure, final inventory reconciliation, evaluation, dispatch, ledger,
  prohibitions, TDD, and durability sections.
- Modify `skills/forge/implementer-prompt.md` (20–35 lines): execute and report each contract's
  selected evidence and reconcile the completed diff.
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
- Both modes reconcile the actual completed diff one-to-one against the planned inventory before
  closure; unmatched or reclassified contracts return to the plan checkpoint.
- A private manual-evaluation matrix records EVAL-01 through EVAL-05 and the two-pass cap.

Verification:

- Contract: Spellcraft plan authoring.
  - Mode: `task-test-not-applicable`.
  - Changed surface: normative instructions for producing and validating a task's contract
    inventory.
  - Reason: no executable plan parser consumes these instructions; a focused task test could only
    pin wording rather than prove the judgment.
- Contract: Forge verification routing and task closure.
  - Mode: `task-test-not-applicable`.
  - Changed surface: normative Cast/Party routing, validation, closure, prohibition, and TDD
    instructions.
  - Reason: Forge is an instruction surface rather than executable orchestration code; a focused
    task test could only search or snapshot its prose.
  - Additional evidence: the specification's bounded EVAL-01 through EVAL-05 behavior matrix.
- Contract: Party implementer-report evidence.
  - Mode: `task-test-not-applicable`.
  - Changed surface: Forge dispatch requirements and the implementer prompt's free-form private
    report contract.
  - Reason: no executable report parser validates the Markdown report; a focused task test would
    pin wording without proving that a future implementer exercises judgment correctly.
- Contract: Cast ledger evidence.
  - Mode: `task-test-not-applicable`.
  - Changed surface: human-readable private evidence-line vocabulary and read-back instructions.
  - Reason: no executable consumer parses these lines; a focused task test would assert prose or
    reproduce a parser this change explicitly does not add.
- Contract: README public build description.
  - Mode: `task-test-not-applicable`.
  - Changed surface: explanatory prose describing the installed workflow.
  - Reason: README wording is not a machine contract, and repository policy forbids a gate that
    asserts it.
- Contract: changed plugin trees increment the manifest version above the base version.
  - Mode: `focused-test`.
  - Red command: `BASE_SHA=$(git merge-base HEAD main) just version-check` before the manifest
    bump; expect exit 1 with `the tree differs from <base-sha> but the version did not increase:
    4.0.0 at the base ref, 4.0.0 here`.
  - Green command: the same command after the manifest bump; expect exit 0.

Steps:

1. Run `BASE_SHA=$(git merge-base HEAD main) just version-check`; expect the red result named in
   Verification because the changed tree still declares `4.0.0`.
2. Update Spellcraft's task-authoring rules to require a per-contract `Verification` inventory,
   define the evidence for each mode, require focused evidence to cover its named contract, and
   reject categorical or vague non-applicability reasons.
3. Update Forge's entry contract, Cast and Party execution, per-task closure, final diff inventory,
   bounded evaluation, dispatch content, the specification's exact Party summary and Cast evidence
   lines, prohibitions, TDD, and durability sections without adding a resume parser.
4. Update the implementer template to follow each selected mode, reject contradictions, report
   evidence per contract, and reconcile its completed diff against the inventory.
5. Update README's build description and skill table to describe meaningful focused tests or a
   recorded non-applicability reason, with guardrails always required.
6. Bump `.claude-plugin/plugin.json` from `4.0.0` to `4.0.1`.
7. Run the same base-aware version command; expect exit 0.
8. Inventory the actual task diff and reconcile it one-to-one with the six Verification entries;
   expect no unmatched or reclassified material contract.
9. Run EVAL-01 through EVAL-05 with one fresh evaluator and write the private pass/fail matrix;
   expect all rows to pass with no forbidden trait. After an evidence-backed correction, allow one
   confirming evaluation; a second failure parks.
10. Run `just verify`; expect every repository gate to pass with zero warnings.
11. Review the diff against the specification's six acceptance checks and correct any missing
    route or stale universal-TDD claim in the changed surfaces.
12. Commit as `feat(forge): require evidence-based task verification`.

Acceptance:

- Each plan task carries one reviewable mode for every material changed contract before
  implementation; mixed tasks may carry both modes.
- Forge rejects unsupported omissions and does not invent prose-only tests.
- Testable structural and behavioral contracts still use red-green TDD.
- Reports and ledger entries identify the evidence actually used.
- The actual diff reconciles one-to-one with the planned material-contract inventory.
- EVAL-01 through EVAL-05 pass within the two-pass evaluation cap.
- Repository guardrails and whole-branch review remain unconditional.

## Rollback

Create a rollback PR that restores the previous workflow and README text, increments the plugin
version above the current release, and adds an ADR superseding 0054 and restoring the prior
decision. Preserve the merged ADR, specification, and plan as history, and run `just verify`.
