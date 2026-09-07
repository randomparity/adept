# Reviewer dispatch isolation — design

Decision record:
[ADR 0058](../../adr/0058-review-dispatch-names-a-fresh-context-subagent.md).

## Goal

Make the subagent type explicit at every site that dispatches a reviewer or a read-only worker,
forbid the context-inheriting fork by name, and rewrite the two isolation claims that depend on
fresh context so they state that precondition instead of asserting the outcome.

Scope is skill and reference prose. Mutating-worker dispatch — `$forge`'s Party implementers and
post-review fix worker, `$campaign`'s `$quest` workers — is an approved non-goal, as are any
script or harness change, any automated gate over the new prose (anatomy rule 4), and
`$summon-swarm`'s external `codex exec` workers, which are not harness subagents.

## Requirements

**R1.** `$trial-loop` step 1 dispatches a **fresh-context subagent** — a worker whose window
inherits none of the caller's conversation or active skill instructions — and states that a fork
(`subagent_type: "fork"`) is not permitted, because it inherits the caller's active,
write-capable workflow instructions. Resuming an agent this run already dispatched is forbidden
on the same ground.

**R2.** Where the harness offers no fresh-context type, the dispatch **stops as blocked**. A fork
under a stronger prompt is not a fallback: issue #334 records four forks overriding an explicit
read-only prompt four times out of four.

**R3.** The passage at `skills/trial-loop/SKILL.md` that today asserts the reviewer worker "is
read-only with respect to the target and git state" and that its context isolation "keeps the
loop from stacking a full payload per pass" is rewritten as precondition-plus-consequence. Each
property says what the empty window buys and what restoring the inheritance costs. Neither reads
as something the prompt establishes.

**R4.** Every site that restates the dispatch inline carries a clause naming the fresh-context
type and the `fork` prohibition, and cites `$trial-loop` step 1 for the reason. Those sites are
`references/review-depth.md` (single-pass dispatch), `skills/quest/SKILL.md` (the `$oathbind`
scope audit and the `$detect-evil` security pass), `skills/saga/SKILL.md` (draft review),
`skills/spellcraft/SKILL.md` (design-set review), `skills/campaign/SKILL.md` (read-only triage
workers), and `skills/forge/SKILL.md` (whole-branch review). A site that only chains to step 1
without restating the dispatch inherits the fix and is not edited.

**R5.** `skills/quest/SKILL.md`'s scope-audit paragraph currently ends "the workflow makes no
context-isolation guarantee". Under R1 it does make one at the dispatch type. That sentence is
replaced by an accurate statement of what the fresh-context type guarantees, rather than left
contradicting the new contract.

**R6.** `.claude-plugin/plugin.json` declares a version strictly greater than the base ref's
(ADR 0022). This change adds a normative constraint to an existing contract and removes no skill
and breaks no invocation, so the bump is `PATCH`.

## Architecture

Prose only. Seven files change plus the manifest; no executable, no gate, no new reference file.

`$trial-loop` step 1 is the contract's single canonical home. The seven other dispatch sites all
restate the dispatch inline and each gain one clause, across six further files. Sites that only
chain — the two inner dispatches of `references/review-depth.md`'s bounded design-artifact
review — inherit the fix unedited. That split is deliberate: the observed failure was a reader
treating a by-reference sentence as self-sufficient, so the clause belongs where the dispatch
call is composed.

`skills/forge/SKILL.md:607` ("Subagents inherit nothing") is the same voidable assertion at a
mutating-worker site, inside the approved exclusion. It is carried as a follow-up candidate.

## Validation

The changed contract is instruction text a model reads. Anatomy rule 4 forbids a gate that
asserts on prose, and this change introduces no parser, schema, record shape, or generated
artifact.

- **Contract: the fresh-context dispatch constraint and the two rewritten isolation properties
  (R1–R5).** Mode: `task-test-not-applicable`. The changed surface is normative prose in
  `skills/*/SKILL.md` and `references/review-depth.md`. No executable consumes it: the repository
  has no runtime that parses skill body text, and the one structural property this change could
  break — that relative reference links resolve — is already covered by
  `scripts/check-skill-shape.sh` rule 5, run by `just shape-check`. A test asserting that a
  sentence is present is the class anatomy rule 4 exists to forbid, and produced the false reds
  that retired its 563-line predecessor.
- **Contract: the manifest version bump (R6).** Mode: `focused-test`. The observable contract is
  `scripts/check-plugin-version.sh`'s strictly-greater rule. Expected red: with
  `.claude-plugin/plugin.json` left at the base version and `BASE_SHA` set to the merge base,
  `just version-check` exits non-zero naming the unbumped version. Expected green after the bump:
  `BASE_SHA=$(git merge-base HEAD origin/main) just version-check` exits 0.
- **Whole-change gate.** `just verify` exits 0.
