# Campaign progress at durable boundaries — implementation plan

## Goal

Add a concise observational progress contract and workflow scenarios to `$campaign` so long waits
remain visible without becoming turn boundaries, state transitions, polling, or redispatch.

## Architecture

The change stays entirely in the campaign instruction surface. One top-level contract defines the
semantics and required fields; small call-site clauses bind it to planning, worker completion,
merge completion, and waits. Normative scenarios show that each update is observational. ADR 0038
governs the choice.

Tech stack: Markdown skill contracts and JSON plugin manifest; repository shell guardrails.

## Global Constraints

- Bash 3.2 is the shell floor, though this change adds no shell.
- Nothing automated asserts on prose; scenarios are normative examples, not grep-based tests.
- No long-lived process, timer polling, speculative liveness inference, reporting-driven
  redispatch, reporting-driven campaign mutation, or new dependency.
- Progress facts come only from the manifest, tracker, worker report, or verified GitHub state.
- Every repository change bumps `.claude-plugin/plugin.json`; this additive skill capability is a
  MINOR bump from `2.9.18` to `2.10.0`.
- BASE_BRANCH is `main`; the guardrail command is `just verify`; ADR-index coupling is `no index`.

## File map

| Path | Responsibility |
|---|---|
| `skills/campaign/SKILL.md` | Progress contract, boundary obligations, and workflow scenarios |
| `.claude-plugin/plugin.json` | Required installable plugin version bump |

Design records already committed on the branch are not implementation targets.

## Task 1 — Define and exercise the campaign progress contract

### Interfaces

- Consumes: the existing campaign manifest fields, tracker events, worker completion report, and
  verified GitHub state described by `skills/campaign/SKILL.md`.
- Provides: a normative `Progress updates` contract used by planning, dispatch/wait, and merge
  phases; no new function, file format, manifest field, or tracker annotation.

### Steps

1. Add this contract after the `Single continuous task` paragraph in
   `skills/campaign/SKILL.md`:

   ```markdown
   **Progress updates are communication, not checkpoints.** Emit a concise operator-visible
   update after presenting the plan, after each worker completion or merge, and immediately before
   a potentially long worker, review, CI, or merge wait. Emitting an update neither ends the
   continuous task nor authorizes a durable state transition, dispatch, probe, retry, or read.

   Derive every field from the campaign manifest, tracker, worker report, or verified GitHub
   state. Name the current issue or wave and phase, branch or PR when known, last verified signal,
   completed guardrails, and next awaited event. Mark unavailable facts unknown or omit them;
   never infer them from elapsed time or silence. Use one compact sentence for one row and the
   existing status table for several rows.
   ```

2. After step 4 presents the triage/plan table, add: `Emit the after-plan progress update before
   the first close or dispatch.`
3. Before serial blocking dispatch and parallel background waiting in step 5, require the
   before-wait update. After each worker completion is received, require the completion update
   before processing its PR or next row. These clauses invoke the top-level contract and add no
   polling or dispatch.
4. In step 6, require the before-wait update immediately before a potentially long PR verification,
   branch-refresh guardrail/CI run, or merge operation. The update reports only evidence already
   read for that operation; it performs no extra read, retry, probe, dispatch, or state change.
5. After each verified merge outcome is recorded in step 6, require the after-merge update before
   advancing to the next row or finalization.
6. Add a `### Progress scenarios` subsection after the existing status-read table with this
   behavior table:

   ```markdown
   | Boundary | Reported evidence | Invariant |
   |---|---|---|
   | Plan presented | Wave/issue plan, verified preflight, next dispatch | The update changes no row |
   | Serial or parallel wait | Current issue/wave, known branch/PR, latest signal, guardrails, awaited event | No timer read, probe, retry, or redispatch is caused by reporting |
   | Worker completed | Worker-reported branch/PR and guardrails, next verification or merge | Completion processing alone owns state changes |
   | Merge completed | Verified PR/issue outcome, next row or finalization | Merge processing alone owns manifest and tracker writes |
   | Evidence unavailable | Unknown or omitted field | Silence, age, and missing data supply no fact |
   ```

7. Review every existing wait site in campaign steps 5 and 6. Record it as covered by a named
   update clause or as not orchestrator-owned; confirm each clause refers to the top-level contract
   and introduces no state mutation, dispatch, probe, retry, or read.
8. Run `git diff --check`. Expected: exit 0 and no output.
9. Bump `.claude-plugin/plugin.json` from `2.9.18` to `2.10.0`; this adds a campaign capability.
10. Run `just verify` bare. Expected: exit 0; all repository gates and discovered test suites pass.
11. Commit the implementation with explicit paths:

    ```text
    feat: report campaign progress at boundaries (#263)
    ```

### Acceptance criteria

- All three boundary classes from issue #263 invoke one shared progress contract.
- Every required field and evidence source is named once in the governing contract.
- Scenarios cover planning, waits, worker completion, merge completion, and unavailable evidence.
- No new executable, manifest schema field, tracker write, dependency, polling path, liveness
  inference, retry, probe, or dispatch is added by reporting.
- `just verify` passes and the plugin version is `2.10.0`.

### Rollback

Revert the implementation commit. No data, migration, external service, or persistent campaign
schema requires cleanup.

## Durable handoff

- Branch: `feat/campaign-progress-boundaries-263`
- BASE_BRANCH: `main`
- Current phase: design complete; plan review next, then forge TDD build.
- Open findings: none.
- Review deferrals: none.
- Guardrail: `just verify` (full suite); focused document gates are `just records` and
  `just public-safety`.
