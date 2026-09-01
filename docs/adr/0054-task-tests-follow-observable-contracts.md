# 0054 — Task tests follow observable contracts

## Status

Accepted (2026-09-01)

Amends [0052](0052-tests-gate-a-task-the-branch-gets-one-review.md) decision 1: a task still
closes on verified commits, task evidence, and guardrails, but task evidence may be either a
focused executable test or a justified finding that no task-specific test applies.

## Context

`$forge` currently requires test-driven development throughout and rejects a task report that
names no executable test evidence. That is a useful default for executable behavior, but it also
pressures implementers to manufacture tests for prose-only changes. In this repository those
tests have included string searches over skill wording, despite the repository rule that no
automated gate asserts on prose.

File type does not decide whether a test is valuable. Markdown can define a machine-checkable
record shape, and a short shell script can carry error handling or destructive behavior. The
useful distinction is whether the task changes an observable executable or structural contract.

## Decision

Each planned task inventories its material changed contracts before implementation. Every
contract receives one of two verification modes, so a mixed task may carry both:

1. **Focused test required.** A task that creates or changes executable behavior or a
   machine-checkable structural contract follows red-green TDD. Its plan names the test, the
   expected red failure, and the focused green command.
2. **Task-specific test not applicable.** A task with no such contract records the changed
   surface and why no task-specific executable observation could fail meaningfully. It does not
   create a test that merely searches for, snapshots, or otherwise pins prose wording.

The decision is evidence-based, not categorical. Documentation, Markdown, configuration, and
small scripts receive focused tests whenever they change a machine-checkable contract or
executable behavior. A file category or small diff is never itself a reason to omit one.

Party implementers record each contract's selected mode and evidence in the existing private task
report; forge validates it when closing the task and records `focused-test`,
`task-test-not-applicable`, or `mixed` in the durable progress ledger. Cast has no implementer
report, so it appends and reads back one private ledger evidence line per contract. Resume trusts
completed ledger entries as forge already does; this decision adds no evidence-envelope parser or
revalidation protocol.

`$spellcraft` writes the mode and its evidence into every task. `$forge` checks that choice
against the task before work starts and returns an unsupported or vague choice to the scope or
plan checkpoint. The implementer reports either red-green evidence or the exact non-applicability
reason. The orchestrator verifies that report before closing the task.

Repository guardrails remain mandatory at every commit and over the assembled branch. The
whole-branch review remains mandatory. A non-applicability reason removes only a task-specific
test; it removes neither executable repository checks nor adversarial review.

## Consequences

Prose-only tasks can complete without tests that duplicate their wording. Their correctness is
established by applicable repository guardrails and the branch review, with the absence of a
focused test visible as an explicit judgment rather than an omitted field.

Plans, reports, and task-completion ledger lines gain small verification-mode fields.
Orchestrators and reviewers must judge the reason, so two agents can disagree; requiring the
changed contract and the missing observation to be named gives that disagreement concrete
evidence to inspect.

Existing structural and behavioral tests remain load-bearing. ADR status, numbering, manifest
shape, link resolution, and script behavior are still tested when a task changes those contracts.

## Considered & rejected

- **Skip tests for documentation and simple scripts.** judgment: file categories are a poor
  proxy for behavior. Markdown can encode structural contracts, while a small script can handle
  meaningful failure or safety paths.
- **Relax test-first ordering but require a test for every task.** verified: issue #298 reports
  tests invented as string searches over skill definitions; moving those tests after the edit
  preserves the defect while changing only its order.
- **Keep universal TDD and rely on reviewers to reject weak tests.** judgment: this spends
  implementation and review effort producing an artifact whose only acceptable disposition is
  deletion.
- **Do nothing.** verified: issue #298 records repeated overreach on prose and supporting-script
  work under the current universal mandate.
