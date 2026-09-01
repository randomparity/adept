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

`$spellcraft` records the inventory and evidence. `$forge` checks it before work and reconciles it
against the completed diff before closure; an unmatched or reclassified contract returns to the
plan checkpoint. Party keeps detailed evidence in its existing report, while Cast records it in
its existing private ledger. This adds no evidence-envelope parser or resume protocol.

Because Forge is an agent instruction surface, a bounded behavior evaluation also exercises the
routing decision over representative prose, structural, script, mixed, and invalid-reason cases.

Repository guardrails remain mandatory at every commit and over the assembled branch. The
whole-branch review remains mandatory. A non-applicability reason removes only a task-specific
test; it removes neither executable repository checks nor adversarial review.

## Consequences

Prose-only tasks can complete without tests that duplicate their wording. Their correctness is
judged through the explicit non-applicability reason, applicable repository guardrails, and the
branch review, with the absence of a focused test visible rather than omitted.

This deliberately narrows ADR 0052's task-specific executable-evidence gate for contracts with no
meaningful executable or structural observation. Those contracts lose direct executable
assurance; the accepted trade is explicit judgment plus unchanged repository guardrails and
whole-branch review. Testable contracts remain under ADR 0052's executable gate.

Plans, reports, and ledger lines gain small verification fields. Orchestrators and reviewers must
judge the inventory and reasons, so two agents can disagree; the final diff reconciliation and
behavior evaluation make that disagreement observable.

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
