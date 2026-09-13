# Implement ownership-transition execution — issue #362

Charter: issue #362 `WORK:SCOPE` token `q362-a1c4e982`.
Base branch: `main`. Guardrails: `just verify`. ADR-index coupling: no index.
Design: `docs/workflow/specs/2026-09-12-ownership-transition-execution-design.md`.
Expected implementation size: 70–150 changed lines (M) — task edits in the file map below.

The implementation is Markdown workflow instructions plus plugin JSON. Forge
owns task verification, the implementer prompt consumes it, and quest owns the
final branch comparison. Bash 3.2 and arm64/x86_64 remain project targets;
this change adds no executable dependency or target-specific behavior.

## File map and callers

| Path | Current owner | Intended responsibility |
|---|---|---|
| `skills/forge/SKILL.md` | Task verification inventory and closure | Carry selected owner, caller/removal and protected-contract evidence into tasks, then reconcile the completed transition |
| `skills/forge/implementer-prompt.md` | Implementer placement and report | Tell implementer to verify ownership transition and report unresolved criteria |
| `skills/quest/SKILL.md` | Whole-branch approved-surface review | Compare the completed transition with design and diff |
| `.claude-plugin/plugin.json` | Installed version | Reserved `5.6.0` |
| `docs/workflow/evals/2026-09-12-ownership-transition-execution.md` | New | Matched-input bounded evaluation record |

Forge's task brief and dispatch are the direct callers of the inventory; the
whole-branch reviewer is quest's direct caller. No executable entry point is
removed. Retain `renewal.eligible(user)` in the evaluation as the ADR A-1
compatibility path; it delegates to the new owner and does not duplicate policy.

## Global constraints

- Keep the #361 design/file-map producer intact. Use existing forge task and
  quest branch-review gates; add no phase, task review, parser, or prose test.
- Keep public, persisted, security, accepted-decision, tracking, claim,
  review-depth, and merge contracts intact.
- Apply the reserved `.claude-plugin/plugin.json` value `5.6.0` exactly.

## Task 1 — carry transition through task evidence

### Interfaces

Consumes #361's approved design and file map, including intended owner,
affected callers, removals and protected contracts. Produces the existing
task brief, implementer dispatch, task report, and forge ledger; it adds no
field to a strict machine-readable format. Task 2 consumes the completed
branch diff and approved design, not a new Task 1 API.

Update `skills/forge/SKILL.md` and `skills/forge/implementer-prompt.md` so a
selected ownership transition in the approved design travels into every
affected task brief and implementer dispatch. Name current/intended owner,
affected callers and migration, obsolete paths, protected contracts, and each
retained compatibility path's contract and reason. At closure, reconcile the
actual diff and direct callers with the inventory, confirm existing behavioral
tests still exercise behavior, and require a controlled structural fault only
when a structural check protects a meaningful boundary. An omitted caller or
unjustified duplicate is unresolved rather than complete. Preserve the current
non-applicable verification mode for pure prose and pure relocation without a
meaningful new executable observation.

### Verification

- Contract: human-readable task handoff and evidence decision.
  Mode: task-test-not-applicable. No executable consumer validates the
  instructions or report shape; a prose search would only pin wording. The
  bounded agent cases in the spec inspect actual routes, while `just verify`
  protects repository structure.

### Steps and acceptance

1. Read the existing inventory and dispatch instructions in both named files.
   Add the selected ownership-transition details to the inventory checkpoint
   and dispatch construction. Keep each fact linked to a criterion and task.
2. Add a task-closure check against the actual changed paths and direct callers:
   intended owner present, affected callers migrated, obsolete path removed,
   protected contracts preserved, and compatibility path justified. Report a
   missing item as unresolved, not DONE. Existing behavioral tests still run.
3. Add the same evidence questions to the implementer prompt's work and report
   sections. A meaningful structural check must fail under one controlled
   boundary violation; pure relocation does not require invented behavioral red.
4. Run `just verify`; expect exit 0. Read the diff and confirm no new task
   review phase, ledger field, or executable prose assertion appears.

Acceptance: Task briefs, implementer reports, and forge closure can account
for the complete transition or name each unresolved criterion, while existing
verification modes and review cadence remain intact. No cleanup applies.

## Task 2 — compare the complete branch with approved transition

### Interfaces

Consumes the approved #361 design/file map and the actual feature-branch diff.
Produces the existing quest review focus and ordinary WORK:REVIEW summary;
no new annotation or reviewer protocol is introduced. The installed plugin
manifest consumes the reserved version value.

Update `skills/quest/SKILL.md`'s existing whole-branch review focus to ask
whether intended ownership landed, all affected callers migrated, obsolete
paths were removed, and protected contracts and justified compatibility paths
survived. Use the approved design and actual branch diff as evidence. Keep
review routing, finding severities, and merge authorization unchanged. Apply
the reserved plugin version. Record four bounded evaluations against baseline
and revised instructions in the spec's eval path, including failed or
inconclusive outcomes; do not assert on prose.

### Verification

- Contract: human-readable branch-review instruction and evaluation record.
  Mode: task-test-not-applicable. No executable consumer validates this prose;
  a text assertion would test incidental wording, not reviewer behavior. The
  four fresh-context cases provide observation, and `just verify` gates the
  shipped structure.
- Contract: installable plugin version.
  Mode: focused-test. With `BASE_SHA=284a0ea697feb3c34e9882235aca1e6465ac8406`,
  `just version-check` must fail while changed files retain `5.5.0`; after
  setting `5.6.0`, the same command must pass.

### Steps and acceptance

1. Run `BASE_SHA=284a0ea697feb3c34e9882235aca1e6465ac8406 just version-check`
   before the bump; expect nonzero because the changed tree still says `5.5.0`.
2. In quest's existing review-focus paragraph, require comparison of approved
   owner, direct callers, obsolete paths, protected contracts, and each retained
   compatibility path's contract/reason with the diff. Missing caller or
   unjustified independent policy is an in-scope finding; a delegating public
   facade with an accepted contract is justified.
3. Set only `.claude-plugin/plugin.json` version to `5.6.0`, then rerun the
   exact command from step 1; expect exit 0.
4. Run the spec's four frozen packets once each with baseline and revised
   instructions in fresh contexts. Record routes, source relationships cited,
   elapsed time, model/harness, revision SHAs, and inconclusive/failures in
   the eval path. No prose assertion becomes a gate.
5. Run `just verify`; expect exit 0. Inspect the final diff for changes to
   review frequency, claim/tracking, or merge rules; none are authorized.

Acceptance: The existing branch review asks about the whole transition and
does not reject a justified facade solely by file presence. The plugin gate
passes with the assigned version; the evaluation reports observed outcomes
without a quality claim if evidence is inconclusive. No cleanup applies.
