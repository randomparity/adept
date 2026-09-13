# Model selection

Use this policy for model recommendations in forge and campaign. The
[provider mapping](model-mapping.md) is the single home for live identifiers and reasoning
controls. Capability tiers describe work; they are not prices, provider brands, or benchmarks.

## Tiers and phase defaults

| Tier | Capability needed |
|---|---|
| Mechanical | Execute a complete, bounded instruction with an obvious verification result and little judgment. |
| Standard | Integrate several files or steps, follow established patterns, and diagnose bounded failures. |
| Deep | Resolve ambiguity, reason across unfamiliar boundaries, and evaluate consequential tradeoffs or weak evidence. |

Choose the least capable tier adequate for the task, starting from these defaults:

| Phase or role | Default | Refinement |
|---|---|---|
| Triage | Mechanical | Standard for unfamiliar scope; deep for ambiguous requirements or consequential classification. |
| Scoping/design | Deep | Standard when the decision is already settled and only bounded detail remains. |
| Implementation | Standard | Mechanical only for fully specified transcription or a mechanical fix; deep for design latitude or difficult integration. |
| Review/security | Deep | Final whole-branch review always uses the strongest available permitted model, even for a mechanical implementation. |
| Coordination | Standard | Mechanical for settled bookkeeping; deep when resolving dependencies, scope conflicts, or consequential judgments. |
| Routine shipping/cleanup | Mechanical | Standard for diagnosing a bounded gate failure; deep for uncertain consequences or difficult verification. |

For each recommendation, consider ambiguity (missing requirements or unfamiliar relationships),
consequences (public contracts, security, irreversible actions), and verification difficulty
(weak tests, unavailable environment, hard-to-observe failures). A named signal raises a
mechanical default to standard, or to deep when resolving it needs broad judgment. Easy local
checks do not cancel consequential uncertainty. Model strength never supplies authorization.

Use the model's supported default reasoning effort initially. For clear bounded work prefer
an economical setting when verified supported; use a deliberative setting for difficult
judgment. Effort is a separate control, not a substitute for capability. The mapping defines
its provider-specific values; equal labels across providers do not imply equal work or cost.

## Resolve a recommendation

1. Identify the actual harness, provider, available models and controls from the active tool
   contract, runtime inventory or supported host inspection. An API catalog alone does not
   prove the harness exposes a model, effort setting, or account entitlement.
2. Apply effective user/project instructions and host restrictions before these defaults,
   using the harness's own instruction precedence. Do not overwrite a supported explicit
   choice with the mapping. If that choice conflicts with a required capability or control,
   report the conflict as unmet; do not silently change the choice or weaken the requirement.
3. Match the required capability to an available mapped candidate, or a runtime-documented
   alternative. For final review compare the permitted available candidates, not only the
   static mapping's preferred entry. A missing favorite can leave another adequate deep
   candidate; a lone mechanical candidate does not establish deep capability. If capability
   or relative strength cannot be established, name what is unmet before dependent work.
4. Check reasoning control support for this model **and** this invocation surface. When a
   requested control is unsupported, record it as unavailable. Use the supported effective
   default only if no required control/capability is lost; otherwise name the unmet requirement.
   Reconcile any host fallback with the actual effective settings instead of reporting the
   original request as applied.
5. For an unknown provider, use its runtime-supported default only when evidence establishes
   the needed capability. Record that default and its source; otherwise report the named unmet
   capability. Never construct an identifier from a tier, provider name, or naming pattern.

Record the recommendation in the workflow's existing work notes: phase, capability and reason,
provider/harness, requested choice, supported effective model/effort (or unknown/unavailable),
and override or fallback basis. Distinguish a recommendation from settings actually observed;
unknown observations cannot prove a required capability. Keep account and endpoint details private.
This is human-readable evidence, not a new schema or state store.

## Escalation after difficulty or failure

Classify the observed signal before changing capability. A worker's statement that it cannot
complete a task is evidence to investigate, not proof that its model was too weak. Check the task,
provided context, failure artifact and verification result against these routes:

| Signal and evidence | Existing route | Tier decision |
|---|---|---|
| Demonstrated reasoning failure despite complete task context and a check that exposes the error | Correct the dispatch under the owning workflow | Consider a stronger available, permitted tier |
| In-scope ambiguity or difficult verification shown by the task or check | Resolve the ambiguity or verification plan within approved scope | Select the adequate tier for that action |
| Missing or wrong context named by the report and confirmed against the brief | Supply the specific missing or corrected context | Do not infer a capability gap |
| Transport, authentication, rate limit or service failure before the task result is trustworthy | Use the owning recovery path or hold | Do not infer a capability gap |
| Wrong plan, oversized task or changed scope | Return to the existing plan, split or scope checkpoint | No model change authorizes the revised work |
| Safety restriction or denied authority | Stop at the owning safety or authorization gate | No model may bypass the restriction |

