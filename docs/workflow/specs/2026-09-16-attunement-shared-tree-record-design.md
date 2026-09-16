# Attunement shared-tree record — design

## Problem

Attunement step 7 only records anything when an orchestrator disclosed that this agent
is one of several. An ordinary, undisclosed session reaches none of its rules, including
the file-scope rule that stops it mutating a checkout another agent is using — the exact
case CLAUDE.md's "treat any checkout you did not create as shared" already governs.

## Scope

Add one unconditional probe at the start of step 7, run whether or not disclosure
happened. Reuse two commands already in reach: `git worktree list`, and step 4's
`git status --short --untracked-files=all` result (no second status call). Record a new
one-sided `SHARED_TREE` line, in step 2's `KEY<TAB>VALUE` shape: `shared (<evidence>)`
when `git worktree list` names a sibling worktree beyond this checkout, or step 4 found
dirty/staged paths; `solo` when neither holds; `unknown` when the probe cannot run.
Fails open like step 2's records — `unknown` never blocks attunement.

No policy attaches to the record: existing disclosed-case bullets (ADR/migration
numbers, file scope, ADR index, doc conflict zones) are unchanged, byte for byte. What a
`shared` value forbids in the undisclosed case is `$quest`'s/`$forge`'s own future work,
per "Attunement records; skills branch" (SKILL.md:69).

**No script.** `git worktree list` and reading back step 4's already-collected status are
commands a model already issues directly and reliably inline — step 4 is this exact
shape. Anatomy rule 2 permits a script only for a deterministic operation that would
otherwise burn context or run inconsistently; a two-command, three-way probe does not
clear that bar. Excluded: `skills/quest/SKILL.md:301-306`'s twin rule (separate, unfiled
follow-up); `$quest`/`$forge` policy consuming `SHARED_TREE` (deferred, issue's own step
3); `references/dispatch-liveness.md` (different, dispatcher-side contract);
`skills/quest-log/` and `references/true-seeing.md` (concurrent sibling runs).

### Failure model

1. Actors: an interactive or unattended session working a checkout, disclosed or not; a
   `$campaign`-dispatched worker.
2. Invariants: another agent's in-flight uncommitted work; whole-tree tooling
   correctness a nested worktree or concurrent edit can break.
3. Accepted: probe cannot run (damaged repo) — records `unknown`, continues, as step 2
   already does. `solo` can miss sharing git cannot see (a separate clone, not a linked
   worktree) — accepted; the record's own text scopes it to worktree-linked sharing only.
4. Covered elsewhere: what a `shared` verdict requires the session to do is
   `$quest`/`$forge`'s future policy work (excluded above); file scope is step 7's
   existing disclosed-case bullet.

## Success

- Step 7 emits `SHARED_TREE` on every run, dispatched or not.
- Its values (`shared (...)`, `solo`, `unknown`) and fail-open behavior mirror step 2.
- No script added; existing step 7 bullets unchanged; new content is additive only.

## Validation

- Contract: step 7 unconditionally emits `SHARED_TREE`. Mode: task-test-not-applicable —
  reason: SKILL.md prose has no executable or structural check; anatomy rule 4 disallows
  a gate here by convention.
- Contract: existing disclosed-case bullets (~204-232) stay unchanged. Mode:
  task-test-not-applicable — reason: verified by diff review, not a
  structural/executable property, per the same anatomy rule 4.
