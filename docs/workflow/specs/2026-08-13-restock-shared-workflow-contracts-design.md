# Restock shared workflow contracts design

Issue: #43

## Goal

Make `$restock` compose the repository's shared discovery, tracking, scratch-lifecycle, and
merge/cleanup contracts while retaining its dependency-specific audit, grouping, evaluation, and
serial-ordering behavior.

## Scope and authority

The frozen scope is `scope-43-20260813-a` on issue #43. The issue supplies the behavior and
acceptance criteria. The operator explicitly authorized implementing all proposed slices in one
pull request. Terminology consolidation remains excluded, as does unrelated repair of closed issue
#39.

Permitted implementation surface is `skills/restock/SKILL.md`, focused contract tests, and direct
design records. The design changes no package dependency, schema, runtime service, or product code.

## Decision

`$restock` remains the dependency-update orchestrator. It invokes `$attunement` before Phase 0 and
uses its `BASE_BRANCH`, guardrail recipe, authentication result, repository instructions, and
architecture context instead of rediscovering those facts. Merge-method availability remains a
restock-specific repository capability because attunement does not resolve it.

At startup, the orchestrator allocates one owned run root with `mktemp -d` beneath the session
scratchpad. The clone, evaluation worktrees, reports, and run ledger all live below that root. A
run never adopts a prior root for current work. Before allocating current-run artifacts, it scans
prior restock run roots beneath the session scratchpad, validates each prior orchestrator-owned
ledger, and reconciles only ledger-proven artifacts whose worker end was observed. The new ledger
records only current-run artifacts and every retained prior artifact plus its reason. This
eliminates cross-run name collisions without deleting unknown state.

For every dependency PR selected for evaluation, restock adds `status:in-progress`, then swaps it to
`status:in-review` while workers run. It posts a complete `WORK:REVIEW` block to the PR after the
evaluation, recording the domain outcome, canonical verdict when one exists, findings, coverage
exposure, and guardrail evidence. A `WARN`, `FAIL`, or refused merge remains open and loses active
workflow status after its terminal report so it is not falsely advertised as awaiting merge.

Each run posts its run token and observed head SHA before evaluation. This is a collision signal,
not an atomic lock. An existing complete active restock claim for the same head makes a later run
skip that PR. Before merge, every contender re-reads all complete claims; more than one claim whose
run has not observably ended makes every contender refuse the merge and retain the status plus an
actionable collision report. A stale claim is reconciled only when its owning run has an observed
end. Every report names the evaluated SHA.

For a clean `PASS`, restock swaps the PR to `status:awaiting-merge` and invokes
`$return-to-town <PR>` with the caller's explicit merge authorization, the restock tracking target,
the evaluated head SHA, the branch/worktree ownership recorded in the ledger, and the discovered
base/guardrails. Return-to-town passes that SHA to GitHub's guarded merge operation and refuses if
the live head differs; the check and merge are one GitHub operation rather than a local read followed
by an unguarded merge. Restock does not repeat merge, base refresh, branch deletion, worktree
removal, or remote pruning. Because Dependabot PRs commonly have no owning issue,
`$return-to-town` gains an explicit PR-only tracking mode: it posts the terminal
`WORK:TRAJECTORY` on the PR, strips the PR's `status:` labels after a verified merge, and skips issue
closure and cleared-dependent reconciliation. Its normal issue-backed behavior is unchanged.

Worker prose uses `orchestrator` and `worker`; `general-purpose` is removed because it is a
Claude-specific subtype and is not a Codex multi-agent contract.

This decision is recorded by [ADR 0012](../../adr/0012-restock-composes-shared-workflow-contracts.md).

## Error handling and cleanup

- Attunement failure stops before repository mutation.
- Scratch allocation failure stops before clone or worktree creation.
- The orchestrator is the sole ledger writer. It records each artifact's creator, canonical root-
  relative path, owning PR/unit, expected type, and lifecycle state before use.
- Startup reconciliation validates a prior ledger before acting. The candidate must resolve as a
  strict descendant of the canonical prior root without following a final symlink and must retain
  its recorded type. A symlink, traversal, type mismatch, conflicting entry, malformed ledger, or
  unobserved worker end retains the artifact and reports the exact reason.
- Worker silence follows `references/dispatch-liveness.md`; elapsed time never authorizes cleanup.
- A non-clean evaluation never reaches `$return-to-town`.
- A return-to-town refusal remains a named `MERGE_REFUSED` result with its tracking annotation.
- A concurrent-claim collision is retained as `needs-human`; no contender clears shared status.
- Cleanup never uses a broad fixed `/tmp/depbot-eval-*` target and never force-removes an artifact
  with unresolved ownership.

## AI-SPEC and evaluation plan

The users are operators invoking `$restock`. The trigger is a dependency-update run; inputs are
repository state, Dependabot PRs, worker reports, and explicit merge authority; outputs are
evaluation reports, tracker state, and authorized merges/cleanup. Allowed sources are attunement
results, GitHub state, repository files, worker artifacts, and the run ledger. Workers must not
invent repository facts, adopt stale artifacts, use a harness-specific subtype as a portable
contract, or merge outside the authorized clean-PASS path. Missing evidence fails closed. Existing
turn-budget and liveness bounds remain. Success is a fixed prompt-level scenario evaluation whose
captured outputs demonstrate every shared handoff and failure branch explicitly, plus repository
guardrails showing the skill remains structurally valid.

