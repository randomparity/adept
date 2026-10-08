# Bounded orchestration validation report — #347

## Problem and scope

Consolidate the frozen #344 waiting and #346 refill experiments for #343. The operator
approved both harnesses, reuse of their evidence, and only missing planned live cases.
Publish one report in `docs/benchmarks/orchestration-validation-347.md`; preserve the
original reports and protocols. No skill ownership or caller migration changes are needed.
The report links to existing detailed records instead of duplicating their full tables.
No new architecture decision is needed: ADR 0017 already separates protocol from runner.
The campaign's optional ADR 0088 remains consumed and unused.

## Success

C1–C6 are the frozen #347 WORK:SCOPE criteria. Reconcile the eight measured arms against
private protocol, prompts, streams, metadata and job artifacts before declaring coverage.
For each harness, retain baseline/changed waiting and refill results, versions/settings,
guidance identity, capabilities, slot/deadline/run budgets, causes and available usage.
Distinguish native observations, coordinator reports and externally observed job events.
Unknown usage stays unavailable. Preserve baseline deviations, failures and service limits.
Map live healthy-idle/blocker/refill cases and constructed deadline/timeout/late-report/
campaign ownership cases separately. Freeze any missing planned case before measuring it;
a required unrun or failed live criterion remains outstanding. Route behavior discrepancies
to #344/#346 rather than silently changing their criteria or expanding this report.
Publish sanitized trace provenance and practical rerun inputs without raw host/session data.
No general savings percentage, full-campaign proof or #117/#161 result follows from N=1.

## Global Constraints

Use existing harness facilities and private short-lived scratch only; no new runner,
schema, dependency or platform. Bash 3.2 is the repository floor; no target architecture
is declared. Plans and raw traces stay private. Public text uses repository-relative paths.
The required plugin metadata version is 7.10.1. Preserve the exact #344/#346 protocols.

## Failure model

- Actors and deployments: report author/reviewer with authorized local private captures;
  public report readers; existing Codex and Claude Code CLI runs on macOS arm64.
- Invariants and assets at stake: truthful evidence boundaries, retained failures,
  private account/host/session data, frozen inputs and behavior-issue ownership.
- Accepted failure classes: missing inner telemetry is explicitly unavailable; N=1,
  uncontrolled service/cache state and wall-clock adjustment limit inference. Constructed
  walkthroughs do not establish live GitHub correctness; no criterion requires that proof.
- Covered elsewhere: waiting behavior #344; campaign scheduling #346; removed swarm #345;
  three-arm benchmark #117; review economics #161; new platform needs future authorization.

## Validation and publication

One tightly coupled report task: inspect raw evidence, map criteria, write the report and
bump metadata. Human reading establishes prose correctness; no automated prose assertions.
Independently review load-bearing raw metrics and frozen inputs, then inspect the complete
public diff for private identifiers. Run `just commit-check`, `just shape-check`,
`just plugin-check`, base-aware `just version-check`, and the ADR structural gate.
Managed pre-push owns final full local verification; CI independently checks the same head.
