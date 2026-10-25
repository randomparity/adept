# Unchanged waits: bounded measurement design — #466

## Problem and authority

The #344/#347 reports did not observe a real unchanged timeout or mandatory progress turn.
Measure those gaps before changing shared guidance. Authority is
[WORK:SCOPE q466-beb8c30b](https://github.com/randomparity/adept/issues/466#issuecomment-6398075582),
with the operator's 2026-10-25 approval of the exact workload and finite budget.
Full-spec lane; fixed denominator 250 changed lines (M), derived from #466's three missing
wait cases and supported-strategy comparison. No new architecture decision: optional ADR0092
remains consumed, unused. Existing waiting policy remains the owner; no caller migration.

## Scope and approach

Publish `docs/benchmarks/unchanged-waits-466.md` and bump the manifest to 7.11.4 PATCH.
Prefer measured no-change publication over speculative guidance. A guidance edit may affect only
`references/dispatch-liveness.md` and a specifically proven conflicting consumer. No runner ships.
Reuse the completed #344/#347 dispatch/refill evidence without rerunning it.

## Global Constraints

Bash 3.2 is the floor. Host arm64; no target architecture declared.
Four serial N=1 arms; one experiment worker slot; four quiet workloads total; two native dispatches.
Each workload is one quiet 75-second command followed by `WAIT466-DONE`.
At most 12 collection calls and 180 seconds observation per arm, 720 seconds total; no retries.
Preserve original process/worker handles. Stop initiating at limits and reconcile outstanding handles.
Higher-priority progress is required before 60 seconds; no blocking wait exceeds 60 seconds.
No discretionary status reads, probes, replacements, extra experiment tasks or interim mailbox wakes.
No inference, token, cache, billing or dollar-cap claims from elapsed time or tool counts.
Private raw captures remain private. Transient plans are uncommitted.

## Protocol frozen before execution

| Arm | Workload owner | Coordinator collection |
| --- | --- | --- |
| N10 | Fresh native worker, retains its inner command handle | Native wait 10 seconds |
| N50 | Fresh native worker, retains its inner command handle | Native wait up to 50 seconds |
| P10 | Coordinator quiet subprocess | Collect original handle at 10-second intervals |
| P50 | Coordinator identical quiet subprocess | Collect original handle up to 50 seconds |

Shorten intervals to allow required progress before 60 seconds. Required progress uses only known
facts; a timeout is a tool result, not a host-generated progress wake. Record the actual wake
cause separately from the reason a progress message was required. Native worker inner-tool
collections are separate from coordinator native waits. Silence proves neither life nor end.
A native final notification observes that run's end; process exit observes only that process end.
Record failed/partial attempts without replacement. A deadline permits reconciliation, not retry.

## Success and validation

The report records the actual exposed client/plugin/model/effort and schemas, distinguishing
requested/native-accepted configuration from unobservable backend attribution. Record tool results,
unchanged timeouts, required progress messages, empty process outputs and ends by arm. Input/cache/
output, inference counts, coordinator-only tokens and billing are unavailable unless actually exposed;
unavailable is never zero. Retain private exact commands, original handles, responses and timings.
A finite invocation budget is not a hard dollar cap. Compare supported strategies within this harness
only; do not infer general latency distributions from N=1. Report unsupported or unrun capabilities.

Mode: task-test-not-applicable — the report's empirical reasoning has no executable consumer;
asserting its prose would duplicate claims rather than verify observations. Validate by reconciling
retained native tool responses and a human-readable evidence table. Manifest structural validation
uses existing `just version-check` and `just plugin-check`, with `BASE_SHA` set to the frozen base.
Run `just commit-check`, `just shape-check` and these focused checks before commits. The managed
pre-push hook owns one final full `just ci` against the pushed object; Linux/macOS CI is separate.

## Failure model

- Actors and deployments: authorized operator and coordinator in the currently exposed Codex
  harness; two sequential fresh native workers; short-lived local scratch subprocesses.
- Invariants and assets: finite credentialed usage; truthful provenance; private capture boundaries;
  original handles, claim ownership, serial dependencies and existing recovery budgets.
- Accepted failure classes: N=1 scheduling variation; unavailable usage/backend attribution;
  tool timeouts and partial attempts are retained, not treated as success or free work.
- Covered elsewhere: provider owns progress requirements and unavailable host capabilities;
  #354 owns routing; #161 phase/test timing; #117 end-to-end benchmarking; existing workflows
  own claim recovery/dependency redesign. Infrastructure changes require future authority.

## Excluded arms and interpretation

Claude/native credentialed-CLI arms, passive heartbeat and blocking beyond 60 seconds are unrun
under the approved capability/budget boundary. No new AI product surface is shipped; scratch
measurement prompts implement the frozen protocol only. Report fewer collection results if observed,
without equating them to fewer inference calls or token savings. If no repository change is supported,
publish the bounded no-change result and exact missing provider capability.
