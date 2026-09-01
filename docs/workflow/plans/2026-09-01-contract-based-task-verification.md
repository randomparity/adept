# Contract-based task verification implementation plan

Goal: Let forge omit task-specific tests only when no meaningful executable or structural
contract exists, while preserving guardrails and whole-branch review.

Architecture: Spellcraft records one verification mode per task; forge validates and routes that
mode; the existing task brief carries it unchanged to the implementer. The task report and forge
ledger preserve the chosen evidence. No new helper or dependency is introduced.

Tech stack: Markdown workflow instructions and JSON plugin manifest.
Expected implementation size: 75–115 changed lines (M) — derived from five focused instruction,
documentation, and manifest edits in the file map below.

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

- Modify `skills/spellcraft/SKILL.md`: require and define each task's verification decision.
- Modify `skills/forge/SKILL.md`: validate, route, close, and ledger the two verification modes.
- Modify `skills/forge/implementer-prompt.md`: execute and report the selected evidence.
- Modify `README.md`: describe contract-based verification publicly.
- Modify `.claude-plugin/plugin.json`: bump the patch version.

## Task 1 — Route task verification by observable contract

Files:

- Modify `skills/spellcraft/SKILL.md`.
- Modify `skills/forge/SKILL.md`.
- Modify `skills/forge/implementer-prompt.md`.
- Modify `README.md`.
- Modify `.claude-plugin/plugin.json`.

Interfaces:

- A plan task exposes `Verification` with `Mode: focused-test` or
  `Mode: task-test-not-applicable` and the evidence defined in the specification.
- `task-brief` carries the block unchanged because it already copies the whole task section.
- An implementer report returns red-green evidence or the exact non-applicability reason.
- A forge progress entry uses one exact line from the specification, names the private report,
  and is trusted on resume only after that report's evidence is revalidated.

Verification:

- Mode: `focused-test`.
- Observable contract: a changed plugin tree must increment the manifest version above the base
  version.
- Red command: `BASE_SHA=$(git merge-base HEAD main) just version-check` before the manifest
  bump; expect exit 1 with `the tree differs from <base-sha> but the version did not increase:
  4.0.0 at the base ref, 4.0.0 here`.
- Green command: the same command after the manifest bump; expect exit 0.
- The focused test covers only the machine-checkable version contract. Do not add a test that
  asserts the changed Markdown wording.

Steps:

1. Update Spellcraft's task-authoring rules to require the two-mode `Verification` block, define
   the evidence for each mode, and reject categorical or vague non-applicability reasons.
2. Update Forge's entry contract, Cast and Party execution, per-task closure, dispatch content,
   the specification's exact ledger lines and resume validation, prohibitions, and TDD section so
   it validates and preserves the selected mode.
3. Update the implementer template to follow the selected mode, reject contradictions, and report
   red-green evidence or the exact confirmed non-applicability reason.
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

Revert the implementation commit. Do not retain README or manifest claims that the installed forge
contract does not implement.