Resolve any stronger tier through the ordinary availability, override and control checks above.
An unavailable adequate model is a named unmet capability, not permission to guess an identifier,
repeat the same prompt, or weaken the strongest-available final whole-branch review. For a later
bounded unit, select a lower adequate tier only when the evidence that required the higher one no
longer applies; changing tiers is not itself a corrective action or a new budget.

Before a returned-worker retry, record new failure evidence and a distinct evidence-backed
change to the context, task, approved plan or effective capability. If the same failure recurs
after the same correction, stop for diagnosis instead of dispatching it again. Keep the returned
dispatch history separate from existing malformed-return, review, probe and liveness-replacement
allowances; preserve their cumulative use across model or session changes. Unknown consumption
holds the dependent action, and an exhausted allowance stays exhausted. Use the owning workflow's
predecessor-end, ownership and artifact checks before replacing a worker. Keep private evidence
in its existing ledger or handoff, and record only public-safe outcomes in public trackers.

## Coordinator continuation at phase boundaries

A settled phase boundary is an opportunity to reassess the coordinator's next decisions,
not an instruction to switch models or end a continuous workflow. Use the defaults above for
those decisions: bookkeeping can be mechanical, while unresolved dependencies, scope conflicts
or consequential merge judgments can require deep capability. A pending CI/worker wait does
not reduce the capability required when it returns. Keep waiting in the existing harness wait
mechanism; select reviewers independently under the strongest-available final-review rule.

First resolve the effective user/project choice and actual host controls as above. Distinguish
an agent-callable root control, an operator-only host control, child dispatch settings, and
startup/resume options. CLI flags or a provider's model catalog alone do not prove that this
active session can switch. Record which control is exposed, who can use it, and any unsupported
or unknown setting in existing private workflow notes. Do not write configuration or launch a
provider session to turn an unavailable control into an available one.

Choose one of these paths:

| Path | Preconditions | Action |
|---|---|---|
| Continue the current root | Its effective settings meet the next action's requirements | Continue the same workflow and ownership. No switch or session handoff is needed just because a skill or phase changed. |
| Native root switch | The active host actually exposes the control to this actor, the choice is permitted, and continuity can be verified | Record continuity before the control is used; then verify the effective settings and continuity before dependent work. An operator-only control requires the operator to perform it. |
| Explicit new-session continuation | The operator explicitly resumes a successor with the required capability and accessible continuity evidence | Use quest-log's sender/receiver checks, including predecessor ownership/end and existing recovery authorization. A copied token is not a transferred claim. |

For either switching path, apply quest-log's
[handoff checklist and receiver checks](../skills/quest-log/SKILL.md#model-and-session-handoffs)
using existing private records. Preserve exact permissions and approved exclusions, claim/run
ownership, branch/worktree and full commit identity, required artifact access, verification,
findings and consumed budgets. A native switch in the same continuing run does not replace its
owner; a host action that creates a successor instead takes the new-session path. Reconcile
changed heads, artifacts or owners before reusing proof. Unknown budget use is not zero.

After an attempted native switch, distinguish requested from observed effective settings.
Host fallback or an unconfirmed result does not prove the requested capability applied. Continue
only if the actual available evidence establishes the next action's requirements and continuity;
otherwise name the unmet fact through the owning workflow's existing checkpoint/park path.
When no root control is available, use the current adequate model or report the unmet capability
before dependent work. An explicit override remains in force; a recommendation is not authority
to replace it. Do not automatically retry a switch or gain attempts by opening a new session.

Child model/effort selection affects that child only. Record it separately from the root's
settings; invoking a skill, receiving a child result or reaching a phase boundary supplies no
root-switch evidence. Carry only the already-permitted review package to a reviewer, not the
controller's continuity narrative. None of these paths weakens review, permissions or merge gates.

## Boundaries

[Review-depth routing](review-depth.md) still determines single-pass versus iterating review;
model choice changes neither that route nor its budgets. Coordinator selection is separate
from reviewer selection. Reading this reference, invoking a skill, or selecting a child model
does not switch the root session. Existing dispatch, handoff, retry, permission, and merge
procedures keep their authority; this reference adds none. No savings are claimed without
measurement through accepted completion, including failed attempts.
