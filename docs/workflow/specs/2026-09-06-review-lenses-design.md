# Named review lenses — issue #320

Issue #320 and epic #316 authorize named focus presets on the existing reviewer channel. They do
not authorize another reviewer, another executable, or a change to the review budget.

## Problem and scope

Repeated review with the same reading technique missed an installed-consumer failure that a new
perspective found. `$quest` and `$spellcraft` each send one fixed focus today, while `$trial-loop`
does not distinguish an independent second reading from its confirming iteration.

Add `references/review-lenses.md` as the sole catalog of lens names, focus text, and suitable
target shapes. Callers select the first lens from the target's shape and append target-specific
context. Reviewer selection remains the existing `gauntlet | detect-evil` contract: broad
adversarial reviews keep `gauntlet`, security reviews keep `detect-evil`, and focus text never
reroutes one into the other.

A new independent review of unchanged target bytes uses a different lens. A `$trial-loop` run is
one review technique, so every iteration—including the confirming pass over fixes—keeps the lens
selected before iteration 1. The existing single-pass escalation still enters `$trial-loop`; when
the target is unchanged, that new run selects a different lens. Issue #323 owns any later
design-review carve-out and is not implemented here.

## Acceptance scenarios

1. A packaged-skill diff starts with `consumer-installation`; a structured annotation change
   starts with `downstream-reader`; a workflow-resume change starts with `operator-cold-resume`.
2. A target matching no more specific shape uses `failure-injection`.
3. `$quest` and `$spellcraft` add the selected focus without losing their target-specific review
   context.
4. A blocking single pass escalates on unchanged bytes with a different lens.
5. Iteration 2 of `$trial-loop` retains iteration 1's lens after fixes.
6. A security pass uses `detect-evil` with the `security` lens; naming that lens never sends the
   default `gauntlet` reviewer to perform the security route.
7. The accepted `--reviewer gauntlet|detect-evil` grammar and review budgets are unchanged.

## Verification and non-goals

These are instruction artifacts. Anatomy rule 4 forbids tests that pin their prose, so acceptance
is checked by reading each caller path against the scenarios and by the existing structural and
plugin guardrails. No helper, reviewer skill, unit test, ADR, or committed implementation plan is
added. This issue does not implement #319's finding fields or #323's one-pass design-review rule.
