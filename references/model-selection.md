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

## Boundaries

[Review-depth routing](review-depth.md) still determines single-pass versus iterating review;
model choice changes neither that route nor its budgets. Coordinator selection is separate
from reviewer selection. Reading this reference, invoking a skill, or selecting a child model
does not switch the root session. Existing dispatch, handoff, retry, permission, and merge
procedures keep their authority; this reference adds none. No savings are claimed without
measurement through accepted completion, including failed attempts.
