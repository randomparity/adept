# Reviewer dispatch isolation — implementation plan

Derived from [the design](../specs/2026-09-07-reviewer-dispatch-isolation-design.md) and
[ADR 0058](../../adr/0058-review-dispatch-names-a-fresh-context-subagent.md).

**Goal.** Name the subagent type at every site that dispatches a reviewer or a read-only worker,
forbid the context-inheriting fork by name, and rewrite the two isolation claims that depend on
fresh context so they state that precondition instead of asserting the outcome.

**Architecture.** Prose only. `$trial-loop` step 1 becomes the contract's one canonical home and
gains the type constraint plus the blocked-harness rule; the passage that today asserts the two
dependent properties is rewritten as precondition-plus-consequence. Six further files each gain a
one-clause restatement at the point where they compose a dispatch call. Sites that only chain to
step 1 inherit the fix and are not edited. `.claude-plugin/plugin.json` takes the mandatory
version bump.

**Tech stack.** Markdown only. No executable, no dependency, no build step, no new gate. The gate
is `just verify`.

**Expected implementation size: 75–100 changed lines (M) — summed from the file map below: about
40 changed lines in `skills/trial-loop/SKILL.md` across the two contract edits, about 4–5 each at
the six inheriting sites, and one line in `.claude-plugin/plugin.json`.**

The estimate sits well under the fixed `M` denominator because the band was frozen from the
change's cross-cutting contract hazard — one dispatch contract restated across seven files — not
from a line count. The two measure different things and are not reconciled by moving either.

## Global constraints

Transcribed from the design and the repository's `CLAUDE.md`:

- **Anatomy rule 4: nothing automated asserts on prose.** No gate greps Markdown for a sentence;
  no test pins a table row. This change adds no gate of any kind.
- **Anatomy rule 1: a skill is instructions, not a program.** No supporting file is added.
- Repository is public. No absolute checkout paths, hostnames, or host identity in committed
  text; plans and specs name the checkout root as `$WORK`.
- `.claude-plugin/plugin.json` declares the version and every change bumps it (ADR 0022). This
  change is `PATCH`: it adds a normative constraint to an existing contract, removes no skill,
  renames nothing, and breaks no invocation. Base version is `4.6.2`, so the tree declares
  `4.6.3`.
- Conventional commits, imperative mood, subject ≤ 72 characters, one logical change per commit.
  Never commit to `main`; work happens on `feat/specify-reviewer-subagent-type-334` in its
  sibling worktree.
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
| `references/review-depth.md` | modify | the single-pass dispatch's own restatement of the type |
| `skills/quest/SKILL.md` | modify | the `$oathbind` scope-audit dispatch and the `$detect-evil` security-pass dispatch |
| `skills/saga/SKILL.md` | modify | the draft-review dispatch |
| `skills/spellcraft/SKILL.md` | modify | the design-set review dispatch |
| `skills/campaign/SKILL.md` | modify | the read-only triage-worker dispatch |
| `skills/forge/SKILL.md` | modify | the whole-branch review dispatch |
| `.claude-plugin/plugin.json` | modify | the mandatory per-PR version bump |

## Task 1 — the canonical contract in `$trial-loop`

**Interfaces.** This task defines the phrase every later clause cites: a **fresh-context
subagent**, with `subagent_type: "fork"` named as the forbidden value and `$trial-loop` step 1
named as the place the reason lives. Task 2 consumes exactly those three tokens and introduces no
synonym for them.

**Where it fits.** `skills/trial-loop/SKILL.md` is the recipe four of the seven other dispatch
sites already cite by name. Fixing it is what the chaining sites inherit; Task 2 covers the sites
that restate the dispatch inline and would otherwise read as self-sufficient.

**Files.** Modifies `skills/trial-loop/SKILL.md`. Creates and tests nothing.

### Verification

- **Contract: the step 1 dispatch-type constraint and the two rewritten dependent properties.**
  Mode: `task-test-not-applicable`. No executable in this repository consumes a `SKILL.md` body —
  `scripts/check-skill-shape.sh` reads frontmatter `name:`, directory agreement, and
  relative-link resolution only. This task adds no link, no frontmatter field, and no structural
  element, so no task-specific executable or structural observation could fail meaningfully. A
  test asserting a sentence is present is the class anatomy rule 4 forbids.

### Steps

