# Reviewer dispatch isolation — design

Decision record:
[ADR 0058](../../adr/0058-review-dispatch-requires-no-parent-conversation.md).

## Goal

Make the isolation requirement explicit at every site that dispatches a reviewer or a read-only
worker, forbid the context-inheriting fork by name, and rewrite the two isolation claims that
depend on fresh context so they state that precondition instead of asserting the outcome. The
requirement binds to the documented property — a worker starting with no parent conversation —
and is satisfied by any dispatch mechanism providing it.

Scope is skill and reference prose. Mutating-worker dispatch — `$forge`'s Party implementers and
post-review fix worker, `$campaign`'s `$quest` workers — is an approved non-goal, as are any
script or harness change, any automated gate over the new prose (anatomy rule 4), and
`$summon-swarm`'s external `codex exec` workers, which are not harness subagents.

## Requirements

**R1.** `$trial-loop` step 1 dispatches a **fresh-context worker** — one starting with none of the
caller's conversation and none of its active skill instructions — and states that a fork
(`subagent_type: "fork"`) is not permitted, because it inherits the caller's active,
write-capable workflow instructions. The property is stated as *no parent conversation*, never as
an empty window: a non-fork subagent's context is documented as starting fresh but not empty, so a
requirement worded as "empty" is satisfied by nothing and blocks every review. One permitted value
is named as an example — `general-purpose` on Claude Code — marked as an illustration rather than
the contract, since a roster is per-installation and even that built-in can be disabled. Reusing a
prior pass's reviewer is forbidden too, on its own ground: that worker inherits its own findings
and verdict, which `$trial-loop`'s naivety rule already forbids. The single liveness probe
`references/dispatch-liveness.md` permits is not a dispatch and is unaffected.

**R2.** The requirement is satisfied by **any dispatch mechanism** whose worker starts with no
parent conversation — a named fresh-context subagent type, or a fresh non-interactive process of
the same agent — and only a harness offering none **stops as blocked**. A fork under a stronger
prompt is not a fallback: issue #334 records four forks overriding an explicit read-only prompt
four times out of four. Absence has a stated test — the harness's dispatch surface offers no
mechanism documented as starting a worker with no parent conversation, as against a model failing
to recognise a name on a roster it does have, or a qualifying mechanism spelled as a subcommand
rather than a type. The blocked rule is carried inline at the canonical site and in
`references/review-depth.md` only, unlike the fork prohibition of R4: it is a once-per-harness
precondition rather than a per-dispatch choice, and the clause a reader holds when it fires has
already sent them to step 1.

**R3.** The passage at `skills/trial-loop/SKILL.md` that today asserts the reviewer worker "is
read-only with respect to the target and git state" and that its context isolation "keeps the
loop from stacking a full payload per pass" is rewritten as precondition-plus-consequence. Each
property says what the absent inheritance buys and what restoring it costs. Neither reads
as something the prompt establishes.

**R4.** Every site that restates the dispatch inline carries a clause stating the fresh-context
requirement and the `fork` prohibition, and cites `$trial-loop` step 1 for the reason. **A site
restates inline when it gives any of brief contents, lens selection, or the retry rule without
citing the canonical recipe**. That test, not section proximity, decides membership. It runs over
reviewer and read-only-worker dispatch only — mutating dispatch, including `$restock` §3b's
build-and-test workers, is outside the contract's subject rather than exempted from it — and
within that population it selects every dispatch-composing site and exempts none. The eleven
sites are `references/review-depth.md` (**all three** — the single-pass dispatch and both bounded
design-artifact review dispatches), `skills/quest/SKILL.md` (**all three** — the `$oathbind`
scope audit, the `single-pass` branch review, and the `$detect-evil` security pass),
`skills/saga/SKILL.md` (draft review), `skills/spellcraft/SKILL.md` (**both** design-set review
dispatches), `skills/campaign/SKILL.md` (read-only triage workers), and `skills/forge/SKILL.md`
(whole-branch review). A clause may add a site-specific consequence beside the citation; it may
not substitute one for it.

**R5.** `skills/quest/SKILL.md`'s scope-audit paragraph currently ends "the workflow makes no
context-isolation guarantee". Under R1 it does make one at the dispatch type. That sentence is
replaced by an accurate statement of what the fresh-context type guarantees, rather than left
contradicting the new contract.

**R6.** `.claude-plugin/plugin.json` declares a version strictly greater than the base ref's
(ADR 0022). This change adds a normative constraint to an existing contract and removes no skill
and breaks no invocation, so the bump is `PATCH`.

## Architecture

Prose only. Seven files change plus the manifest; no executable, no gate, no new reference file.

`$trial-loop` step 1 is the contract's single canonical home. The eleven other dispatch sites all
restate the dispatch inline and each gain one clause, across six further files. No site inside the
contract's subject is exempt: the observed failure was a reader treating a by-reference sentence
as self-sufficient, so the clause belongs wherever such a dispatch call is composed, and a rule
with no exceptions is shorter to apply than one with a defended exemption.

The clauses say **worker**, not *subagent*. ADR 0011 already reserves `worker` for "a dispatched
agent or process", and `$summon-swarm` instructs readers to reserve `subagent` for a literal
harness capability, so a clause demanding a subagent is unfollowable where no such capability
exists. `subagent_type: "fork"` keeps the narrow noun, because there it names the capability
being forbidden.

`skills/forge/SKILL.md`'s "Subagents inherit nothing" is the same voidable assertion at a
mutating-worker site, inside the approved exclusion. It is carried as a follow-up candidate.

## Validation

The changed contract is mostly instruction text a model reads, and anatomy rule 4 forbids a gate
that asserts on prose. Two structural elements the change does add are machine-checkable, and
they take a focused mode rather than hiding behind the prose reason.

- **Contract: the `$invocation` tokens the new clauses add (R1, R4, R5).** Mode: `focused-test`.
  `scripts/check-skill-shape.sh` has seven rules, and rule 4 extracts every backticked
  `$invocation` from `skills/*/SKILL.md` and fails on one naming no skill. The clauses add
  `$quest` to `skills/trial-loop/SKILL.md` and `$trial-loop` to `skills/quest/SKILL.md` and
  `skills/spellcraft/SKILL.md`. Expected red: introduce a `` `$nonexistent-skill` `` token in an
  edited file and `just shape-check` exits non-zero naming it. Expected green after reverting the
  fault: `just shape-check` exits 0.
- **Contract: the normative sentences themselves (R1–R5).** Mode: `task-test-not-applicable`. The
  changed surface is prose in `skills/*/SKILL.md` and `references/review-depth.md`. Its only
  machine-checkable elements are the `$invocation` tokens above and the relative reference links
  rule 5 resolves, both already observed by `just shape-check`. The sentences carry no parser,
  schema, record shape, validation rule, or generated artifact, so a test that bit on them would
  have to assert on wording — the class anatomy rule 4 exists to forbid, and the one that produced
  the false reds retiring its 563-line predecessor.
- **Contract: the manifest version bump (R6).** Mode: `focused-test`. The observable contract is
  `scripts/check-plugin-version.sh`'s strictly-greater rule. Expected red: with
  `.claude-plugin/plugin.json` left at the base version and `BASE_SHA` set to the merge base,
  `just version-check` exits non-zero naming the unbumped version. Expected green after the bump:
  `BASE_SHA=$(git merge-base HEAD origin/main) just version-check` exits 0.
- **Whole-change gate.** `just verify` exits 0.
