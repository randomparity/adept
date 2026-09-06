# Light-spec artifact lane — issue #318

## Problem

Non-trivial work has one design weight today: a specification, a detailed implementation plan,
and review of both. Small, hazard-free changes that do not qualify for the existing no-spec
classifications therefore receive the same artifact set as broad or hazardous work.

## Scope

The artifact lane is derived with the issue assessment. Trivial bugfixes and governed small
changes remain `no-spec`. A non-trivial change with complexity `S` or `M` and change hazards
exactly `none` uses `light-spec`; every other change uses `full-spec`. A public contract,
migration, auth or permission behavior, concurrency, irreversibility, or external service is a
hazard and therefore cannot enter the light lane.

A light spec contains exactly Problem, Scope, Success, and Validation sections. “One page” means
at most 500 words and 60 physical lines, including headings and blank lines. Its Validation
section inventories every material contract as `focused-test` with a test, expected red, and
green command, or `task-test-not-applicable` with a concrete reason. It contains one
independently implementable unit and no task breakdown or separate plan. A viable design
alternative still earns an ADR.

`$spellcraft` writes and reviews the bounded artifact. `$quest` records the lane, audits every
design lane, and passes the light spec to `$forge`. Forge runs it as one Cast unit without
`task-brief`. Campaign triage returns, displays, persists, and dispatches the lane with the
assessment that supports it. Existing no-spec, full-spec, scope approval, guardrail, and branch
review contracts remain unchanged.

## Success

1. A non-trivial `M`, hazards-`none` issue produces one bounded spec and no plan.
2. The same issue with a public-contract hazard uses the full lane.
3. Forge accepts the light spec, closes its complete Validation inventory, and uses one Cast unit.
4. A light design receives design review and scope audit without inventing a plan denominator.
5. A campaign worker receives the exact lane and supporting assessment derived during triage.
6. Work that exceeds the cap or cannot remain one unit returns to lane selection.

## Validation

- Lane selection and cross-workflow propagation — `task-test-not-applicable`: these are
  human-readable routing instructions with no executable consumer; manually trace Success 1, 2,
  and 5 through quest and campaign.
- Light artifact, review, and proportionality — `task-test-not-applicable`: no executable
  consumer validates instructional prose; inspect spellcraft against Success 1, 4, and 6 and
  verify this file remains within its own line and word caps.
- Single-unit execution — `task-test-not-applicable`: forge's routing is prose; inspect its Cast
  entry and reconciliation rules against Success 3 and confirm no helper or prose assertion was
  added.
- Run the repository's structural, public-safety, version, and plugin-validation guardrails.
