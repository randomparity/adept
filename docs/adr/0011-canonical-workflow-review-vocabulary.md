# 0011 — Canonical workflow review vocabulary

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

Oathbind's scope classifications stay orthogonal to severity: each defensible concern also
receives an impact-based canonical severity; `unsupported` is rejection evidence rather than
a finding. Restock converts `PASS` to `approve` and both `WARN` and `FAIL` to
`needs-attention`, preserving the local outcome to distinguish human judgment from failed
evidence. Its matrix assessment is coverage exposure, not a severity.

Reserve `blocked` for a workflow or issue that cannot proceed. Qualify narrower outcomes,
such as a refused dependency merge, instead of emitting bare `BLOCKED`. Name each risk axis:
`risk:*` labels are execution-risk policy, divination risk flags are change hazards, and
restock's matrix assessment is coverage exposure.

Forge's task and branch reviewers both require explicit model selection, use the canonical
severity and verdict enums, and rely on the implementer's first-run test evidence by default.
Either may run one focused check for a named unresolved concern, but neither reruns a broad
suite merely to duplicate evidence. A retry remains nondeterminism evidence. Forge routes
`critical`, `high`, and `medium` findings to fixes and carries `low` findings to final triage.
The orchestrator selects models through forge's `Choosing a model` rubric: task reviewers have
a mid-tier floor and scale with task complexity; the final whole-branch reviewer uses the most
capable available model. Both templates carry a required explicit model field.

This record supersedes only ADR 0007's decisions to preserve the whole-branch review's
`Critical / Important / Minor` grades and `Yes | No | With fixes` verdict. ADR 0007 continues
to govern the packaged diff, file-backed review, bounded return, failure values, verification,
and conditional reads.

Review artifacts use caller-supplied, run-unique paths. The worker may create or overwrite
only its assigned artifact and must not dispose of it. The orchestrator clears that path
before dispatch and disposes of the artifact after consumption. Each party removes only the
temporary worktrees it created; a worker reports a cleanup failure before returning.

## Consequences

Forge's two reviewer prompts and its routing logic move to four severities and one verdict,
so findings pass into trial-loop and quest without lossy conversion. Existing domain-specific
restock and oathbind classifications remain expressive, but their relationship to shared
review vocabulary becomes explicit. Skill prose changes across several directories because
the vocabulary is a composed public contract rather than a local wording preference.

This decision does not rename GitHub `status:*`, `risk:*`, or `priority:*` labels and does not
change their semantics.

It creates a coordinated wording migration across composed skills and invalidates examples or
review artifacts that rely on the former enums. That churn is accepted because a partial
migration would preserve contradictory routing contracts; the branch and its behavioral
evaluation therefore move together.

## Considered & rejected

**Keep every local enum and add pairwise conversion tables.** Rejected because the number of
translations grows with every new consumer and round trips lose information.

**Adopt forge's three grades as canonical.** Rejected because it collapses gauntlet's distinct
medium and low failure impacts and would change more established command-pipeline contracts.

**Treat all vocabulary as local prose.** Rejected because these values drive routing, retry,
fix, and hand-off decisions across skills; contradictions already change behavior.

**Do nothing.** Rejected because forge can currently grade the same defect differently by
review stage, and downstream skills cannot interpret several domain outcomes without local
guesswork. Leaving that state preserves incorrect routing rather than mere editorial variety.

**Normalize only values that cross skill boundaries.** Rejected because forge's local routing,
model/test policy, and artifact lifecycle produce the values and evidence that cross those
boundaries. Standardizing only the handoff would hide contradictions behind a conversion table;
reconciling both reviewer producers is the smallest change that makes the shared values honest.
