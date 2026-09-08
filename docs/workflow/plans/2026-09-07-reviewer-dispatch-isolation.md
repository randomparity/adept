# Reviewer dispatch isolation — implementation plan

Derived from [the design](../specs/2026-09-07-reviewer-dispatch-isolation-design.md) and
[ADR 0058](../../adr/0058-review-dispatch-names-a-fresh-context-subagent.md).

**Goal.** Name the subagent type at every site that dispatches a reviewer or a read-only worker,
forbid the context-inheriting fork by name, and rewrite the two isolation claims that depend on
fresh context so they state that precondition instead of asserting the outcome.

**Architecture.** Prose only. `$trial-loop` step 1 becomes the contract's one canonical home and
gains the type constraint plus the blocked-harness rule; the passage that today asserts the two
dependent properties is rewritten as precondition-plus-consequence. Eleven further dispatch
sites, across six files, each gain a one-clause restatement at the point where they compose a
dispatch call. No site is exempt.
`.claude-plugin/plugin.json` takes the mandatory version bump.

**Tech stack.** Markdown only. No executable, no dependency, no build step, no new gate. The gate
is `just verify`.

**Expected implementation size: 80–110 changed lines (M) — summed from the file map below: about
45 changed lines in `skills/trial-loop/SKILL.md` across the two contract edits, about 4–16 per
file at the six inheriting files (eleven dispatch sites: three each in
`references/review-depth.md` and `skills/quest/SKILL.md`, two in `skills/spellcraft/SKILL.md`,
one each in the rest), and one line in `.claude-plugin/plugin.json`.**

The estimate sits well under the fixed `M` denominator because the band was frozen from the
change's cross-cutting contract hazard — one dispatch contract restated across seven files — not
from a line count, and the band is frozen before design in any case. The two measure different
things and are not reconciled by moving either.

## Global constraints

Transcribed from the design and the repository's `CLAUDE.md`:

- **Anatomy rule 4: nothing automated asserts on prose.** No gate greps Markdown for a sentence.
  This change adds no gate, and anatomy rule 1 means no supporting file either.
- Repository is public. No absolute checkout paths, hostnames, or host identity in committed
  text; plans and specs name the checkout root as `$WORK`.
- `.claude-plugin/plugin.json` declares the version and every change bumps it (ADR 0022). This
  change is `PATCH`: it adds a normative constraint to an existing contract, removes no skill,
  renames nothing, and breaks no invocation. Base version is `4.6.2`, so the tree declares
  `4.6.3`.
- Conventional commits, imperative mood, subject ≤ 72 characters, one logical change per commit,
  on `feat/specify-reviewer-subagent-type-334` in its sibling worktree — never on `main`.
- Run gates bare — no pipes that swallow an exit code, no `|| true`. `git push` re-runs all of
  `just verify` under the managed pre-push hook and regularly exceeds a two-minute tool timeout;
  that is slowness, not a hang.
- The approved exclusions are frozen: no mutating-worker dispatch site is edited
  (`$forge` Party implementers, `$forge`'s post-review fix worker, `$campaign`'s `$quest`
  workers), no script or harness file changes, and `$summon-swarm` is untouched.

## File map

| Path | Action | Answerable for |
|---|---|---|
| `skills/trial-loop/SKILL.md` | modify | the canonical dispatch-type contract and the two rewritten dependent properties |
| `references/review-depth.md` | modify | all three inline dispatches: the single pass and both bounded-review passes |
| `skills/quest/SKILL.md` | modify | the `$oathbind` scope-audit, `single-pass` branch-review, and `$detect-evil` security-pass dispatches |
| `skills/saga/SKILL.md` | modify | the draft-review dispatch |
| `skills/spellcraft/SKILL.md` | modify | both design-set review dispatches, first pass and second |
| `skills/campaign/SKILL.md` | modify | the read-only triage-worker dispatch |
| `skills/forge/SKILL.md` | modify | the whole-branch review dispatch |
| `.claude-plugin/plugin.json` | modify | the mandatory per-PR version bump |

## Task 1 — the canonical contract in `$trial-loop`

**Interfaces.** This task defines the phrase every later clause cites: a **fresh-context
subagent**, with `subagent_type: "fork"` named as the forbidden value and `$trial-loop` step 1
named as the place the reason lives. Task 2 consumes exactly those three tokens and introduces no
synonym for them.

