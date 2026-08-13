# Restock shared workflow contracts implementation plan

**Goal:** Make `$restock` compose attunement, quest-log tracking, run-unique scratch lifecycle,
and return-to-town merge/cleanup contracts without changing its dependency-evaluation outcomes.

**Architecture:** Restock remains the orchestrator and owns dependency-specific phases plus shared
run artifacts. Return-to-town gains a narrow PR-only mode for one terminal unit and returns typed
base-change/tracking outcomes. Temporary state is described by one versioned ownership manifest
under a run-unique session-scratchpad root.

**Tech stack:** Markdown skill contracts, Git/GitHub CLI procedures, Codex multi-agent workers,
Bash 3.2-compatible command examples.

## Global constraints

- Bash 3.2 is the shell floor; no associative arrays, `mapfile`, or GNU-only assumptions.
- Skills are instructions, not programs; add no helper script or dependency.
- No automated test asserts on prose. Semantic verification uses fixed prompt-level R1–R20 cases;
  `just verify` covers structural repository guardrails.
- Use `orchestrator` and `worker`; precise worker subtypes remain valid. Do not require the Claude
  `general-purpose` subtype for Codex dispatch.
- Local integration is advisory evidence for one observed head/base snapshot. GitHub atomically
  guards only the PR head; reports disclose the residual base-advance race.
- `BASE_BRANCH=main`; guardrails are `just verify` locally and `just ci` in CI.
- Host architecture is `arm64`; no target architecture is declared; relationship is
  `no-target-declared`.
- Branch is `feat/restock-shared-conventions-43`.

## File map

- Modify `skills/return-to-town/SKILL.md`: accept PR-only tracking, expected head/evaluated base,
  typed `BASE_CHANGED`, unit-only cleanup, and `MERGED_TRACKING_INCOMPLETE`.
- Modify `skills/restock/SKILL.md`: invoke attunement; allocate/reconcile/finalize session scratch;
  add PR lifecycle annotations/status; dispatch portable workers; delegate passing merges and unit
  cleanup to return-to-town; clean non-merge units itself.
- No executable test file is created because repository policy forbids gates over prose.

## Task 1 — Establish failing semantic baseline

**Interfaces**

- Consumes: current `skills/restock/SKILL.md`, `skills/return-to-town/SKILL.md`, spec R1–R20.
- Produces: ignored `.agent/evals/issue-43/baseline-summary.json`, keyed by R1–R20, with at least one
  failing case and file blob ids for the evaluated commit.

1. Create canonical JSON input packets for R1–R20 under ignored `.agent/evals/issue-43/packets/`.
   Each packet contains only the scenario inputs named by its spec row, including exact simulated
   Git/GitHub results where needed.
2. Dispatch one fresh worker per case in bounded waves. Give it the two skill files at the baseline
   commit, its packet, and exactly: `Apply the supplied workflow instructions to this scenario and
   return the response they require.` Record model, commit, blobs, packet SHA-256, tool-call report,
   and raw response.
3. Dispatch two fresh evaluators with the captured responses, spec, ADR 0012, and R1–R20 rubric.
   Require boolean pass/forbidden-trait fields with instruction citations. Any disagreement,
   uncertainty, malformed result, missing case, or extra case fails closed.
4. Verify the baseline summary contains R1–R20 exactly and at least one failure. Expected result:
   failure, proving the cases can reject the current contract. Do not commit ignored artifacts.

## Task 2 — Extend return-to-town’s terminal-unit interface

**Interfaces**

- Consumes: PR number, tracking mode (`issue-backed` or `pr-only`), actual PR head SHA, evaluated base
  SHA, guardrail evidence, exact unit-owned worktree/ref, and `shared: retain` disposition.
- Produces: existing handoff/merge result, plus typed `BASE_CHANGED` or
  `MERGED_TRACKING_INCOMPLETE`; cleans only explicitly unit-owned artifacts.
- Later task dependency: restock invokes this interface for clean PASS units.

1. Edit `skills/return-to-town/SKILL.md` entry snapshot to accept the optional immutable restock
   context. In PR-only mode, compare live base with evaluated base before merge and return
   `BASE_CHANGED` without merge/cleanup on mismatch.
2. On authorized merge, add `--match-head-commit <actual-head-sha>` to the selected `gh pr merge`
   command. State that this guards only head and local integration remains snapshot evidence.
3. Define PR-only tracking: pending trajectory, verified status transition, applied trajectory;
   after merge remove PR `status:` labels and skip issue closure/dependent reconciliation.
4. If merge succeeds but terminal tracking does not, re-read merged state, never retry merge, retry
   tracking once after readback, then return `MERGED_TRACKING_INCOMPLETE` with repair details.
5. Restrict cleanup to the exact unit worktree/ref supplied by restock; honor `shared: retain` for
   clone/root/manifest/reports. Preserve all existing issue-backed behavior.
6. Run `just shape-check`, `just public-safety`, and `git diff --check`. Expected: exit 0. Commit only
   `skills/return-to-town/SKILL.md` as `docs(skills): add PR-only return-to-town handoff`.

## Task 3 — Recompose restock around shared contracts

**Interfaces**

- Consumes: `$REPO`, `$OPTIONS`, explicit merge authorization, attunement results, Dependabot PR
  state, worker reports, return-to-town typed outcomes.
