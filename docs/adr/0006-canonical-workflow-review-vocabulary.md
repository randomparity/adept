# 0006 — Canonical workflow review vocabulary

## Status

Accepted (2026-08-13)

## Context

Adept composes review, build, dependency, and shipping skills by passing findings and
outcomes between them. Those contracts currently use incompatible severity and verdict
enums, call the dispatching role by four names, overload `BLOCKED`, and use `risk` for both
queue policy and analytical evidence. The forge task and branch reviewer prompts also
define different meanings for the same grades.

## Decision

Use `orchestrator` for the role that dispatches and owns workflow state, and `worker` for a
dispatched agent or process. More precise subtype names such as implementer, reviewer, and
evaluator remain valid.

Use gauntlet's `critical | high | medium | low` as the only cross-workflow finding severity
scale and `approve | needs-attention` as the cross-workflow review verdict. Domain outcomes
may retain different enums only when their contract includes an explicit, one-way conversion
to the canonical vocabulary and states that the domain value is not a finding severity or
review verdict.

Reserve `blocked` for a workflow or issue that cannot proceed. Qualify narrower outcomes,
such as a refused dependency merge, instead of emitting bare `BLOCKED`. Name each risk axis:
`risk:*` labels are execution-risk policy, divination risk flags are change hazards, and
restock's matrix assessment is coverage exposure.

Review artifacts use caller-supplied, run-unique paths. The caller owns pre-dispatch cleanup
and post-consumption disposal; a worker owns only files or temporary worktrees it creates and
must clean those worktrees before returning.

## Consequences

Forge's two reviewer prompts and its routing logic move to four severities and one verdict,
so findings pass into trial-loop and quest without lossy conversion. Existing domain-specific
restock and oathbind classifications remain expressive, but their relationship to shared
review vocabulary becomes explicit. Skill prose changes across several directories because
the vocabulary is a composed public contract rather than a local wording preference.

This decision does not rename GitHub `status:*`, `risk:*`, or `priority:*` labels and does not
change their semantics.

## Considered & rejected

**Keep every local enum and add pairwise conversion tables.** Rejected because the number of
translations grows with every new consumer and round trips lose information.

**Adopt forge's three grades as canonical.** Rejected because it collapses gauntlet's distinct
medium and low failure impacts and would change more established command-pipeline contracts.

**Treat all vocabulary as local prose.** Rejected because these values drive routing, retry,
fix, and hand-off decisions across skills; contradictions already change behavior.

