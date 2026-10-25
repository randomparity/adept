# Provider mapping refresh (#465)

## Problem

The centralized mapping predates current provider candidates and supported effort controls.
Issue #465 requests current reference data under the existing selection policy.

## Scope

Refresh `references/model-mapping.md` from primary OpenAI and Anthropic documentation;
update candidates, invocation examples, support distinctions, links, and verification date.
Keep the existing centralized owner; no caller migration or obsolete path is needed.
Bump required plugin metadata to the campaign-assigned patch version. No ADR is warranted:
this applies the accepted refresh procedure without a new architecture or policy decision.

### Failure model

- Actors and deployments: maintainers and agents reading the mapping in Codex or Claude Code.
- Invariants and assets: supported explicit overrides, strongest permitted available review,
  runtime evidence before account/control claims, centralized identifiers, existing tier policy.
- Accepted failure classes: future catalog drift between refreshes (bounded reference lifetime);
  account entitlement unknown (runtime verification remains required, not inferred from docs).
- Covered elsewhere: worker assignment #258; routing evaluation/savings #354; policy operator;
  artifact structure and release metadata existing repository guardrails.

## Success

C1: Current relevant candidates, examples, controls, primary links and date for both providers.
C2/C3: Preserve the scoped invariants and root-versus-worker distinction; no savings claims.
C4: Source inspection and bounded scenario walkthroughs suffice; no live workload or client launch.

## Validation

- `task-test-not-applicable`: mapping facts and policy-preserving prose require primary-source
  comparison and human reading; executable prose snapshots would not establish correctness.
- Walk both providers' supported choices, an explicit override, missing preferred candidate,
  unsupported effort, and unknown provider; require verified effective choice or named unmet need.
- `task-test-not-applicable`: release version is existing metadata, covered by `just version-check`.
- Run `just commit-check` and `just shape-check plugin-check version-check`; managed pre-push
  runs final full local `just ci` on the pushed object; independent CI covers macOS and Linux.
