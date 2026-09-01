# Contract-based task verification design

Issue: #298
Decision: [ADR 0054](../../adr/0054-task-tests-follow-observable-contracts.md)

## Scope

Change `$forge` from universal task-level TDD to evidence-based choices over each task's material
changed contracts. A contract gets a focused red-green test when it changes executable behavior
or machine-checkable structure. Otherwise it carries a concrete non-applicability reason.
Repository guardrails and the whole-branch review remain mandatory.

This change does not create categorical exemptions, weaken an existing test gate, alter forge's
whole-branch review result contract, or automate assertions over prose.

## Verification decision

`$spellcraft` adds a `Verification` block to every implementation-plan task before its steps. The
block inventories every material changed contract; each entry uses one mode:

- `Mode: focused-test` names the observable contract, the test file or case, the expected red
  failure, and the focused green command.
- `Mode: task-test-not-applicable` names the changed surface and explains why no task-specific
  executable or structural observation could fail meaningfully.

Focused evidence must cover the contract named by its entry. It cannot stand in for another
material changed contract in the same task. The second mode is invalid when its reason is only a
file type, task size, convenience, or the
existence of repository guardrails. It is also invalid for a new or changed script behavior,
parser, schema, record shape, validation rule, generated artifact, or other machine-checkable
contract. A test that only searches for or snapshots prose wording is not meaningful evidence.

`$forge` validates the block against the task before implementation. A missing, vague, or
contradictory mode is a plan defect, not a choice the implementer silently repairs. Build-time
discovery of a testable contract returns to the caller's scope or plan checkpoint.

## Build behavior

Cast mode makes the same per-contract decisions directly when it has no planned task. Focused-test
work follows the existing red-green sequence. Non-applicable work starts with the implementation
and remains subject to the applicable repository guardrails.

Party mode passes the plan's contract inventory and evidence through the task brief. The existing
private implementer report contains one entry per contract, each with either:

- the red command, expected failure, green command, and passing result; or
- the exact non-applicability reason from the plan, confirmed against the implemented diff.

The orchestrator closes a task only after verifying its commits, every report entry, and every
required guardrail result. It appends one exact completion line, using `mixed` when the report
contains both entry modes:

```text
Task N: complete (commits <base-sha>..<head-sha>, verification <focused-test|task-test-not-applicable|mixed>)
```

Before appending the line, forge requires the focused-test entries to contain the red command and
expected failure plus the green command and passing result. Each non-applicable entry must repeat
the plan's exact reason and confirm that its implemented contract remained non-executable and
non-structural. A missing, contradicted, or incomplete entry does not close the task. On resume,
the completed progress-ledger line remains authoritative under forge's existing contract; no task
report is re-parsed.

Cast has no implementer report. Before returning its existing forge result, it appends and reads
back one single-line private ledger entry per material contract:

```text
Cast verification: <contract> = focused-test (red <command-and-result>; green <command-and-result>)
Cast verification: <contract> = task-test-not-applicable (reason <reason>)
```

Commands, results, contract names, and reasons must be non-empty single-line text. Cast rejects
carriage return or NUL rather than inventing escaping. Its existing result record remains the
phase boundary; the new evidence lines explain the verification judgment without changing resume
routing.

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

The implementation changes instruction and documentation contracts and also increments the
machine-checkable plugin version. Use the existing base-aware version gate as the task's focused
red-green test: before the bump it must reject a changed tree whose version still equals the base;
after the bump it must pass. Do not add a test that asserts exact Markdown wording. Run
`just verify` bare for the repository's structural, shell, manifest, record, and plugin checks.
Review the finished branch adversarially through forge and quest as already required.

Acceptance checks:

1. A future prose-only contract can select `task-test-not-applicable` with a contract-based reason.
2. A future structural Markdown or functional script task is still required to select
   `focused-test`.
3. Forge rejects a missing, categorical, or diff-contradicted non-applicability reason.
4. Party reports and Cast ledger evidence preserve which verification mode ran for every material
   changed contract.
5. Repository guardrails and whole-branch review remain unconditional.

## Rollback

Create a rollback PR that restores the previous workflow instructions and README wording, bumps
the plugin version above the currently published version, and adds a new ADR superseding 0054 and
restoring the prior decision. Keep this specification, plan, and ADR 0054 as historical records;
do not delete or rewrite them. Run `just verify`. No persisted or external data migration is
required.