1. In `skills/trial-loop/SKILL.md`, find the step 1 opening, which reads exactly:

   ```
   1. **Petition the council** — read the installed selected reviewer in full, then run it in a
      **subagent** with
      `--json --out <findings-path> <challenge-args>`, then the exact
      `CHARTER` block above as the labeled trailing block.
   ```

   Replace it with:

   ```
   1. **Petition the council** — read the installed selected reviewer in full, then run it in a
      **fresh-context subagent** with
      `--json --out <findings-path> <challenge-args>`, then the exact
      `CHARTER` block above as the labeled trailing block.

      **Fresh-context is the type, not a preference.** Dispatch a subagent type whose window
      starts empty — inheriting none of this session's conversation and none of its active skill
      instructions. **Never a fork** (`subagent_type: "fork"`), and never a resume of an agent
      this run already dispatched. Both inherit the caller's context, and with it the caller's
      *active, write-capable workflow instructions*: a fork dispatched from inside `$quest` reads
      `$quest`'s own text telling it to apply fixes, commit, push and hand off, and follows it.
      Observed four times out of four on randomparity/adept#334, under a dispatch prompt that
      said "no correctness review, no git/PR/merge actions" in those words. The prompt is not the
      layer where this holds. Where the harness offers no fresh-context type, **stop as blocked**
      and report that it cannot carry a review dispatch; a fork under a stronger prompt is not
      the fallback.
   ```

2. In the same file, find the passage that begins `The reviewer worker is read-only with respect
   to the target and git state` and ends `keeps the loop from stacking a full payload per pass in
   the caller's window.` Replace the whole passage with:

   ```
      **Two properties this loop depends on hold because step 1 dispatched a
      fresh-context subagent, and only because of that.** Each is written below as what
      the empty window buys and what restoring the inheritance costs. A reader who
      satisfies them by telling the worker to be read-only has satisfied neither.

      *Read-only with respect to the target and git state.* A window that starts empty
      carries no instruction to commit, push, or ship, so the only workflow the worker
      can act on is the one its own prompt gives it. Restore the inheritance and the
      prompt loses to it. The single write it does make is the findings file, so **its
      tool allowlist must include `Write`** — `--out` writes that file (the selected
      reviewer's sole write exception); without `Write`, `--out` silently no-ops and the
      loop dead-ends.

      *Payload isolation.* The worker's context (not this one) holds the full findings;
      it returns only `{verdict, findings_count, blocking_count, suppressed_count, path,
      run_id}` — `run_id` included, because steps 4 and 5 assert it against the artifact
      and a four-field contract degrades that check to a no-op. What that buys is a
      caller window carrying verdicts instead of payloads, one pass after another. A
      worker that inherited the caller's window has already spent the saving, whatever
      it returns.
   ```

3. Run the fast structural gates bare and read their exit status:

   ```sh
   just shape-check && just public-safety
   ```

   Expect both to exit 0 and print no error line.

**Acceptance criteria.** Step 1 of `$trial-loop` names `fresh-context subagent`, names
`subagent_type: "fork"` as forbidden, forbids resuming an already-dispatched agent, and stops as
blocked where no fresh-context type exists. The two dependent properties each state the empty
window as their precondition and name what restoring the inheritance costs. The `Write`-allowlist
requirement and the exact six-field compact object survive verbatim.

## Task 2 — the six inheriting sites and the version bump

**Interfaces.** Consumes Task 1's three tokens — `fresh-context subagent`, `subagent_type:
"fork"`, and `$trial-loop` step 1 as the citation — and introduces no synonym. Produces the
finished change; nothing later depends on it.

**Where it fits.** Each of these files composes a dispatch call inline, in wording a reader can
act on without following the chain to `$trial-loop` step 1 — the observed failure mode.

**Files.** Modifies `references/review-depth.md`, `skills/quest/SKILL.md`,
`skills/saga/SKILL.md`, `skills/spellcraft/SKILL.md`, `skills/campaign/SKILL.md`,
`skills/forge/SKILL.md`, `.claude-plugin/plugin.json`.

### Verification

- **Contract: the seven inline dispatch clauses.** Mode: `task-test-not-applicable`. Same surface
  and same reason as Task 1: normative instruction prose no executable consumes, adding no link,
  frontmatter field, or structural element `just shape-check` could observe.
- **Contract: the manifest version bump.** Mode: `focused-test`. The observable contract is rule
  3 of `scripts/check-plugin-version.sh` — the tree's version is strictly greater than the base
  ref's whenever the tree differs from `BASE_SHA` at all. Expected red, run before step 7 with
  `.claude-plugin/plugin.json` still at `4.6.2`:
  `BASE_SHA=$(git merge-base HEAD origin/main) just version-check` exits non-zero and names the
  version that did not increase. Expected green after step 7: the same command exits 0.

### Steps

1. In `references/review-depth.md`, under `## Running a single pass`, replace
   `Dispatch the reviewer in a subagent exactly as `$trial-loop` step 1 does — the` with:

   ```
   Dispatch the reviewer in a fresh-context subagent exactly as `$trial-loop` step 1 does —
   never a fork, and stop as blocked where the harness offers no fresh-context type; the
   ```

