# 0065 — One final full local verification owner

## Status

Accepted (2026-09-14)

Amends [0052](0052-tests-gate-a-task-the-branch-gets-one-review.md) decision 3
and [0054](0054-task-tests-follow-observable-contracts.md)'s assembled-branch
guardrail mandate. The assembled branch still receives an executable check
before review, but that check need not be the full suite when its integration
impact is bounded.

## Context

Forge's full assembled-branch suite ran before review edits and simplification.
Deliver then required another full run before the first push. A mandatory
pre-push hook could run the same suite a third time on the pushed commit. Early
results could become inapplicable before shipping, while the final hook still
provided the required full local coverage.

## Decision

After all tasks, Forge checks the assembled branch across changed callers,
shared boundaries, and generated artifacts before whole-branch review. It runs
the full suite at that point only when impact cannot be bounded or repository
policy requires it. Task checks alone do not replace this integration check.

Attunement records iteration, integration, full local, hook, and CI coverage,
cost, and prerequisites, and names the owner of final full local verification.
After review fixes and simplification, Deliver uses a mandatory full pre-push
hook as that owner when it blocks failure and tests the exact pushed object.
Without such a hook, Deliver uses applicable successful full evidence or runs
the suite on the final candidate before pushing. A changed candidate, base, or
environment requires applicability reassessment under true-seeing; a workflow
phase change alone does not. Pending or failed checks supply no passing evidence.
Required repository and CI gates remain in force. Report every actual full
local run, its reason, and the observed total duration, leaving unknown cost
unknown.

## Consequences

The ordinary path gets one full local run on the final pushed candidate, plus
required CI. A broad assembled-branch impact or an explicit repository rule
can require another full run, with its reason visible. No hook, cache, or
verification stamp is added.

## Considered & rejected

- **Keep every phase's full suite.** Repeating equivalent coverage spends time
  without adding evidence for the final candidate.
- **Skip assembled-branch execution.** Task tests cannot expose every
  cross-task interaction before the whole-branch review.
- **Disable the hook after a manual pass.** A hook checks the pushed object and
  is a repository requirement, not an optional repeat.
