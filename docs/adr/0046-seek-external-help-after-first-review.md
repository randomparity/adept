# 0046 — Seek external help after the first review

## Status

Accepted (2026-08-28)

## Context

An adversarial review can expand around hypothetical edge cases when its target depends on
platform conventions or established practices that neither the target nor repository evidence
settles. Issue #276 records a Windows installer design that exhausted its review budget before a
web search exposed a mature, much smaller pattern.

## Decision

After reading the first review result, `$trial-loop` performs an external-help checkpoint before
dispositioning `needs-attention` findings. When the result is drifting into speculative or
disproportionate work, or depends on an unresolved external practice, the orchestrator searches
the web for focused prior art using only public-safe terms. It records the sources and what they
establish, then applies them as evidence through the existing finding-disposition rules.

External material cannot expand the charter or supply user authority. If the remaining need is a
design decision or authorization, an interactive run asks the operator one focused question and
an unattended run uses its existing park path. Later iterations may repeat the checkpoint when a
new external question appears, but the first eligible check cannot occur later than the end of
iteration one.

An unavailable or inconclusive search is recorded as such and supplies no evidence. The loop then
continues through ordinary finding disposition; it asks or parks only when the unresolved finding
itself requires authority.

## Consequences

The loop can cut speculative review surface before spending its iteration budget. Searches remain
conditional, narrow, and public-safe. The loop gains no new exit, budget, or disposition, and a
source result is still a hypothesis that must fit the frozen charter and repository evidence.

## Considered & rejected

- **Search before every first review.** judgment: unconditional network work adds cost and noise
  when the reviewer finds no external-practice uncertainty or disproportionate expansion.
- **Wait until the iteration budget is exhausted.** verified: randomparity/bzr issue #566 records
  that review had already reached its five-pass plan-review budget before web research simplified
  the Windows PATH design.
- **Ask the operator instead of researching established practice.** judgment: it transfers a
  discoverable evidence task to the operator and still leaves the loop without prior art.