**Where it fits.** `skills/trial-loop/SKILL.md` is the recipe four of the eleven other dispatch
sites already cite by name. Fixing it is what the chaining sites inherit; Task 2 covers the sites
that restate the dispatch inline and would otherwise read as self-sufficient.

**Files.** Modifies `skills/trial-loop/SKILL.md`. Creates and tests nothing.

### Verification

- **Contract: the `$quest` invocation token the step 1 replacement adds.** Mode: `focused-test`.
  `scripts/check-skill-shape.sh` rule 4 (lines 219-243) extracts every backticked `$invocation`
  from `skills/*/SKILL.md` and fails on one naming no skill. Expected red: temporarily change the
  replacement's `` `$quest` `` to `` `$nonexistent-skill` `` and run `just shape-check` — it exits
  non-zero with `$nonexistent-skill is invoked but no such skill exists`. Revert the fault.
  Expected green: `just shape-check` exits 0 and prints `check-skill-shape: 29 skills, all rules
  pass`.
- **Contract: the step 1 dispatch-type constraint and the two rewritten dependent properties, as
  normative sentences.** Mode: `task-test-not-applicable`. Beyond the invocation token above and
  the reference link to `dispatch-liveness.md` that rule 5 resolves — both covered by the focused
  entry and by step 3 — the changed surface is prose. It carries no parser, schema, record shape,
  validation rule, or generated artifact, so a test that bit on it would have to assert on
  wording, which anatomy rule 4 forbids.

### Steps — executed

Cycle 1 replaced step 1's opening and the two dependent-property paragraphs in
`skills/trial-loop/SKILL.md`. The committed file is the record of the exact wording, so the
verbatim before/after blocks that stood here are not repeated: they duplicated the source and,
after the cycle-2 re-freeze, contradicted it. Commit `3dc0241`. Task 3 supersedes part of that
wording.

**Acceptance criteria.** Step 1 of `$trial-loop` states the fresh-context requirement, names
`subagent_type: "fork"` as the forbidden instance, forbids reusing a prior pass's reviewer, and
stops as blocked where no qualifying mechanism exists. The two dependent properties each state
the precondition and name what restoring the inheritance costs. The `Write`-allowlist requirement
and the exact six-field compact object survive verbatim.

## Task 2 — the eleven inheriting dispatch sites and the version bump