- Produces: dependency evaluation reports; PR `WORK:TRAJECTORY`/`WORK:REVIEW`; status transitions;
  one version-1 ownership manifest; reconciled/finalized scratch state.

1. Replace clone/default-branch discovery with an explicit `$attunement` preflight and retain its
   base, guardrails, architecture, working-tree, and authentication result. Keep merge-method
   discovery as restock-specific capability discovery.
2. Before allocating current state, scan only direct prior roots under
   `<session-scratchpad>/restock/run.*`. Read only supported same-user ownership manifests. Retain
   and report unknown/malformed roots without traversal.
3. Allocate `run.XXXXXX` with `mktemp -d`, then write one version-1 ownership manifest containing
   root/repository/run identity and unit/run-owned artifacts. Record canonical relative paths,
   types, clone/common-dir, worktree registration, temporary ref, worker lifecycle, and completed
   cleanup steps. Every manifest transition writes and fsyncs a sibling file, atomically renames it
   over the live manifest, and reads back the expected state before the next mutation.
   Worker lifecycle starts `dispatched`; the active orchestrator changes it to `ended` only after a
   harness end-of-run notification (or orchestrator-requested stop followed by that notification),
   recording worker identity, recovery chain, observation, and artifact dispositions per
   `references/dispatch-liveness.md`. Startup never infers end from time, process absence, or stale
   files. A manifest lacking verified `ended` evidence is retained and reported without cleanup.
4. Reconcile proven-ended units in Git-aware order: validate containment/type/registration/ref,
   persist/read back `cleanup: worktree-pending`, remove the exact worktree (force only for proven-
   owned dirty ended work), verify unregistered, persist/read back `worktree-removed`, delete the
   exact ref, persist/read back `ref-removed`, then prune only the owning clone and persist/read back
   `unit-clean`. On restart, verify the Git state expected by the last persisted step before either
   completing the pending operation or advancing; a mismatch retains and reports the unit.
5. Before selecting a PR, classify existing restock activity only when active label and latest
   applied restock trajectory match repository/PR/token/head/transition. Skip active or ambiguous
   state without mutation.
6. For every transition, post/read pending trajectory, swap/read labels, then post/read applied
   trajectory. Use one bounded retry only after readback. Reconcile interrupted halves by run token.
7. Retain existing evaluation outcomes and canonical mappings. Record the actual PR head, evaluated
   base, local integration commit, guardrails, and residual base race in `WORK:REVIEW`.
8. Replace fixed `/tmp/depbot-eval-*` examples with manifest-owned paths below the run root. Replace
   the contradictory `general-purpose` requirement with portable Codex worker dispatch language.
9. For clean PASS, call return-to-town with immutable PR/unit context. On first `BASE_CHANGED`, move
   to in-review and perform one fresh snapshot evaluation; on second, post terminal evidence and
   clear active status. For WARN/FAIL/refusal, restock cleans the unit itself. Never duplicate shared
   merge/cleanup commands.
10. After every unit is terminal and worker end observed, finalize the run: remove shared owned
    artifacts only after persisting/readback of `finalization-pending`. Persist/read back progress
    after each exact report/clone removal, and on startup resume a live manifest from its recorded
    finalization step after verifying filesystem state. After all removals are verified, write/fsync
    a sibling finalized manifest, atomically rename it over the live manifest, read it back, then
    remove the exact root. Startup removes an otherwise-empty validated finalized root.
11. Run `just shape-check`, `just public-safety`, and `git diff --check`. Expected: exit 0. Commit only
    `skills/restock/SKILL.md` as `docs(skills): compose restock with shared workflows`.

## Task 4 — Verify semantics and repository guardrails

**Interfaces**

- Consumes: implementation commit and the unchanged Task 1 R1–R20 packets.
- Produces: ignored post-implementation captures and two evaluator summaries; durable compact review
  summary for the later PR `WORK:REVIEW`.

1. Re-run the exact Task 1 packets against the implementation commit with fresh scenario workers.
2. Run two fresh independent evaluators. Expected: both pass every boolean field for R1–R20 with
   instruction citations, no uncertainty/disagreement, and manifest/blob hashes matching captures.
3. Run `just verify` bare. Expected: exit 0 with the accepted single plugin-validator warning only.
4. Run `git diff --check` and inspect `git diff main...HEAD` for naming, duplication, and accidental
   expansion. Expected: clean diff and only the planned files/records.
5. Record case verdicts, models, commit, packet hashes, guardrail result, and any human disposition in
   the compact review summary. Do not commit `.agent/evals/` artifacts.
6. If either evaluator fails, is uncertain, disagrees, or returns malformed evidence, verify each
   failed field against the skill text, edit only the planned two-skill surface for defensible
   findings, run focused guardrails, and commit each correction separately. Rerun all unchanged
   R1–R20 packets with fresh workers and both fresh evaluators after every correction round. Stop for
   human disposition after five rounds without a complete pass; never weaken packets or rubric to
   obtain green.

## Rollback and cleanup

Task 3 depends on Task 2. Roll back Task 3 before Task 2, or revert both together; Task 2 may remain
without Task 3, but Task 3 may not remain without Task 2. Failed evaluation leaves ignored captures
for diagnosis. Never delete unknown scratch roots or foreign worktrees. Before shipping, verify the
feature branch working tree is clean and no evaluation worker remains live.
