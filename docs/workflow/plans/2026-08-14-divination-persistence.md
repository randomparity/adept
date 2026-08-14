# Durable divination assessment implementation plan

**Goal.** Persist `$divination` assessments as authenticated `WORK:DIVINATION` issue annotations
and let `$quest` and `$bounty decompose` adopt a fresh, fully revalidated assessment.

**Architecture.** ADR 0015 separates advisory assessment evidence from quest's frozen
`WORK:SCOPE` authority. The producer publishes one authenticated, source-bound annotation;
consumers select latest-complete first, then authenticate and validate the whole assessment or
fall back to their existing local reasoning. The reviewed specification owns the exact annotation,
fingerprint, citation, failure, threat, and evaluation contracts.

**Tech stack.** Markdown skill contracts, `gh`, `git`, `jq`, SHA-256, prompt-level behavioral
evaluation under ignored `.agent/evals/`, and repository shell guardrails through `just`.

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
- Use the exact annotation shape, fingerprint protocol, evidence grammar, failure contract, E1–E13
  packets, and response schema from the reviewed specification.
- Evaluation artifacts remain ignored and are never committed.

## Task 1 — Establish failing behavioral evidence

**Files:** create ignored `.agent/evals/issue-49-packets/*.json`, baseline capture envelopes, and
one evaluator result. Modify no tracked file.

**Interfaces:** consumes the specification's base object, RFC 7396 case patches, materialization
overrides, exact hashes, worker response schema, and E1–E13 table. Produces a structurally valid
baseline result and immutable packet hashes reused by Task 3.

1. Verify `.agent/evals/` is ignored with `git check-ignore -q .agent/evals/probe`.
2. Materialize E1–E13 exactly, including both E11 packets. Serialize sorted-key UTF-8 JSON with
   two-space indentation and one newline; record SHA-256 for each.
3. Deterministically validate every composed packet: required fields, expected fresh/stale class,
   per-field evidence, repository-reference existence, E5 canaries, E10 hash/path, E11 split and
   broken-reference pair, and explicit E6/E13 producer workflows.
4. Dispatch one fresh most-capable scenario worker per packet with the neutral request and current
   bytes of `skills/divination/SKILL.md`, `skills/quest/SKILL.md`,
   `skills/quest-log/SKILL.md`, and `skills/bounty/SKILL.md`. Capture the exact response envelope.
5. Dispatch one different most-capable evaluator with the reviewed rubric. Require a complete
   schema and at least one blocking trait failure. Malformed evidence is rerun, not accepted as red.

**Acceptance:** valid baseline aggregate `fail`; packets and captures are ignored; tracked tree is
unchanged.

## Task 2 — Implement the durable producer and consumers

**Files:** modify `skills/divination/SKILL.md`, `skills/quest-log/SKILL.md`,
`skills/quest/SKILL.md`, and `skills/bounty/SKILL.md`.

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
   four fields or derive all four locally. Never use assessment content for the eight charter
   fields.
4. In `skills/bounty/SKILL.md` decompose mode, apply the same whole-block validation. Use a valid
   assessment, including `split`, as drafting evidence; otherwise preserve existing reasoning.
5. Sweep direct references with `rg -n '\$divination|WORK:DIVINATION|in-session only|read-only' skills
   docs/cheatsheet.md` and fix only stale claims within the chartered surface.
6. Run `git diff --check`, `just shape-check`, `just public-safety`, and `just commit-check`; expect
   exit 0. Commit as `docs(skills): persist divination assessments`.

**Acceptance:** producer and both consumers implement the same exact contract; no helper,
dependency, label behavior, historical migration, or scope-authority change is introduced.

## Task 3 — Prove behavior and repository integrity

**Files:** create a fresh ignored post-change evaluation directory; change tracked skill files
only when evidence exposes an in-scope defect.

**Interfaces:** reuses Task 1's exact packet bytes and hashes. Produces complete post-change
captures, evaluator result, and repository guardrail evidence for the shipping review.

1. Repeat Task 1's workers and independent evaluation against the implemented skill bytes, using
   the same selectable models/settings and new run ids. Require all E1–E13 traits to pass.
2. Run deterministic response checks: schema/expected booleans, E5 canary absence, E10 full hash
   and delimiter path, E11 valid/invalid adoption split, and E6/E13 producer persistence failures.
3. If any tracked edit follows evaluation, commit the logical repair and repeat the entire
   post-change evaluation against the new HEAD.
4. Run `git diff --check` and `just verify` bare; expect zero warnings and exit 0.
5. Record branch, base, evaluated commit, model identities, packet hashes, evaluator verdict,
   guardrail result, and open findings in the quest review summary. Keep ignored artifacts until
   all branch/security/simplification reviews finish, then move only issue-49 artifacts to trash.

**Acceptance:** E1–E13 pass, all deterministic assertions pass, `just verify` passes, and the diff
contains only chartered skill and durable design files.

**Rollback:** before push, ordinary commits may be reverted newest-first. After push, use new
`git revert` commits; never rewrite history. ADR 0015 and its reviewed specification remain the
durable decision record unless superseded by a new ADR.

## Progress

- Current step: implementation plan awaiting adversarial review.
- Branch: `feat/divination-persistence-49`.
- Base: `main` at quest start.
- Guardrail: `just verify` (`just ci` in CI).
- Architecture: host `arm64`; no target declared; `no-target-declared`.
- ADR review: approved in cycle 2 iteration 1; no open findings.
- Specification review: approved in resumed cycle iteration 2; no open findings.
- Open findings: none.
