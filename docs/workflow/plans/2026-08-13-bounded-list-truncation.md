# Implementation plan: bounded GitHub list truncation reporting

**Goal.** Make three maintenance skills report possible partial coverage whenever a bounded
GitHub list returns exactly its configured limit.

**Architecture.** This is an instruction-only contract change. Each existing one-shot list read
retains its workflow and gains an explicit or existing limit plus a local equality check whose
warning is carried into that workflow's report.

**Tech stack.** Markdown skill contracts, GitHub CLI examples, `just verify`.

**Design:** `docs/workflow/specs/2026-08-13-bounded-list-truncation-design.md`.
**Decision:** `docs/adr/0013-report-bounded-list-truncation.md`.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- Implementation is limited to `skills/restock/SKILL.md`,
  `skills/resurrection/SKILL.md`, and `skills/warding/SKILL.md`.
- Each of the four affected GitHub list reads uses explicit JSON fields and an explicit limit.
- Equality with the configured limit means possible truncation, not proven truncation.
- Bash 3.2 is the shell floor for command examples.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/bounded-list-truncation-40`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.

## File map

| File | Responsibility |
|---|---|
| `skills/restock/SKILL.md` | Bound Dependabot discovery and report its possible truncation |
| `skills/resurrection/SKILL.md` | Report open and closed issue-sweep truncation separately |
| `skills/warding/SKILL.md` | Report possible partial coverage of the open-issue staleness sweep |

## Pre-implementation scope check

Run `git branch --show-current`, `git status --short --untracked-files=all`, and read issue #40's
latest complete `WORK:SCOPE`. Require branch `feat/bounded-list-truncation-40`, no uncommitted
changes, and token `58D4B37E-9BCE-4C30-A45A-4BA5E261B3CE`. Stop on a mismatch.

## Task 1 — Establish the failing behavior

**Files:** read the three skill files; create no tracked file.

**Interfaces:** consumes the unchanged bounded-read instructions and produces review evidence for
spec cases E2–E5 and E7. Later tasks rely on that evidence to prove the prior contract could
silently present an at-limit population as complete.

### Step 1.1 — Run the before-change trace

Give a fresh read-only reviewer the three skill files and the at-limit cases E2–E5 and E7 from
the design. Ask it to record pass or fail, affected population, controlling lines, and a one-
sentence reason for each case. It must use only the supplied skill text and hypothetical counts,
without calling tools or GitHub.

Expected: E2–E5 and E7 fail. `restock` has no explicit limit, while `resurrection` and `warding`
have limits but no at-limit reporting contract.

## Task 2 — Bound and report Dependabot discovery

**Files:** modify `skills/restock/SKILL.md`.

**Interfaces:** consumes the open Dependabot PR JSON array. Produces the existing categorized list
plus a report warning when the array contains 500 rows. No later task consumes a new interface.

### Step 2.1 — Add the minimal restock contract

Add `--limit 500` to the Phase 1a `gh pr list` command. Immediately after the command, add:

```markdown
If the returned array contains 500 PRs, report that Dependabot discovery is possibly truncated
at the limit and that evaluation covers only the returned population. Carry that warning into the
final summary. Equality is conservative evidence of possible truncation; do not claim that another
PR exists.
```

Keep the zero-result stop and categorization behavior unchanged.

### Step 2.2 — Verify the restock behavior

Trace E1, E2, E8a, E9, and E10 with a fresh read-only reviewer. Expected: every blocking case
passes with controlling instruction lines; advisory cases introduce no tool call or pagination
loop.

Run `just shape-check`, `just public-safety`, and `git diff --check` bare.

Expected: every command exits 0.

Commit `skills/restock/SKILL.md` with `fix: report truncated Dependabot discovery`.

## Task 3 — Report resurrection sweep boundaries independently

**Files:** modify `skills/resurrection/SKILL.md`.

**Interfaces:** consumes separate open-issue and closed-issue arrays, each limited to 500 rows.
Produces independent possible-truncation notes in the reconciliation plan. No later task consumes
a new interface.

### Step 3.1 — Add open and closed population checks

After the open-issue command in step 2, add:

```markdown
Record the returned row count. If it is 500, mark the open-issue population as possibly truncated
at the limit and carry that named warning into the reconciliation plan; do not describe the open
sweep as complete.
```

After the closed-issue command in step 5, add:

```markdown
Evaluate this count independently from the open sweep. If it is 500, mark the closed-issue
population as possibly truncated at the limit and carry that named warning into the reconciliation
plan; do not describe the closed sweep as complete.
```

### Step 3.2 — Verify independent warnings

Trace E3–E5, E8b, and E8c with a fresh read-only reviewer. Expected: open-only, closed-only, and
simultaneous at-limit cases retain distinct warning identities; failed reads do not become partial
populations.

Run `just shape-check`, `just public-safety`, and `git diff --check` bare.

Expected: every command exits 0.

Commit `skills/resurrection/SKILL.md` with `fix: report truncated resurrection sweeps`.

## Task 4 — Report warding staleness coverage

**Files:** modify `skills/warding/SKILL.md`.

**Interfaces:** consumes the open-issue array limited to 500 rows. Produces the existing staleness
report plus a possible-partial-coverage warning. No later task consumes a new interface.

### Step 4.1 — Add the staleness sweep check

After the Sweep A open-issue command, add:

```markdown
If the returned array contains 500 issues, report that Sweep A is possibly truncated at the limit
and that staleness coverage may be partial. Do not infer or act on issues outside the returned
population.
```

Keep the existing status, epic, and open-PR filters unchanged.

### Step 4.2 — Verify warding behavior

Trace E6, E7, E8d, E9, and E10 with a fresh read-only reviewer. Expected: below-limit behavior is
unchanged, at-limit coverage is reported without inventing unseen issues, and failed reads do not
produce a staleness conclusion.

Run `just shape-check`, `just public-safety`, and `git diff --check` bare.

Expected: every command exits 0.

Commit `skills/warding/SKILL.md` with `fix: report truncated warding sweep`.

## Task 5 — Whole-change verification

**Files:** no planned edits; accepted review fixes remain within the frozen surface.

**Interfaces:** consumes all three completed contracts and produces branch-review and guardrail
evidence.

### Step 5.1 — Recheck scope and behavior

Read issue #40's latest complete `WORK:SCOPE` and require token
`58D4B37E-9BCE-4C30-A45A-4BA5E261B3CE`. Map all completion criteria to controlling skill lines.
Run the complete E1–E10 bounded human review and record pass/fail, affected population,
controlling lines, and a one-sentence reason per case.

Expected: E1–E8d pass; E9–E10 have no blocking behavior.

### Step 5.2 — Run repository guardrails

Run `just verify`, `git diff --check`, and `git status --short --untracked-files=all` bare.

Expected: every command exits 0 and the worktree is clean.

### Step 5.3 — Rollback and cleanup

Each implementation commit changes one skill and can be reverted independently. Review artifacts
stay outside the repository. A behavioral reviewer must not call GitHub or mutate repository
state.
