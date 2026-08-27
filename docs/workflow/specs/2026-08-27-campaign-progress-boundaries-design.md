# Campaign progress at durable boundaries — design

Issue: [#263](https://github.com/randomparity/adept/issues/263)  
Decision: [ADR 0038](../../adr/0038-campaign-progress-is-observational.md)

## Goal

Make a healthy campaign observable during long-running work without changing its continuous-task,
state, dispatch, or liveness contracts.

## Scope authority

- Scope identity: issue #263, token `q263-965cecc3`.
- Outcome and criteria: the frozen `WORK:SCOPE` annotation on issue #263.
- Surface: `skills/campaign/SKILL.md`, its workflow scenarios, these design records, and the
  repository-required patch version bump.
- Exclusions: timer polling, speculative liveness inference, reporting-driven redispatch,
  reporting-driven campaign mutation, and executable runtime services.
- Ambiguities: none. Interaction is interactive.

## Design

Add one progress-reporting contract near the campaign's continuous-task rule so it governs every
phase. A progress update is operator-visible communication, not a turn boundary, durable state
transition, liveness signal, or authorization source.

The orchestrator emits an update at three boundary classes:

1. after presenting the campaign plan;
2. after a worker completes and after a merge completes; and
3. immediately before a potentially long wait for a worker, review, CI, or merge operation.

Every update is assembled from already-owned evidence: the campaign manifest, tracker events,
worker completion report, or verified GitHub state. It contains the current issue or wave, phase,
branch or PR when known, last verified signal, completed guardrails, and next awaited event.
Unavailable facts are marked unknown or omitted. Silence, timestamps, and elapsed time do not
supply facts or trigger additional reads.

The existing read-status table remains the shape for multi-row observations. Boundary updates may
use a compact sentence or table, whichever is smaller, but do not add manifest fields, tracker
annotations, labels, dispatches, or probes.

## Failure handling

Reporting never upgrades uncertain evidence. If a source read fails, the update names the failed
read only when it is already part of the active workflow; reporting does not perform a retry or
manufacture a poll. The underlying campaign rule decides whether the failure blocks, holds, or
allows other rows to drain.

## Workflow scenarios

| Scenario | Observable update | State and dispatch invariant |
|---|---|---|
| Plan is presented | Wave/issue plan, verified preflight and next dispatch | No row changes solely because of the update |
| Serial worker will block | Issue, phase, known branch/PR, latest signal, guardrails, awaited worker completion | Exactly one authorized dispatch; no timer read or redispatch |
| Parallel wave waits | Wave and row facts from manifest/tracker, then awaited end-of-run notification | Existing workers remain the only workers |
| Worker completes | Worker-reported branch/PR and guardrails, then next verification or merge | Completion processing owns state changes; the update adds none |
| Merge completes | Verified PR/issue outcome and next row or finalization event | Merge workflow owns manifest/tracker writes; the update adds none |
| A fact is unavailable | Field is unknown or omitted | No inference from silence, age, or missing data |

These scenarios are normative examples rather than an automated prose gate. Repository rule 4
forbids tests that assert Markdown wording; review checks the contract and scenarios together.

## Verification

- Read the changed campaign contract against each workflow scenario.
- Run `just verify` bare.
- Confirm the diff adds no executable, manifest schema field, tracker write, polling loop, or
  dispatch path.

## Durable handoff

- Branch: `feat/campaign-progress-boundaries-263`
- BASE_BRANCH: `main`
- Guardrail: `just verify`
- ADR-index coupling: no index.
- Host architecture: `x86_64`; target architectures: none declared; relationship:
  `no-target-declared`.

