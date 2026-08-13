# Canonical workflow vocabulary implementation plan

**Goal.** Implement issue #45's reviewed vocabulary contract across the affected skills and forge
reviewer prompts, with fixed behavioral evidence demonstrating the old contradictions and the new
shared behavior.

**Architecture.** ADR 0011 owns the canonical `orchestrator`/`worker` roles,
`critical | high | medium | low` findings, `approve | needs-attention` verdicts, qualified state
and risk axes, and review artifact lifecycle. Domain skills retain local classifications or
outcomes only with explicit one-way relationships to the canonical contract. Forge's two reviewer
templates share semantics while retaining their intentionally different transport shapes.

**Tech stack.** Markdown skill contracts and prompts, read-only model scenario evaluation,
repository shell guardrails through `just`.

## Global constraints

- Branch: `feat/unify-review-vocabulary-45`; base: `main`; guardrail: `just verify`.
- Host architecture: `arm64`; target architectures: none declared; relationship:
  `no-target-declared`.
- Bash 3.2 remains the shell floor; no runtime scripts or dependencies are added.
- Skills remain instructions, not programs; no automated gate asserts on prose.
- Canonical roles are `orchestrator` and `worker`; implementer/reviewer/evaluator remain precise
  worker subtypes; `subagent` remains only for literal harness/API capability references.
- Canonical findings are `critical | high | medium | low`; canonical review verdicts are
  `approve | needs-attention`, with `approve` meaning zero defensible findings.
- Reviewer cleanup failure returns exactly three lines: `CLEANUP_FAILED`,
  `Worktree: <absolute path>`, `Reason: <one line>`; it carries no verdict or counts.
- The fixed manifest, packets, capture envelopes, trait ids, and one-evaluator schema are copied
  exactly from the reviewed specification. Evaluation artifacts stay ignored under `.agent/`.
- ADR 0011 and the specification are durable; this plan records progress. Do not edit the
  superseded ADR 0007 beyond its existing supersession banner.

## Task 1 — Establish failing behavioral evidence

**Files:** create ignored `.agent/evals/issue-45-packets/*.json`,
`.agent/evals/issue-45-before-<run-id>/captures/*.json`, and evaluator result JSON. Modify no
tracked file.

**Interfaces:** consumes the exact manifest, packets, envelope schema, trait ids, and evaluator
schema from the specification. Produces a baseline result whose commit is the current HEAD and
whose path/packet identities are reused after implementation.

1. Verify `.agent/` is ignored with `git check-ignore -q .agent/evals/probe`; create `.agent/`
   only when safe and never alter a tracked `.agent/.gitignore`.
2. Materialize the canonical sorted packet JSON files exactly as specified; compute SHA-256 for
   each and record the fixed path set and current blob map.
3. Dispatch one fresh most-capable scenario worker for each of the twelve capture ids with the
   neutral request, selected packet, frozen charter, and verified bytes from all manifest paths.
   Wrap each unchanged response in the exact capture envelope.
4. Dispatch one different fresh most-capable evaluator with the exact evaluator prompt and
   schema. Confirm run id, model, commit, manifest, packet hashes, ten cases, fixed traits,
   implementation citations, and evidence capture ids are structurally complete.
5. Expected red: aggregate `fail`, with at least one case citing the pre-change divergent
   vocabulary or contract. A malformed result is not acceptable red evidence; correct the
   evaluation dispatch, not the repository instructions.

**Acceptance:** a complete baseline artifact proves the evaluation can fail against current
instructions; `git status --short` shows no evaluation artifact.

## Task 2 — Establish the canonical cross-workflow vocabulary

**Files:** modify `skills/gauntlet/SKILL.md`, `skills/oathbind/SKILL.md`,
`skills/restock/SKILL.md`, `skills/divination/SKILL.md`, `skills/trial-loop/SKILL.md`,
`skills/detect-evil/SKILL.md`, `skills/campaign/SKILL.md`,
`skills/summon-swarm/SKILL.md`, and `skills/quest-log/SKILL.md` where their public contracts use
the divergent terms.

**Interfaces:** consumes ADR 0011's role, severity, verdict, domain mapping, state, risk-axis, and
artifact rules. Forge in Task 3 relies on gauntlet as the canonical definition rather than a
conversion owner.

1. Replace gauntlet's forge conversion table with definitions for the four canonical severities,
   zero-finding verdict aggregation, domain scale distinctions, and artifact lifecycle.
2. In oathbind, add canonical impact severity to defensible findings, preserve scope
   classifications as orthogonal evidence, and state the zero-finding verdict rule.
3. In restock, rename bare merge `BLOCKED` to `MERGE_REFUSED`; distinguish evaluation outcomes
   from verdicts and matrix `coverage exposure` from severity/risk labels.
4. Rename divination `Risk flags` to `Change hazards` and update direct consumers/references.
5. Sweep generic role prose to `orchestrator`/`worker`, retaining only literal harness/API uses
   of subagent and precise subtypes. Qualify bare blocked states outside issue/workflow parking.
6. Align gauntlet/detect-evil examples on caller-supplied run-unique artifact paths and explicit
   ownership; remove any fixed-filename recommendation.