**Interfaces.** Consumes Task 1's three tokens — `fresh-context subagent`, `subagent_type:
"fork"`, and `$trial-loop` step 1 as the citation — and introduces no synonym. Produces the
finished change; nothing later depends on it.

**Where it fits.** Each of these eleven sites composes a dispatch call inline, in wording a
reader can act on without following the chain to `$trial-loop` step 1 — the observed failure mode.
Three files carry more than one — `references/review-depth.md` and `skills/quest/SKILL.md` three
each, `skills/spellcraft/SKILL.md` two — so editing only the first in any of them would leave a
live synonym inside one file.

**Files.** Modifies `references/review-depth.md`, `skills/quest/SKILL.md`,
`skills/saga/SKILL.md`, `skills/spellcraft/SKILL.md`, `skills/campaign/SKILL.md`,
`skills/forge/SKILL.md`, `.claude-plugin/plugin.json`.

### Verification

- **Contract: the `$trial-loop` invocation tokens the clauses add to `skills/quest/SKILL.md` and
  `skills/spellcraft/SKILL.md`.** Mode: `focused-test`. Same rule 4 contract as Task 1. Expected
  red: temporarily change the step 4 replacement's `` `$trial-loop` `` to
  `` `$nonexistent-skill` `` in `skills/quest/SKILL.md` and run `just shape-check` — non-zero,
  naming it. Rule 4 scans `skills/*/SKILL.md` only, so the fault must go in a skill rather than
  in `references/review-depth.md`. Revert. Expected
  green: `just shape-check` exits 0 printing `check-skill-shape: 29 skills, all rules pass`.
- **Contract: the eleven inline dispatch clauses as normative sentences.** Mode:
  `task-test-not-applicable`. Beyond those invocation tokens, the changed surface is prose
  carrying no parser, schema, record shape, validation rule, or generated artifact; a test that
  bit on it would assert on wording, which anatomy rule 4 forbids.
- **Contract: the manifest version bump.** Mode: `focused-test`. The observable contract is rule
  3 of `scripts/check-plugin-version.sh` — the tree's version is strictly greater than the base
  ref's whenever the tree differs from `BASE_SHA` at all. Expected red, run before step 7 with
  `.claude-plugin/plugin.json` still at `4.6.2`:
  `BASE_SHA=$(git merge-base HEAD origin/main) just version-check` exits non-zero and names the
  version that did not increase. Expected green after step 7: the same command exits 0.

### Steps — executed

Cycle 1 added the inline clause at each of the eleven sites listed under **Files** above and
bumped the manifest. The committed files are the record of the exact wording. Commits `464dd41`
and `5abf658`.

**Acceptance criteria.** Each of the eleven sites carries the clause and cites `$trial-loop`
step 1. No mutating-worker dispatch site is edited. `skills/quest/SKILL.md` no longer claims the
workflow makes no context-isolation guarantee. `.claude-plugin/plugin.json` declares a version
strictly greater than the base ref's. `just verify` exits 0.

The positive per-file count that proves coverage:

```sh
rg --no-config -ic 'never a fork' skills/trial-loop/SKILL.md references/review-depth.md \
  skills/quest/SKILL.md skills/saga/SKILL.md skills/spellcraft/SKILL.md \
  skills/campaign/SKILL.md skills/forge/SKILL.md
```

Expect `1, 3, 3, 1, 2, 1, 1` in that order — twelve in total, the canonical clause plus the
eleven inline ones. A negative grep for the old wording is not the check: the pre-change
sentences share no common phrase, so one would pass vacuously while missing most of the sites.

## Task 3 — cycle-2 correction: bind to the property, not to a named type

**Interfaces.** Redefines the requirement Task 1 established. It becomes a worker with **no
parent conversation**, satisfied by any dispatch mechanism providing it. `subagent_type: "fork"`
remains the named forbidden instance and `$trial-loop` step 1 remains the citation target, so
Task 2's eleven inline clauses keep their wording except where they restate the absence test.

**Where it fits.** Cycle 1 wrote the absence test as *no type documented as starting with an empty
window*. No dispatch type is documented that way — a non-fork subagent's context is documented as
starting fresh, with no parent conversation, but not empty — so the test as written is satisfied
by nothing and would block every review on every harness, including the one it was written for.
This task corrects the property and widens the mechanism, under the re-frozen cycle-2
`WORK:SCOPE`.

**Files.** Modifies `skills/trial-loop/SKILL.md`, `references/review-depth.md`,
`.claude-plugin/plugin.json`. The nine inline clauses that do not restate the absence test are
unchanged, because the tokens they cite are unchanged.

### Verification

- **Contract: the corrected absence test, the widened mechanism, and the permitted example, as
  normative sentences.** Mode: `task-test-not-applicable`. The changed surface is prose carrying
  no parser, schema, record shape, validation rule, or generated artifact, so a test that bit on
  it would have to assert on wording — the class anatomy rule 4 forbids. The `$invocation` tokens
  and relative reference links this task leaves in place stay covered by `just shape-check`
  rules 4 and 5.
- **Contract: the manifest version bump.** Mode: `focused-test`. Rule 3 of
  `scripts/check-plugin-version.sh` — strictly greater than the base ref's whenever the tree
  differs from `BASE_SHA`. Expected red before the bump; expected green after.

### Steps

1. In `skills/trial-loop/SKILL.md` step 1, restate the requirement as a worker starting with **no
   parent conversation** rather than one whose window *starts empty*, and add one permitted
   example — `general-purpose` on Claude Code — marked as an illustration, with the caveat that
   the built-in can be disabled.
2. In the same step, replace the blocked-harness paragraph so its test asks whether the harness's
   dispatch surface offers any mechanism documented as starting a worker with no parent
   conversation — a named subagent type, or a fresh non-interactive process — rather than whether
   it names a type.
3. Apply the same two corrections at the one `references/review-depth.md` site that carries the
   blocked rule, under `## Running a single pass`. The two bounded design-artifact dispatches
   cite `$trial-loop` step 1 for the definition and restate no absence test, so they are
   unchanged.
4. Rewrite the two dependent-property paragraphs so their stated precondition matches.
5. Bump `.claude-plugin/plugin.json` to the next `PATCH`.
6. Run `just verify` bare.

**Acceptance criteria.** No *empty window* or *starts empty* phrasing remains as the stated
property anywhere in `skills/` or `references/`. The canonical site names exactly one permitted
example and marks it as an illustration rather than the contract. The blocked rule's test names
both qualifying mechanism kinds. `just verify` exits 0.

## Deferrals

None recorded by this design phase.
