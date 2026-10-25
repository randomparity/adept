# Worker model assignment

## Problem

Issue #258 asks whether campaign/quest workers use appropriate models. Shared selection
policy exists, but campaign passes only a tier, quest lacks a dispatch-time obligation,
and forge templates omit effort; the implementer template also misstates inheritance cost.

## Scope

Extend the existing campaign, quest and forge dispatch instructions and forge templates.
Shared model selection remains the owner of tiers, overrides, capability, availability and
fallback semantics; link it instead of duplicating identifiers or creating a resolver.
No ownership transition, caller migration or compatibility path is needed.
Use existing manifest notes and forge/quest work records for selection evidence.
Exclusions approved by the operator: comparative evaluation (#354), catalog refresh (#465),
and coordinator switching (#352). Optional ADR0090 remains unused; release patch 7.11.2.

AI-SPEC: Workflow operators dispatch workers from issue/task/review inputs using only
active harness controls, shared policy and effective instructions. Output is a supported
model/effort request plus truthful observed settings in existing private records. Invented
identifiers, inherited settings called explicit, weakened review and configuration writes
are forbidden. Unsupported controls follow shared default-or-unmet behavior. Validation
uses normal native workflow dispatches and bounded walkthroughs, without provider tasks,
comparative benchmarks or extra retry budget. Success is actionable selection at each owner.

### Failure model

- Actors/deployments: trusted local workflow operators using native child dispatch controls.
- Invariants/assets: adequate workers, strongest permitted final review, explicit overrides,
  truthful request/observation evidence, existing isolation and recovery budgets.
- Accepted failures: backend identity/usage unavailable, recorded unknown; no savings claim.
- Covered elsewhere: mappings #465; economics #354; root switching #352; shared policy owns
  unavailable-capability holds and existing workflows own retries, authorization and privacy.

## Success

Campaign triage/fix workers, quest audit/review/security workers, and forge implementer/reviewer
workers apply the shared resolver before dispatch, supply model and effort where supported,
and retain requested versus observed evidence in existing private notes. Templates guide
selection without inventing tool fields or assuming inherited cost. Explicit choices and
required review strength survive unavailable controls.

## Validation

- task-test-not-applicable: selection instructions and templates have no executable consumer;
  prose assertions are prohibited by repository policy. Read entry points and templates.
- Bounded evaluation (instruction following/handoff failures severity4; each case blocks):
  E1 ordinary task selects adequate supported settings; E2 ambiguous capability holds;
  E3 requested forbidden downgrade preserves strongest review; E4 stale mapping yields to
  runtime/override evidence; E5 private setting evidence remains private; E6 unavailable
  controls do not launch sessions or gain retries; E7 forge inheritance is recorded honestly.
  Evaluate E1 through normal fresh design/audit/branch-review dispatches; E2–E7 through
  explicit constructed walkthroughs. Distinguish tool acceptance from backend telemetry.
- Run commit-check, shape-check, plugin-check and version-check; mandatory pushed-object
  pre-push hook owns final local just ci, with independent Linux/macOS CI.
