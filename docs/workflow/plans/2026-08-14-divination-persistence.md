# Durable divination assessment implementation plan

**Goal.** Persist `$divination` assessments as authenticated `WORK:DIVINATION` issue annotations
and let `$quest` and `$bounty decompose` adopt a fresh, fully revalidated assessment.

**Architecture.** ADR 0015 separates advisory assessment evidence from quest's frozen
`WORK:SCOPE` authority. The producer publishes one authenticated, source-bound annotation;
consumers select latest-complete first, then authenticate and validate the whole assessment or
fall back to their existing local reasoning. The reviewed specification owns the exact annotation,
fingerprint, citation, failure, threat, and adversarial-review contracts.

**Tech stack.** Markdown skill contracts, `gh`, `git`, `jq`, SHA-256, and repository shell
guardrails through `just`.

## Global constraints

- Branch: `feat/divination-persistence-49`; base: `main`; guardrail: `just verify`.
- Host architecture: `arm64`; target architectures: none declared; relationship:
  `no-target-declared`.
- Skills remain instructions, not programs; add no helper or dependency.
- Bash 3.2 remains the shell floor for any command recipe.
- `WORK:DIVINATION` is advisory and never supplies a `WORK:SCOPE` authority field, changes a
  `status:*` label, or assigns/reinterprets `risk:*`.
- The producer, selected comment author, and consumer authenticated login must match exactly.
- Producer and consumer repository worktrees must be clean; assessment adoption is all-or-nothing.
- Use the exact annotation shape, fingerprint protocol, evidence grammar, and failure contract
  from the reviewed specification.
- Treat E1–E15 as an adversarial review checklist, not a prompt-level model gate.

## Task 1 — Review the contract scenarios

**Files:** review ADR 0015, the specification, and this plan; change tracked files only to resolve
a defensible finding.

1. Map every E1–E15 checklist scenario to explicit producer, registry, or consumer clauses.
2. Adversarially review the specification and plan against the frozen `WORK:SCOPE`, same-login
   authentication decision, failure boundaries, and repository policy.
3. Fix defensible findings, commit each review round separately, and re-review until approved or
   the bounded review stop condition fires.

**Acceptance:** every checklist case has an explicit contract owner; the reviewed artifacts are
approved with no undispositioned finding and introduce no model-response completion gate.

## Task 2 — Implement the durable producer and consumers

**Files:** modify `skills/divination/SKILL.md`, `skills/quest-log/SKILL.md`,
`skills/quest/SKILL.md`, `skills/bounty/SKILL.md`, and direct mutation-behavior reference
`skills/seek-quest/SKILL.md`.

**Interfaces:** divination produces the exact annotation defined by the specification. Quest and
bounty consume the quest-log marker contract and either adopt the complete four-field assessment
or invoke their existing derivation path.

1. In `skills/quest-log/SKILL.md`, add `WORK:DIVINATION` to the annotation registry as an issue
   annotation posted after assessment. Document latest-complete-first selection, distinct
   ownership from `WORK:SCOPE`, and the existing safe body-file posting/readback recipe.
2. In `skills/divination/SKILL.md`, replace the read-only contract with read-only investigation
   followed by one bounded public-safe annotation write. Add repository/issue/auth resolution,
   clean-tree gating, exact source fingerprint and evidence construction, one post attempt,
   token-based indeterminate reconciliation, readback verification, and explicit non-durable
   local reporting on failure.
3. In `skills/quest/SKILL.md` step 1, before branch creation, read the latest complete block first;
   authenticate producer/comment/current login; require clean tree, issue identity, exact source
   fingerprint and HEAD, valid evidence grammar, and semantic support for every field. Adopt all
   four fields or derive all four locally. If any required persisted-evidence read or validation
   fails and the independent issue/repository derivation read also fails, stop before scope freeze
   with non-adoption and a public-safe retry message. Never use assessment content for the eight
   charter fields.
4. In `skills/bounty/SKILL.md` decompose mode, apply the same whole-block validation. Use a valid
   assessment, including `split`, as drafting evidence; otherwise preserve existing reasoning. If
   any required persisted-evidence read or validation and the independent derivation read both
   fail, stop before any draft or filing with non-adoption and the same public-safe retry contract.
5. In `skills/seek-quest/SKILL.md`, state its read-only guarantee independently instead of using
   divination as an exemplar. Sweep direct references with
   `rg -n '\$divination|WORK:DIVINATION|in-session only|read-only' skills docs/cheatsheet.md`.
   Fix only references that characterize divination's mutation behavior; report other matches as
   diagnostic evidence.
6. Run `git diff --check`, `just shape-check`, `just public-safety`, and `just commit-check`; expect
   exit 0. Commit as `docs(skills): persist divination assessments`.

**Acceptance:** producer and both consumers implement the same exact contract; no helper,
dependency, label behavior, historical migration, or scope-authority change is introduced.

## Task 3 — Prove branch and repository integrity

1. Sweep direct references with the specification's `rg` command and inspect every match.
2. Run the focused formatting, shape, public-safety, and commit checks without suppressing output.
3. Run a diff-scoped adversarial review and security review; fix defensible findings and re-review.
4. Apply a behavior-preserving simplification pass over the final diff.
5. Run `just verify` bare at final HEAD and record the completed guardrail result.

**Acceptance:** the final five skill contracts satisfy the frozen scope and E1–E15 checklist;
adversarial and security reviews approve; repository guardrails pass; tracked changes remain
limited to the five skills, ADR, specification, and plan.

## Progress

- Current step: model gate removed by operator decision; amended design awaiting review.
- Branch: `feat/divination-persistence-49`.
- Base: `main` at quest start.
- Guardrail: `just verify` (`just ci` in CI).
- Architecture: host `arm64`; no target declared; `no-target-declared`.
- ADR review: approved in cycle 2 iteration 1; no open findings.
- Specification review: prior revision approved; amended review pending.
- Open findings: none.