7. Review the diff with `rg` for the old terms; classify every survivor as literal API/label,
   historical quotation, or defined domain value.
8. Run `just shape-check`, `just public-safety`, and `just commit-check`; expect exit 0. Commit as
   `docs(skills): unify workflow vocabulary`.

**Acceptance:** every affected cross-skill value has one definition or explicit one-way mapping;
no label or dependency-policy semantics changed.

## Task 3 — Reconcile forge reviewer and worker contracts

**Files:** modify `skills/forge/SKILL.md`, `skills/forge/implementer-prompt.md`,
`skills/forge/task-reviewer-prompt.md`, and `skills/forge/code-reviewer.md`.

**Interfaces:** consumes Task 2's canonical contract. Produces the task and whole-branch reviewer
contracts exercised by E1, E5, E6, and E9.

1. Replace `Critical / Important / Minor` with canonical severities and identical definitions in
   both reviewer templates. Replace task `Approved | Needs fixes` and branch
   `Yes | No | With fixes` with `approve | needs-attention` and canonical counts.
2. Update forge routing: fix critical/high/medium; ledger low; do not relabel a dispositioned-low
   review as approve. Remove the obsolete severity conversion instructions.
3. Add the required explicit model field to the branch reviewer; keep task reviewers at a
   mid-tier floor selected by the rubric and branch reviewers at most-capable.
4. Give both reviewers the same test responsibility: trust first-run implementer evidence by
   default, run at most one focused check for a named unresolved concern, never rerun broadly to
   duplicate evidence, and treat a reported retry as nondeterminism.
5. Replace generic controller/coordinator/parent prose with orchestrator and dispatched agent
   prose with worker, retaining implementer/reviewer as subtypes. Rename implementer `BLOCKED` to
   `CANNOT_COMPLETE`; retain `NEEDS_CONTEXT`.
6. Require reviewer-created worktrees to be isolated and cleaned before return. Add the exact
   `CLEANUP_FAILED` alternative to both reviewer contracts and the forge handling path. Preserve
   `WRITE_FAILED` and `PACKAGE_MISSING` for whole-branch review.
7. Align artifact ownership: orchestrator supplies/clears/disposes run-unique paths; worker writes
   only its assigned file; cleanup failures never carry a verdict.
8. Run `just shape-check`, `just public-safety`, and `just commit-check`; expect exit 0. Commit as
   `docs(forge): reconcile reviewer contracts`.

**Acceptance:** both reviewer templates share severity, verdict, model-selection, test, cleanup,
and artifact semantics while retaining task-inline versus branch-file transport.

## Task 4 — Prove behavior and run repository guardrails

**Files:** create a new ignored post-implementation evaluation directory; modify tracked files
only if the evaluation exposes an in-scope defect.

**Interfaces:** reuses Task 1's exact packet files and stable path manifest; consumes the current
per-run blob map. Produces final evaluation and repository-gate evidence.

1. Repeat Task 1's twelve scenario captures against the implemented skill bytes and dispatch one
   different fresh evaluator. Require exact structure and `pass` for every fixed trait.
2. Verify the post-run path set and packet hashes equal baseline, the evaluated commit equals
   HEAD, and at least one implementation blob differs from baseline. Expected: aggregate `pass`.
3. If a behavioral defect requires tracked edits, fix it, commit one logical change, and rerun the
   entire post-evaluation against the new HEAD with fresh run ids.
4. Run `git diff --check`, then `just verify` bare. Expected: zero warnings and exit 0.
5. Review `git diff main...HEAD` for scope, naming, and stale old vocabulary. Record final branch,
   base, guardrail result, evaluation run ids, and open findings only in the quest's GitHub
   `WORK:REVIEW`/handoff annotations; do not edit this tracked plan after the proven HEAD.
6. A defensible in-scope finding from the final diff review enters the same repair loop as step 3:
   fix and commit it, rerun the complete post-evaluation and `just verify` against the new HEAD,
   and repeat the diff review. Stop instead of handing off when a finding cannot be resolved.
7. Only after the final review reports zero open findings and every oathbind, evaluation,
   adversarial-review, and handoff consumer has finished reading its artifacts, move this run's
   ignored issue-45 packet, capture, evaluator, oathbind, and gauntlet artifacts to trash. Never
   delete another run's `.agent/` content.

**Acceptance:** all fixed behavioral traits pass under one independent evaluator, all repository
guardrails pass, evaluation artifacts remain untracked, and the branch contains only chartered
surface.

**Rollback:** before push, revert the implementation commits newest-first while retaining the
design history only if another change still needs it; after push, use ordinary `git revert`
commits in that same order. Never rewrite published history. Ignored evaluation artifacts are
evidence only and can be moved to trash after their run ids and verdicts are recorded.

## Progress

- Current step: design complete; plan awaiting adversarial review.
- Branch: `feat/unify-review-vocabulary-45`.
- Base: `main` at quest start.
- Guardrail: `just verify` (`just ci` in CI).
- Open findings: none carried from the approved ADR and specification reviews.
