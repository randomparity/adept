# Ownership-transition execution — issue #362

Charter: issue #362 `WORK:SCOPE` token `q362-a1c4e982`; approved exclusions and
epic #360 direction are retained there. Design denominator: 250 changed lines (M).

## Problem

Issue #361 lets a design select a criterion-linked ownership move, but the build
handoff can still focus on behavior alone. An implementer could leave a caller
on the old path or retain an unjustified duplicate while tests stay green. The
whole-branch review needs to compare the completed transition with the design.

## Scope and behavior

`$forge` owns task verification. When an approved design selects an ownership
transition, its existing task briefs and implementer prompt carry the intended
owner, every affected caller and migration, obsolete paths, protected contracts,
and any compatibility path with its contract and reason. Each task's existing
Verification inventory names structural evidence where a meaningful boundary
can be violated; otherwise it gives a concrete non-applicability reason. The
implementer reconciles the actual diff, direct callers, existing behavioral
tests, and contract evidence before reporting. It reports an unresolved
criterion instead of calling an incomplete migration done. No task review loop
or behavioral red test is added merely to relocate code.

`$quest` owns the final branch comparison. Its existing review focus compares
the built owner, caller migrations, removals, protected contracts, and retained
compatibility paths against the approved design. A missing caller or unjustified
parallel path is an in-scope finding. A compatibility path remains valid only
when its protected contract and reason are evidenced; removal cannot silently
break a public, persisted, security, or accepted-decision contract. This changes
review content, not the claim, review-depth, or merge protocols.

The current owner is the design/file map from #361. The intended execution
owners are forge's task verification and quest's whole-branch review. The
affected caller is the implementer prompt; no executable or public API path is
removed. Existing behavioral suites remain the behavior proof.

## Failure model

- Actors and deployments: a local or CI-dispatched forge implementer and quest
  branch reviewer operating on an approved feature branch.
- Invariants and assets at stake: the approved owner and caller migration,
  behavior covered by existing tests, and public/persisted/security contracts.
- Accepted failure classes: a pure instruction change has no deterministic
  prose test; the bounded agent evaluation may be inconclusive, so this release
  claims no measured quality gain from inconclusive cases. A pure relocation
  need not produce new behavioral red evidence when existing tests exercise it.
- Covered elsewhere: #361 owns the design choice and file map; #363 owns
  unattended authority; #364 owns broad cross-language evaluation; existing
  quest review and merge gates own final publication and merge authorization.

## Change surface

| File | Responsibility |
|---|---|
| `skills/forge/SKILL.md` | Task evidence and completed-transition reconciliation |
| `skills/forge/implementer-prompt.md` | Explicit implementer handoff and report |
| `skills/quest/SKILL.md` | Whole-branch approved-transition comparison |
| `.claude-plugin/plugin.json` | Reserved 5.6.0 version |
| `docs/workflow/evals/2026-09-12-ownership-transition-execution.md` | Bounded behavioral evaluation |

## Success and verification

Inspect four bounded plans/results: complete migration, omitted caller,
unjustified duplicate, and justified compatibility boundary. Require correct
accept/reject decisions based on actual code relationships, not the presence of
phrases. A structural check is meaningful only when its controlled violation
fails. A pure relocation may use the existing behavioral tests without an
invented red test. Run `just verify`; no prose assertion is added.

### AI surface evaluation plan

User: implementer and whole-branch reviewer. Trigger: approved ownership
transition execution. Inputs: four frozen synthetic case packets and either
baseline or revised instructions. Output: implementation disposition,
verification inventory, and branch-review concern. Allowed sources: each
packet and supplied instructions. Disallowed: assuming all green tests imply
complete migration, fabricating red behavior, or rejecting a justified
compatibility path by filename alone. Fallback: state unresolved evidence.
Budget: four cases × two variants, one fresh context per run, no retries.
Report model/harness, revisions, elapsed time, failures, and uncertainty.
This small evaluation is a warning signal; #364 owns broad language coverage.

The following source packets are frozen inputs. Each run receives the same
approved design: `policy.py` is the sole owner of status eligibility; migrate
`purchase.py`, `renewal.py`, and `invoice.py`; remove independent status rules;
keep the public `renewal.eligible(user)` signature under accepted ADR A-1.
Existing `tests/test_eligibility.py` exercises allowed, suspended, and expired
users through purchase and invoice entry points and passes on all four packets.
The evaluator must cite a specific call or predicate from the packet for each
decision. Human calibration checks the call graph and protected facade first;
a model verdict is not its own score. Each case is `warn`, never a release gate.

| ID | Source packet after implementation | Observable pass trait | Forbidden trait |
|---|---|---|---|
| OT-1 | `policy.py: is_eligible(u) = u.status == "active"`; `purchase.py: from policy import is_eligible`; `renewal.py: eligible(u) = is_eligible(u)`; `invoice.py: from policy import is_eligible`; no other status predicate | Accept single owner and migrated callers; retain behavior tests, optionally check source boundary with controlled fault | Demand a new behavioral red test merely for relocation |
| OT-2 | OT-1 except `invoice.py: from renewal import old_eligible`; `renewal.py` retains `old_eligible(u) = u.status == "active"` | Report invoice's omitted migration and leave criterion unresolved | Accept because behavior tests pass |
| OT-3 | OT-1 except `renewal.py: eligible(u) = u.status == "active"` | Report independent duplicate policy and obsolete rule | Treat matching output as justification |
| OT-4 | OT-1 with ADR A-1 explicitly requiring `renewal.eligible(user)` as a delegating public facade | Accept justified compatibility boundary | Require facade deletion by filename alone |

## Exclusions

#361 owns the initial ownership choice and design/file-map production. #363
owns standing authority. #364 owns broad cross-language evaluation. No new
task review loop or fabricated behavioral red test for pure relocation.
