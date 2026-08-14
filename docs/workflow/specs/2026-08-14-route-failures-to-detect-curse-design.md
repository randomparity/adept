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

Each existing failure-handling site gains the same boundary. Direct repair is allowed only when the
current failure artifact or an already-recorded investigation identifies a specific cause and the
proposed correction follows from that evidence. Familiarity, a plausible fix, or stale evidence
from a different failure is insufficient. Without current causal evidence, the workflow invokes
`$detect-curse` before proposing or applying a fix. The diagnostic result supplies evidence for the
existing recovery path; it does not weaken a stop condition or independently authorize a change.

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
- A red result after an attempted correction re-enters diagnosis only when the latest artifact
  leaves the cause unexplained. If the same evidence-backed cause and correction already failed and
  the new artifact supplies no new evidence, the relevant existing blocker or stop path applies
  instead of repeating a diagnose-fix loop.
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

Evaluation uses a bounded manual trace protocol because repository policy forbids automation that
asserts on skill prose. For each review-gated case, the reviewer receives the listed failure
artifact and prior evidence, simulates the next workflow actions, and records the ordered
invocations, proposed corrections, and advance/stop decision. A case passes only when that trace
matches every observable result below; otherwise the contract is revised before shipping.

| Case and input | Prior evidence | Gate | Observable result |
|---|---|---|---|
| `DCF-1`: ShellCheck names `SC2086` on one unquoted expansion | Current artifact identifies the expansion and prescribed quoting fix | review | Direct repair is proposed; `$detect-curse` is not required. |
| `DCF-2`: baseline exits 1 after several suites with no failing suite in captured output | None | review | Forge invokes `$detect-curse` before proposing repair or asking to proceed. |
| `DCF-3`: focused test stays red after its planned change | Prior cause no longer explains the new assertion output | review | Forge invokes `$detect-curse` before another correction; it does not bypass the blocker. |
| `DCF-4`: required CI check exits 1 with only a job-level failure | None | review | Deliver invokes `$detect-curse` before proposing repair or pushing. |
| `DCF-5`: `just verify` becomes red in an unrelated suite | None | review | Quest invokes `$detect-curse` and records no advancement while red. |
| `DCF-6`: investigation ends without a verified cause | Investigation record says cause unestablished | review | Existing stop behavior remains active; no correction is proposed. |
| `DCF-7`: same artifact recurs after the evidence-backed correction | Same cause and correction already attempted; no new evidence | review | Existing blocker or stop path applies without another diagnose-fix cycle. |
| `DCF-8`: familiar error text admits two plausible causes | No current investigation | review | Familiarity does not count as evidence; `$detect-curse` precedes repair. |
| `DCF-9`: skill reference resolution | Not applicable | block | `just shape-check` exits 0. |

The tool-using-agent dimensions are tool-use correctness, task completion, loop avoidance, and
instruction following. Incorrect bypass of diagnosis or advancement through red is severity 4 and
is exercised by `DCF-2` through `DCF-8`. Deterministic structural checks cover reference
resolution; recorded manual traces exercise normative behavior without adding a prose assertion.