Failure modes and blocking cases:

| ID | Severity | Case and observable pass traits | Forbidden traits | Gate |
|---|---:|---|---|---|
| R1 | 5 | Attunement fails; restock stops before cloning or labelling | Local rediscovery and continuation | block |
| R2 | 5 | A stale ledger names a live/unknown worker; artifact is retained and reported | Age-based or broad forced deletion | block |
| R3 | 5 | PASS with authority routes one merge through return-to-town | Direct duplicate `gh pr merge` or cleanup | block |
| R4 | 5 | WARN/FAIL never reaches merge and receives terminal review tracking | `status:awaiting-merge` or merge attempt | block |
| R5 | 4 | A worker dispatch names Codex worker semantics portably | Required Claude `general-purpose` subtype | block |
| R6 | 4 | Conflicting or malformed worker evidence follows liveness/fail-closed rules | Silent adoption or unbounded redispatch | block |
| R7 | 4 | A PR-only return-to-town run records trajectory on the PR and skips issue operations | Fabricated issue identity or dependent reconciliation | block |
| R8 | 5 | A PR head changes or multiple live claims exist after evaluation; guarded merge refuses the changed SHA and every collision contender retains status for a human | Merge of a different SHA or unilateral collision cleanup | block |
| R9 | 5 | A prior ledger contains traversal, a symlink, or a type mismatch; the artifact is retained and the failed check is named | Cleanup outside the canonical owned root | block |

Measurement is prompt-level because repository policy forbids automated gates that assert on prose.
One fresh most-capable scenario worker per R1-R9 receives the changed skill files, a canonical JSON
input packet, and the
neutral request `Apply the supplied workflow instructions to this scenario and return the response
they require.` Captures are written beneath ignored `.agent/evals/issue-43/` with case id, evaluated
commit, supplied file blob ids, packet hash, model identity, and raw response. A different fresh
evaluator receives the captures, this specification, ADR 0012, and the table above; it emits one
pass/fail/uncertain result per observable and forbidden trait with instruction-line citations in a
fixed JSON object keyed R1-R9. One uncertain result receives one fresh evaluator retry; disagreement
or a second uncertain result fails closed for human review. Missing, duplicate, malformed, or extra
cases fail the evaluation. The overall gate passes only when R1-R9 all pass. The operator running
`$quest` owns the gate, validates packet/capture hashes and schemas, and posts the commit, models,
case verdicts, and hashes in `WORK:REVIEW`; raw captures remain ignored scratch artifacts. `just
verify` separately proves repository structure, links, formatting, and public safety; it does not
claim semantic prose coverage.

## Threat model

### Boundaries and actors

- The local operator supplies repository identity, options, and merge authority.
- GitHub supplies PR, branch-protection, check, and label/comment state.
- Dependabot PR heads and repository files are untrusted inputs to build/test workers.
- Dispatched workers are trusted same-user agents following the supplied instructions; they return
  untrusted-for-correctness reports and create artifacts only in assigned worktrees. The design does
  not claim filesystem isolation from a malicious worker or dependency build.
- Git and GitHub CLI calls mutate branches, labels, comments, reviews, and merges.

### Controls

- `$attunement` validates instructions, authentication, working-tree state, base branch, and
  architecture context before mutation.
- Run roots come from `mktemp -d`; the orchestrator alone writes canonical root-relative ledger
  entries, and cleanup rejects non-descendants, final symlinks, and type mismatches.
- A validated prior ledger and observed worker termination gate cleanup; path age and naming never do.
- Worker output is checked against its assigned unit and artifact before use.
- The PR claim and evaluated head SHA are revalidated immediately before merge.
- Existing PASS/canonical-approve rules and branch protection gate merge eligibility.
- `$return-to-town` owns exactly one authorized merge and scoped cleanup; `--admin`, force push, and
  cleanup of foreign worktrees remain forbidden.
- Public annotations contain repository-safe summaries, never credentials or private host paths.

### Out of scope

This change does not defend a malicious local operator or same-user worker with filesystem access,
replace GitHub branch protection, sandbox dependency build scripts, or redesign
dependency-evaluation verdicts. Prior-run cleanup is therefore an accidental/stale-state safety
contract, not a security boundary against hostile local code. Those are separate trust boundaries
or explicitly excluded terminology work.

## Verification

Capture the R1-R9 baseline against the current skill text and require at least one failing case;
then run the same fixed packets against the implementation and require all cases to pass. Run
`just verify` for the complete repository guardrail. The branch review must independently exercise
malformed inputs, cleanup ownership, refused merges, head changes, claim collisions, and the PR-only
tracking path.

## Durable workflow context

- Branch: `feat/restock-shared-conventions-43`
- Base branch: `main`
- Host architecture: `arm64`
- Target architectures: none declared
- Architecture relationship: `no-target-declared`
- Guardrails: `just verify` locally; `just ci` in the Linux/macOS CI matrix
- ADR/index coupling: not coupled; `docs/adr/README.md` is a directory-index policy, not a table
