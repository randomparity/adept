# Contract-based task verification design

Issue: #298
Decision: [ADR 0054](../../adr/0054-task-tests-follow-observable-contracts.md)

## Scope

Change `$forge` from universal task-level TDD to an evidence-based choice per task. A task gets a
focused red-green test when it changes executable behavior or a machine-checkable structural
contract. Otherwise it carries a concrete non-applicability reason. Repository guardrails and
the whole-branch review remain mandatory.

This change does not create categorical exemptions, weaken an existing test gate, alter forge's
whole-branch review result contract, or automate assertions over prose.

## Verification decision

`$spellcraft` adds a `Verification` block to every implementation-plan task before its steps:

- `Mode: focused-test` names the observable contract, the test file or case, the expected red
  failure, and the focused green command.
- `Mode: task-test-not-applicable` names the changed surface and explains why no task-specific
  executable or structural observation could fail meaningfully.

The second mode is invalid when its reason is only a file type, task size, convenience, or the
existence of repository guardrails. It is also invalid for a new or changed script behavior,
parser, schema, record shape, validation rule, generated artifact, or other machine-checkable
contract. A test that only searches for or snapshots prose wording is not meaningful evidence.

`$forge` validates the block against the task before implementation. A missing, vague, or
contradictory mode is a plan defect, not a choice the implementer silently repairs. Build-time
discovery of a testable contract returns to the caller's scope or plan checkpoint.

## Build behavior

Cast mode makes the same decision directly when it has no planned task. Focused-test work follows
the existing red-green sequence. Non-applicable work starts with the implementation and proves it
through the applicable repository guardrails.

Party mode passes the plan's decision and evidence through the task brief. The implementer report
contains either:

- the red command, expected failure, green command, and passing result; or
- the exact non-applicability reason from the plan, confirmed against the implemented diff.

The orchestrator closes a task only after verifying its commits, that report evidence, and every
required guardrail result. Ledger entries distinguish `focused-test` from
`task-test-not-applicable`; they no longer claim that every completed task has green focused
tests.

The assembled-branch guardrail run and whole-branch reviewer are unchanged. They remain the proof
that tasks compose and the adversarial check on prose and judgment calls.

## Changed surfaces

- `skills/spellcraft/SKILL.md` defines the task verification block and plan-quality checks.
- `skills/forge/SKILL.md` validates and routes the two modes in Cast and Party, updates task
  closure and ledger wording, and narrows its TDD rules to applicable tasks.
- `skills/forge/implementer-prompt.md` reports the selected evidence without inventing tests.
- `README.md` describes the public build behavior without promising universal TDD.
- `.claude-plugin/plugin.json` receives the required patch version bump.

No executable helper or data format changes. Existing task briefs already copy a task section
verbatim, so the verification block needs no parser change.

## Failure handling

- Missing verification mode: stop before implementation and repair the plan.
- Non-applicability reason contradicted by the task or discovered diff: stop and return to the
  caller; do not proceed testless.
- Focused test that cannot produce the expected red: investigate the test or design before
  implementation.
- Guardrail failure: retain the existing forge stop-and-diagnose behavior.
- Implementer report missing its selected evidence: return `NEEDS_CONTEXT` and do not close the
  task.

## Verification strategy

The implementation changes instruction and documentation contracts only. It introduces no
machine-checkable runtime or structural contract, so no task-specific regression test applies:
asserting exact Markdown wording would recreate the defect this issue removes. Run `just verify`
bare for the repository's structural, shell, manifest, record, and plugin checks. Review the
finished branch adversarially through forge and quest as already required.

Acceptance checks:

1. A future prose-only plan can select `task-test-not-applicable` with a contract-based reason.
2. A future structural Markdown or functional script task is still required to select
   `focused-test`.
3. Forge rejects a missing, categorical, or diff-contradicted non-applicability reason.
4. Implementer and orchestrator reports preserve which verification mode actually ran.
5. Repository guardrails and whole-branch review remain unconditional.

## Rollback

Revert the instruction, documentation, ADR, and manifest changes together. No persisted or
external data migration is required.
