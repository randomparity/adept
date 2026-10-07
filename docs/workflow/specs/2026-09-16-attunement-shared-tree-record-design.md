# Attunement shared-tree record — design

## Problem

Attunement step 7 records anything only when an orchestrator disclosed that this agent
is one of several. An undisclosed session reaches none of its rules, including the
file-scope rule stopping it from mutating a checkout another agent is using — the case
CLAUDE.md's "treat any checkout you did not create as shared" governs.

## Scope

Add one unconditional probe at the start of step 7, run whether or not disclosure
happened. Reuse two commands already in reach: `git worktree list`, and step 4's
`git status --short --untracked-files=all` result (no second status call). Record a new
one-sided `SHARED_TREE` line, in step 2's `KEY<TAB>VALUE` shape, as raw counts rather
than a judged verdict: `siblings: <n> (<branch names, or none>); pre-existing dirty or
staged paths: <yes|no>`, or `unknown` when the probe cannot run. Counts, not a collapsed
`shared`/`solo` judgment, let a downstream reader weight a confirmed sibling worktree
above mere dirtiness, which is common and often this session's own already-approved
resumed work, not another agent's. Fails open like step 2's records. No policy
attaches: existing disclosed-case bullets (ADR/migration numbers, file scope, ADR
index, doc conflict zones) stay byte-for-byte unchanged; what the counts imply in the
undisclosed case is `$quest`'s/`$forge`'s own future work, per "Attunement records;
skills branch" (SKILL.md:69).

**No script.** `git worktree list` and reading back step 4's status are commands a model
issues directly and reliably inline, as step 4 already does. Anatomy rule 2 permits a
script only for an operation that would otherwise burn context or run inconsistently;
this probe does not clear that bar. Excluded: `skills/quest/SKILL.md:301-306`'s twin
rule (unfiled follow-up); `$quest`/`$forge` policy consuming `SHARED_TREE` (deferred,
issue's step 3); `references/dispatch-liveness.md` (different contract);
`skills/quest-log/` and `references/true-seeing.md` (sibling runs).

### Failure model

1. Actors: an interactive or unattended session working a checkout, disclosed or not; a
   `$campaign`-dispatched worker.
2. Invariants: another agent's in-flight uncommitted work; whole-tree tooling
   correctness a nested worktree or concurrent edit can break.
3. Accepted: probe cannot run (damaged repo) — records `unknown`, continues, as step 2
   already does. Raw counts cannot attribute a cause (own resumed work, another agent,
   a stale worktree) — accepted; the record states the observation, not attribution.
4. Covered elsewhere: what an observed sibling worktree or dirty state requires the
   session to do is `$quest`'s/`$forge`'s future work (excluded above); the
   undisclosed-case file-scope gap stays open, part of that same deferred work.

## Success

- Step 7 emits `SHARED_TREE` on every run, dispatched or not.
- Its value reports raw sibling/dirty counts, plus `unknown`, fail-open like step 2.
- No script added; existing step 7 bullets unchanged; new content is additive only.

## Validation

- Contract: step 7 unconditionally emits `SHARED_TREE` in the stated `siblings: <n>
  (<names>); pre-existing dirty or staged paths: <yes|no>` / `unknown` shape, failing
  open. Mode: task-test-not-applicable — prose has no executable check; anatomy rule 4
  disallows a gate here by convention.
- Contract: existing disclosed-case bullets (~204-232) stay unchanged. Mode:
  task-test-not-applicable — verified by diff review, not a structural property.
