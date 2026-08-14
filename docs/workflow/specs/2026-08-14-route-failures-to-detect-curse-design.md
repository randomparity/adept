# Route unexplained pipeline failures to detect-curse

Issue: #41

## Goal

Make `$detect-curse` reachable from the three pipeline failure entry points that currently direct
an operator to inspect or fix a failure without first establishing its cause.

## Scope and authority

The frozen scope is issue #41 annotation token `quest-41-20260814-8b03929f`. Issue #41 supplies
the outcome, the three entry points, and the exception for trivially understood failures. There
are no unresolved ambiguities.

Permitted surface is `skills/forge/SKILL.md`, `skills/deliver/SKILL.md`,
`skills/quest/SKILL.md`, and directly necessary structural verification. Changes to
`$detect-curse`, new skills or scripts, dependencies, compatibility paths, and generalized failure
classification are excluded.

## Design

Each existing failure-handling site gains the same boundary: when the cause is already understood,
the workflow follows its current direct action; when the cause is not understood, it invokes
`$detect-curse` before proposing or applying a fix. The diagnostic result supplies the evidence for
the existing recovery path; it does not weaken any stop condition or independently authorize a
change.

The three integrations remain local because their surrounding control flow differs:

- `$forge` routes an unexplained failing baseline through `$detect-curse` before asking whether to
  proceed, and routes a test or verification that resists the planned fix before treating it as an
  unresolved blocker.
- `$deliver` routes an unexplained required-check failure through `$detect-curse` before fixing,
  locally verifying, and pushing the correction.
- `$quest` states the pipeline-wide invariant: a red guardrail with an unexplained cause routes to
  `$detect-curse`; an understood failure is fixed directly, and the workflow never advances while
  the guardrail remains red.

No shared phrase or new decision table is introduced. Three call sites are below the repository's
threshold for abstraction, and keeping the rule beside each distinct recovery path makes its
continuation explicit.

## Failure cases and verification

- A trivially understood lint, format, or configuration failure keeps the existing direct-fix path.
- An unexplained failure cannot be labelled obvious merely because a speculative fix is available;
  `$detect-curse` establishes the cause first.
- An investigation that does not establish a cause leaves the existing stop or blocker behavior in
  force; the invocation is not permission to proceed through red.
- Repeated test or CI failure after an attempted correction re-enters diagnosis rather than retrying
  for green.
- Every added `$detect-curse` invocation resolves to the installed skill under `skills/` through
  `just shape-check`; `just verify` remains the full local and CI guardrail.

Repository anatomy rule 4 forbids a test that asserts Markdown contains prescribed sentences.
Contract correctness is therefore established by reading and adversarial review, while the
existing structural gate proves that the referenced skill exists and resolves.

## AI-SPEC and evaluation plan

The user is a pipeline operator. The trigger is an unexplained red baseline, resistant task test or
verification, red repository guardrail, or failed required CI check. Inputs are the failure output,
the attempted operation, repository state, and applicable workflow instructions. Output is a
`$detect-curse` investigation whose verified cause feeds the existing recovery path. Allowed
sources are the failure artifact, repository and tracker evidence, and operator answers. The
workflow must not guess a cause, treat a retry as evidence, weaken a stop condition, or invoke the
full investigation for a cause already established by direct evidence. If diagnosis cannot
establish a cause, the existing blocker behavior applies. No new model call, latency budget, or
token budget is introduced; success is a verified causal explanation followed by the existing
green guardrail requirement.

| Case | Gate | Observable result |
|---|---|---|
| `DCF-1` obvious lint error | review | Direct fix remains permitted; no mandatory investigation. |
| `DCF-2` unexplained red baseline | review | Forge invokes `$detect-curse` before a proceed decision. |
| `DCF-3` resistant task failure | review | Forge diagnoses before declaring or bypassing the blocker. |
| `DCF-4` unexplained required CI failure | review | Deliver diagnoses before fixing and pushing. |
| `DCF-5` unexplained red guardrail | review | Quest diagnoses and remains stopped until green. |
| `DCF-6` unresolved diagnosis | review | Existing stop behavior remains active; no speculative fix. |
| `DCF-7` skill reference resolution | block | `just shape-check` exits 0. |

The tool-using-agent dimensions are tool-use correctness, task completion, loop avoidance, and
instruction following. Incorrect bypass of diagnosis or advancement through red is severity 4 and
is covered by `DCF-2` through `DCF-6`. Deterministic structural checks cover reference resolution;
human and adversarial reading cover normative prose because automated prose assertions are banned.
