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
run never adopts a path from an earlier invocation. Before evaluating, it reconciles only artifacts
recorded in its own ledger; an artifact with unresolved ownership is reported and retained. This
eliminates cross-run name collisions without deleting unknown state.

For every dependency PR selected for evaluation, restock adds `status:in-progress`, then swaps it to
`status:in-review` while workers run. It posts a complete `WORK:REVIEW` block to the PR after the
evaluation, recording the domain outcome, canonical verdict when one exists, findings, coverage
exposure, and guardrail evidence. A `WARN`, `FAIL`, or refused merge remains open and loses active
workflow status after its terminal report so it is not falsely advertised as awaiting merge.

For a clean `PASS`, restock swaps the PR to `status:awaiting-merge` and invokes
`$return-to-town <PR>` with the caller's explicit merge authorization, the restock tracking target,
the branch/worktree ownership recorded in the ledger, and the discovered base/guardrails. Restock
does not repeat merge, base refresh, branch deletion, worktree removal, or remote pruning. Because
Dependabot PRs commonly have no owning issue, `$return-to-town` gains an explicit PR-only tracking
mode: it posts the terminal `WORK:TRAJECTORY` on the PR, strips the PR's `status:` labels after a
verified merge, and skips issue closure and cleared-dependent reconciliation. Its normal
issue-backed behavior is unchanged.

Worker prose uses `orchestrator` and `worker`; `general-purpose` is removed because it is a
Claude-specific subtype and is not a Codex multi-agent contract.

This decision is recorded by [ADR 0012](../../adr/0012-restock-composes-shared-workflow-contracts.md).

## Error handling and cleanup

- Attunement failure stops before repository mutation.
- Scratch allocation failure stops before clone or worktree creation.
- The ledger records each artifact's creator, path, owning PR/unit, and lifecycle state before use.
- Startup reconciliation removes only artifacts whose recorded worker has an observed end and whose
  ownership matches the current run; otherwise it retains them and reports the exact reason.
- Worker silence follows `references/dispatch-liveness.md`; elapsed time never authorizes cleanup.
- A non-clean evaluation never reaches `$return-to-town`.
- A return-to-town refusal remains a named `MERGE_REFUSED` result with its tracking annotation.
- Cleanup never uses a broad fixed `/tmp/depbot-eval-*` target and never force-removes an artifact
  with unresolved ownership.

## AI-SPEC and evaluation plan

The users are operators invoking `$restock`. The trigger is a dependency-update run; inputs are
repository state, Dependabot PRs, worker reports, and explicit merge authority; outputs are
evaluation reports, tracker state, and authorized merges/cleanup. Allowed sources are attunement
results, GitHub state, repository files, worker artifacts, and the run ledger. Workers must not
invent repository facts, adopt stale artifacts, use a harness-specific subtype as a portable
contract, or merge outside the authorized clean-PASS path. Missing evidence fails closed. Existing
turn-budget and liveness bounds remain. Success is structural contract tests plus adversarial review
showing every shared handoff is explicit.

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

Measurement is structural and deterministic: a shell test extracts the restock and
return-to-town contracts and asserts required invocations, state transitions, scratch allocation,
ownership gates, PR-only behavior, and absence of the superseded direct merge/cleanup and fixed-path
instructions. `just verify` runs the test on Linux and macOS. Adversarial scenario review covers
ambiguous ownership, stale evidence, missing issues, and refused merges.

## Threat model

### Boundaries and actors

- The local operator supplies repository identity, options, and merge authority.
- GitHub supplies PR, branch-protection, check, and label/comment state.
- Dependabot PR heads and repository files are untrusted inputs to build/test workers.
- Dispatched workers return reports and create artifacts beneath the owned run root.
- Git and GitHub CLI calls mutate branches, labels, comments, reviews, and merges.

### Controls

- `$attunement` validates instructions, authentication, working-tree state, base branch, and
  architecture context before mutation.
- Run roots come from `mktemp -d`; derived children remain below the resolved owned root.
- The ledger and observed worker termination gate cleanup; path age and naming never do.
- Worker output is checked against its assigned unit and artifact before use.
- Existing PASS/canonical-approve rules and branch protection gate merge eligibility.
- `$return-to-town` owns exactly one authorized merge and scoped cleanup; `--admin`, force push, and
  cleanup of foreign worktrees remain forbidden.
- Public annotations contain repository-safe summaries, never credentials or private host paths.

### Out of scope

This change does not defend a malicious local operator with filesystem access, replace GitHub
branch protection, sandbox dependency build scripts, or redesign dependency-evaluation verdicts.
Those are separate trust boundaries or explicitly excluded terminology work.

## Verification

The focused test must first fail on the current skill text, then pass after the contract edits.
Run `just test` for the behavioral suites and `just verify` for the complete repository guardrail.
The branch review must exercise malformed inputs, cleanup ownership, refused merges, and the
PR-only tracking path.

## Durable workflow context

- Branch: `feat/restock-shared-conventions-43`
- Base branch: `main`
- Host architecture: `arm64`
- Target architectures: none declared
- Architecture relationship: `no-target-declared`
- Guardrails: `just verify` locally; `just ci` in the Linux/macOS CI matrix
- ADR/index coupling: not coupled; `docs/adr/README.md` is a directory-index policy, not a table