2. In `skills/quest/SKILL.md`, step 4, replace the sentence

   ```
   Pick a fresh report path there and dispatch a fresh reviewer task running
   `$oathbind` -- no prior verdicts, proposed fixes, or review history in its
   brief. Inherited history is non-authoritative and cannot supply scope; the
   workflow makes no context-isolation guarantee.
   ```

   with:

   ```
   Pick a fresh report path there and dispatch a fresh-context subagent running
   `$oathbind` -- never a fork, per `$trial-loop` step 1 -- with no prior verdicts,
   proposed fixes, or review history in its brief. Inherited history is
   non-authoritative and cannot supply scope, and the fresh-context type is what
   makes the brief the whole of what the auditor has.
   ```

3. In `skills/quest/SKILL.md`, step 6, replace

   ```
   Dispatch it the way `$trial-loop` dispatches its reviewer -- a subagent running
   ```

   with:

   ```
   Dispatch it the way `$trial-loop` dispatches its reviewer -- a fresh-context subagent,
   never a fork, for the reason step 1 of that skill gives -- running
   ```

4. In `skills/saga/SKILL.md`, step 5, replace

   ```
   Write the draft to a scratchpad temp file. Dispatch `$gauntlet` on it as a read-only
   subagent per `$trial-loop`'s dispatch recipe (`--json --out` to a scratchpad path —
   one pass, not the loop).
   ```

   with:

   ```
   Write the draft to a scratchpad temp file. Dispatch `$gauntlet` on it per
   `$trial-loop`'s dispatch recipe (`--json --out` to a scratchpad path — one pass, not
   the loop), in a fresh-context subagent and never a fork: step 1 of that recipe gives
   the reason read-only depends on the type rather than on the prompt.
   ```

5. In `skills/spellcraft/SKILL.md`, under `### Run the review`, replace

   ```
   Dispatch `$gauntlet` in a fresh worker using the bounded design-artifact recipe
   ```

   with:

   ```
   Dispatch `$gauntlet` in a fresh-context subagent — never a fork, per `$trial-loop`
   step 1 — using the bounded design-artifact recipe
   ```

6. In `skills/campaign/SKILL.md`, step 3, replace
   `**Dispatch read-only triage workers** (up to 5 parallel).` with:

   ```
   **Dispatch read-only triage workers** (up to 5 parallel), each a fresh-context subagent
   and never a fork: a fork inherits this orchestrator's context, and with it the dispatch,
   merge, and label authority a triage worker must not have.
   ```

7. In `skills/forge/SKILL.md`, replace

   ```
   Then dispatch the whole-branch review with
   [code-reviewer.md](code-reviewer.md), on the most capable model. It is the
   branch's only adversarial pass.
   ```

   with:

   ```
   Then dispatch the whole-branch review with
   [code-reviewer.md](code-reviewer.md), on the most capable model, in a fresh-context
   subagent — never a fork, which would carry this run's own build instructions into the
   one worker whose job is to disbelieve them. It is the branch's only adversarial pass.
   ```

8. Confirm the expected red for the version contract, before editing the manifest:

   ```sh
   BASE_SHA=$(git merge-base HEAD origin/main) just version-check
   ```

   Expect a non-zero exit naming `4.6.2` as not greater than the base version.

9. In `.claude-plugin/plugin.json`, change `"version": "4.6.2"` to `"version": "4.6.3"`.

10. Confirm the expected green, then run the whole gate suite bare:

    ```sh
    BASE_SHA=$(git merge-base HEAD origin/main) just version-check
    just verify
    ```

    Expect the first to exit 0 and `just verify` to exit 0 with every suite reporting `ok`.

**Acceptance criteria.** Each of the six files names the fresh-context type and the `fork`
prohibition at the point it composes a dispatch, using Task 1's tokens without synonym. No
mutating-worker dispatch site is edited. `skills/quest/SKILL.md` no longer claims the workflow
makes no context-isolation guarantee. `.claude-plugin/plugin.json` declares `4.6.3`. `just
verify` exits 0.

## Deferrals

None recorded by this design phase.
