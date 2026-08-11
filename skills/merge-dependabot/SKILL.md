---
name: merge-dependabot
description: "Audit Dependabot configuration, evaluate open dependency-update pull requests against a clean baseline, group overlapping updates, test each unit, and merge only verified safe updates serially. Use when asked to review, batch, or merge Dependabot PRs for a GitHub repository."
---
# Merge Dependabot PRs


Clone $REPO if not already available locally:

```bash
REPO_DIR=/tmp/depbot-eval-$(echo "$REPO" | tr '/' '-')
gh repo clone "$REPO" "$REPO_DIR" -- --filter=blob:none 2>/dev/null || {
  cd "$REPO_DIR" || exit 1
  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --unshallow origin
  fi
  git fetch origin
}
```

`--filter=blob:none` fetches every commit and tree but defers file contents until
a checkout needs them, so the clone stays cheap while keeping complete history.
Complete history is not optional here: every later phase compares a fetched PR
head against the default branch — `git diff "$DEFAULT_BRANCH"...pr-{n}` in Phase 3,
`git merge pr-{n}` for batches, `git merge "$DEFAULT_BRANCH"` in Phase 4a — and each
of those needs a **merge base**. A depth-capped clone truncates history at grafted
boundary commits, so once a PR's base falls outside the cap, its head shares no
reachable ancestor with the default branch and each of those commands fails with
`fatal: <branch>...pr-{n}: no merge base`. The cap is what makes this intermittent
rather than obvious — it holds until a PR is branched from far enough back, then
breaks the run with no recovery step the skill specifies.

The `--unshallow` in the fallback is for a clone left behind by an earlier run of
this skill: `/tmp/depbot-eval-*` persists between runs, a plain `git fetch` on a
shallow repo keeps it shallow, and the failure above would survive the fix.

Work from `/tmp/depbot-eval-{repo-slug}` for all subsequent phases.

## Resolve the default branch and merge method (before Phase 0)

Two repo facts govern every phase below, and one call returns both. Resolve them
here rather than at first use — Phase 0 already checks out the default branch, so
a lookup deferred to Phase 1c comes too late for it.

```bash
gh repo view "$REPO" \
  --json defaultBranchRef,rebaseMergeAllowed,mergeCommitAllowed,squashMergeAllowed
```

`gh repo view` takes the repo as a **positional** argument — it has no `--repo`
flag and exits `1` with `unknown flag: --repo` if given one, unlike the
`gh pr`/`gh issue` commands elsewhere in this file.

- **`$DEFAULT_BRANCH`** — `.defaultBranchRef.name`. Every `git checkout`,
  `git merge`, `git diff`, and `git worktree add` below uses this, never a literal
  `main`. On a repo whose default branch is `master`, `trunk`, or `develop`, a
  literal breaks the run at the first checkout.
- **`$MERGE_FLAG`** — the first merge method this repo allows, in this order:

  | Allowed | Flag |
  |---|---|
  | `rebaseMergeAllowed` | `--rebase` |
  | `mergeCommitAllowed` | `--merge` |
  | `squashMergeAllowed` | `--squash` |

  Rebase is first because it satisfies the no-squash-code-PRs rule in
  `merge-cleanup.md` and both `AGENTS.md` files without needing an exception, and
  on the common single-commit dependabot PR it produces exactly the history
  `--squash` would. Where a PR carries more than one commit — a grouped update, or
  a bump dependabot had to rebase and fix up — rebase keeps each commit bisectable.
  Squash is last rather than forbidden: a repo that allows nothing else leaves no
  alternative. If the repo allows none of the three, **stop the run** and report
  that merging is disabled for `$REPO`; evaluating PRs you cannot merge wastes the
  whole pass.

Execute every phase below sequentially. Do not stop or ask for
confirmation at any phase.

## Binding rules (read first — these survive head-first truncation; the phase detail below does not)

- **Caller contract.** Run every phase in order without stopping for
  confirmation (but honor the hard stops below); completing a phase means
  proceed to the next.
- **Merge authorization & boundary.** Merge **only** work units with a
  `PASS` verdict (approve, then merge with `$MERGE_FLAG` per Phase 4a).
  **Never merge `WARN` or `FAIL`** — those go to the final report for human
  review (Phase 4b). Re-test each unit on the updated default branch before
  merging it; if it then fails, mark it `SKIPPED` and do not merge.
- **Never `--admin`.** Do not pass `--admin` (or otherwise bypass branch
  protection) on any merge. It skips **required status checks**, not just
  approvals, so it would merge a PR whose CI is red on the strength of this
  command's local build — and Phase 3 Step 5 exists precisely because that local
  build cannot cover the CI matrix. Approvals are already satisfiable without it:
  dependabot is the PR author, so the Phase 4a approval counts. A refused merge is
  a `BLOCKED` outcome to report, never a reason to retry with `--admin`.
- **Stop conditions.** **Abort the whole run** if the default-branch baseline
  build or tests fail (Phase 1c — fix the default branch first), the repo allows
  no merge method at all, or there are no open dependabot PRs (Phase 1a).
  Otherwise honor the turn budget below: at **75%** of turns, stop launching
  evaluations and merge already-`PASS` PRs (summary only); at **90%**, print the
  summary and stop. Prioritize merging evaluated `PASS` PRs over further analysis.

## Turn Budget Management

If you are running as a background agent with a `max_turns` cap:

- **At 75% of turns used:** Stop launching new evaluations. Merge
  any PRs already evaluated as PASS. Skip Phase 5's detailed
  reports — print only the summary table.
- **At 90% of turns used:** Immediately print whatever summary you
  have and stop. Do not start new evaluations or re-tests.
- **Prioritize merging over analysis.** If you must choose between
  thorough analysis of the last PR and merging already-evaluated
  PASS PRs, merge first.

## Phase 0: Dependabot Config Audit

If `$OPTIONS` includes `--skip-config-audit`, skip this entire
phase and proceed to Phase 1.

Detect all package ecosystems present in the repo by checking for
these indicator files:

| Indicator file(s) | Ecosystem |
|---|---|
| `pyproject.toml` + `uv.lock` | `uv` |
| `pyproject.toml` (no `uv.lock`), `requirements*.txt`, `setup.py`, `setup.cfg` | `pip` |
| `Cargo.toml` | `cargo` |
| `package.json` | `npm` |
| `go.mod` | `gomod` |
| `Gemfile` | `bundler` |
| `Dockerfile`, `docker-compose.yml` | `docker` |
| `.github/workflows/*.yml` | `github-actions` |
| `composer.json` | `composer` |
| `*.csproj`, `*.fsproj` | `nuget` |

Read `.github/dependabot.yml`. Verify all five conditions:

1. **Coverage** — every detected ecosystem has a corresponding
   `updates` entry with the correct `package-ecosystem` value and
   appropriate `directory` (usually `"/"`)
2. **uv vs pip** — if a directory has both `pyproject.toml` and
   `uv.lock`, the ecosystem MUST be `uv`, not `pip`. The `pip`
   ecosystem does not update `uv.lock`, which causes PRs that
   modify `pyproject.toml` but leave `uv.lock` out of sync.
   If any entry uses `pip` where `uv` is correct, flag it for
   correction.
3. **Schedule** — every entry has `schedule.interval: "weekly"`
4. **Cooldown** — every entry has a `cooldown` block with
   `default-days: 7`. This prevents dependabot from flooding the
   PR queue with rapid re-attempts after a PR is closed or merged.
5. **Grouped updates** — every entry has a `groups` key with at
   least one group using `patterns: ["*"]` or more specific
   grouping patterns

If the file is missing or any condition fails, create a corrective
PR:

1. `git checkout -b fix/dependabot-config`
2. Write or update `.github/dependabot.yml`. Every `updates` entry
   MUST include all four required blocks. Use this template for each
   ecosystem entry:

   ```yaml
   - package-ecosystem: "{ecosystem}"
     directory: "/"
     schedule:
       interval: "weekly"
     cooldown:
       default-days: 7
     groups:
       {ecosystem}-dependencies:
         patterns:
           - "*"
   ```

   When updating an existing file, preserve any extra fields already
   present (labels, reviewers, open-pull-requests-limit, etc.) and
   only add missing blocks.

3. `git commit -m "chore: update dependabot config for full coverage, weekly schedule, 7-day cooldown, and grouped updates"`
4. `git push origin fix/dependabot-config`
5. `gh pr create --repo $REPO --title "Update dependabot configuration" --body "Adds missing ecosystem coverage, enforces weekly schedule, 7-day cooldown, and grouped updates."`
6. `git checkout "$DEFAULT_BRANCH"`

Continue to Phase 1 regardless — this PR is non-blocking.

## Phase 1: Discovery & Baseline

### 1a. Fetch dependabot PRs

```bash
gh pr list --repo $REPO --author "app/dependabot" --state open \
  --json number,title,headRefName,labels,files,mergeable
```

If zero PRs are returned, print "No open dependabot PRs for $REPO"
and stop.

### 1b. Categorize PRs

For each PR, examine its changed files:

- **Actions dep** — all changed files are under `.github/workflows/`
  or `.github/actions/`
- **Library dep** — everything else (lockfiles, manifests, version
  pins, dependency specification files)

Store the categorized list for later phases.

### 1c. Baseline build and test

Verify the default branch is healthy before evaluating any PR.

1. `git checkout "$DEFAULT_BRANCH"`
2. Discover the build system — follow the same discovery process
   described in Phase 3's subagent instructions (read CI workflows
   first, then Makefile, then language-specific defaults)
3. Run the build command. If it fails, **stop the entire command**
   and report: "`$DEFAULT_BRANCH` build is broken. Fix it before
   processing dependabot PRs." Include the error output.
4. Run the test command. If tests fail, **stop the entire command**
   and report: "`$DEFAULT_BRANCH` tests are failing. Fix them before
   processing dependabot PRs." Include which tests fail.
5. Record the baseline:
   - Full dependency tree from lockfile(s) (`pip freeze`,
     `cargo tree`, `npm ls --all`, `go list -m all`, etc.)
   - List of passing tests
   - Build output summary

Store the baseline data — subagents need it for comparison.

## Phase 2: Dependency Graph Analysis

### 2a. Build the transitive dependency map

Parse the repo's lockfile(s) to understand the full dependency
tree:

| Ecosystem | Lockfile | Tree command |
|---|---|---|
| uv | `uv.lock` | `uv pip freeze` (after `uv sync`) |
| pip | `poetry.lock`, `requirements*.txt` | `pip freeze` |
| cargo | `Cargo.lock` | `cargo tree` |
| npm | `package-lock.json`, `pnpm-lock.yaml` | `npm ls --all` or `pnpm ls --depth=Infinity` |
| gomod | `go.sum` | `go list -m all` |
| bundler | `Gemfile.lock` | `bundle list` |

For each library dep PR, identify which direct dependency it bumps
(from the PR title and changed files). Look up that package in the
dependency tree to find all its transitive dependents and
dependencies.

### 2b. Group overlapping PRs into batches

Two PRs overlap if:
- PR A bumps package X, PR B bumps package Y, and X depends on Y
  (or Y depends on X) in the transitive tree
- Both PRs modify the same lockfile section for shared transitive
  dependencies

Group overlapping PRs into **batches**. PRs with no overlaps
remain **independent** work units.

Actions dep PRs are always independent work units — they don't
interact with library dependency trees.

### 2c. Sort and queue

Sort work units in topological order — leaf dependencies first,
core/shared dependencies last. This ensures earlier merges are
less likely to affect later ones.

If there are more than 5 work units total, process in **waves
of 5**. The first wave starts immediately; subsequent waves start
after the previous wave completes.

Print the grouping plan before proceeding:
- List each work unit (batch or independent)
- Show which PRs are in each batch and why they were grouped
- Show the evaluation order

## Phase 3: Parallel Evaluation

### 3a. Fetch PR branches

For each work unit, fetch every PR head it contains into the local repo —
a batch needs all of them, because Phase 3b merges them together:

```bash
git fetch origin pull/{number}/head:pr-{number}
```

Then give each work unit its own worktree. Phase 3b runs up to 5 units
concurrently against this one clone, so a `git checkout` per subagent would
have them overwrite each other's files mid-build. Worktrees go outside the
clone, so repo-wide tooling inside it never walks another unit's tree:

```bash
# independent PR
git worktree add /tmp/depbot-eval-{repo-slug}-wt/pr-{number} pr-{number}

# batch — branch off the default branch, merge the PRs in Phase 3b
git worktree add -b test-batch-{batch_id} \
  /tmp/depbot-eval-{repo-slug}-wt/batch-{batch_id} "$DEFAULT_BRANCH"
```

Create every worktree here, in the parent, and pass each subagent its path.
Cleanup is the parent's job too (Phase 3c) — a subagent that reports FAIL stops
early and would never reach a cleanup step of its own.

Two costs come with the isolation. Each worktree is a full checkout, so a wave of
5 uses 5 working trees' worth of disk and each unit builds from a cold cache
instead of sharing one warm tree — that sharing is what was corrupting the
results. And because the clone is blobless, checking out a worktree fetches the
blobs it needs, so these commands need network, not just the clone.

### 3b. Launch subagents

Launch up to 5 subagents in parallel using Codex multi-agent tooling. Each
call must use:
- `subagent_type: "general-purpose"`
- The appropriate prompt below (library or actions)

Send all subagent dispatches in a **single message** for parallel execution.
If more than 5 work units, wait for the current wave to complete
before launching the next.

Pass each subagent:
- The repo directory path
- The worktree path created for its unit in Phase 3a
- The PR number(s) and title(s)
- The baseline dependency tree from Phase 1
- The repo's build and test commands discovered in Phase 1
- `$DEFAULT_BRANCH` — a subagent diffs and merges against it and has no way to
  resolve it itself, so substitute the resolved name into `{default_branch}`
  below rather than leaving the placeholder for the subagent to guess

### Subagent prompt: Library Dep Evaluation

Use this prompt for each library dep work unit.

---

You are evaluating dependabot PR(s) for merge safety. Work in your own
worktree: {worktree_path} — a checkout of the clone at {repo_path}.

**Repo:** $REPO
**PR(s) to evaluate:** {pr_numbers_and_titles}
**Default branch:** {default_branch}
**Baseline dependency tree from {default_branch}:**

```
{baseline_dep_tree}
```

**Build command:** {build_command}
**Test command:** {test_command}

Execute every step. Do not skip steps. Do not ask for confirmation.

**STEP 1 — Enter your worktree**

Phase 3a fetched the PR head and created this worktree with the PR
branch already checked out. Work here for every remaining step. Never
`git checkout` in `{repo_path}` — the other units are running there.

```bash
cd {worktree_path}
```

For a batch, the worktree sits on a fresh branch off the default
branch instead; merge the PR heads into it:

```bash
cd {worktree_path}
git merge pr-{pr1} pr-{pr2} --no-edit
```

If the merge has conflicts, report FAIL with the conflicting files
and stop.

**STEP 2 — Transitive dependency analysis**

Generate the full dependency tree using the same command that
produced the baseline. Compare against the baseline and report:

```
DIRECT CHANGES:
  - {package}: {old_version} → {new_version}

TRANSITIVE CHANGES:
  - {package}: {old_version} → {new_version}  (depended on by: {parent})

NEW TRANSITIVE DEPS:
  - {package} {version}  (pulled in by: {parent})

REMOVED TRANSITIVE DEPS:
  - {package} {version}

FLAGS:
  - DOWNGRADE: {package} went from {higher} to {lower}
  - MAJOR BUMP: {package} crossed a major version boundary
```

If there are zero flags and zero new/removed transitive deps,
note "Clean transitive dependency change."

**STEP 3 — Build**

Run the build command: {build_command}

If the build command was not provided (blank), discover it:

1. Read `.github/workflows/` for build steps
2. Check `Makefile` or `justfile` for a `build` target
3. Language-specific defaults:

| Manifest | Default |
|---|---|
| `Cargo.toml` | `cargo build` |
| `pyproject.toml` | `uv pip install -e ".[dev]"` |
| `package.json` | `pnpm install && pnpm build` |
| `go.mod` | `go build ./...` |
| `Gemfile` | `bundle install` |

If the build fails, report FAIL with exact error output and stop.

**STEP 4 — Test**

Run the test command: {test_command}

If the test command was not provided (blank), discover it using the
same approach as Step 3:

| Manifest | Default |
|---|---|
| `Cargo.toml` | `cargo test` |
| `pyproject.toml` | `pytest -q` |
| `package.json` | `pnpm test` |
| `go.mod` | `go test ./...` |
| `Gemfile` | `bundle exec rspec` or `bundle exec rake test` |

If tests fail, check whether the same tests also fail on the
`{default_branch}` baseline. Pre-existing failures do not count against
this PR.

If there are new test failures (pass on `{default_branch}`, fail on this
PR), report FAIL with the failing test names and error output.

**STEP 5 — Build matrix gap analysis**

Read `.github/workflows/` for `strategy.matrix` blocks. For each
matrix dimension, report what was tested locally vs. what only
runs in CI:

| Dimension | Example values | Testable locally? |
|---|---|---|
| OS | ubuntu, macos, windows | Current OS only |
| Language version | python 3.9-3.12 | Installed version only |
| Dependency version | numpy 1.x, 2.x | PR's version only |

Report the matrix gaps and assess risk:
- **HIGH risk:** The dependency is known to have version-specific
  behavior (e.g., numpy/scipy ABI, pytorch CUDA builds, native
  extensions) and CI tests versions we couldn't test locally
- **LOW risk:** The matrix covers OS variants or formatting
  differences unlikely to be affected by a dependency bump

If there is no matrix strategy in CI, report "No CI matrix — single
configuration build."

**STEP 6 — Verdict**

**PASS** — all conditions met:
- Build succeeds
- All tests pass (or only pre-existing failures)
- No transitive dependency flags (downgrades, major bumps)
- No high-risk matrix gaps

**WARN** — build and tests pass, but concerns exist:
- New transitive dependencies introduced
- Transitive dep crossed a major version boundary
- High-risk matrix gaps
- List each specific concern

**FAIL** — any of:
- Build fails
- New test failures
- Merge conflicts

Format the final report:

```
## Evaluation Report: PR #{number} — {title}

**Verdict: {PASS|WARN|FAIL}**

### Transitive Dependency Analysis
{step 2 output}

### Build Result
{pass/fail with output if failed}

### Test Result
{pass/fail with details}

### Matrix Gap Analysis
{step 5 output}

### Concerns
{list of concerns, or "None"}
```

---

### Subagent prompt: Actions Dep Evaluation

Use this prompt for each GitHub Actions version bump PR.

---

You are evaluating a GitHub Actions version bump for merge safety.
Work in your own worktree: {worktree_path} — a checkout of the clone
at {repo_path}.

**Repo:** $REPO
**PR to evaluate:** #{number} — {title}
**Default branch:** {default_branch}

Execute every step.

**STEP 1 — Enter your worktree**

Phase 3a fetched the PR head and created this worktree with the PR
branch already checked out. Never `git checkout` in `{repo_path}` —
the other units are running there.

```bash
cd {worktree_path}
```

**STEP 2 — Diff analysis**

Run `git diff {default_branch} -- .github/` to see what changed. Identify:
- Which action(s) were bumped
- Old and new versions (or SHA pins)
- Whether this is a patch, minor, or major version bump

For major version bumps, use Exa (`mcp__exa__web_search_exa`) to
search for breaking changes:
`{action_name} v{old_major} to v{new_major} migration breaking changes`

**STEP 3 — Workflow validation**

Run: `actionlint` (it auto-discovers `.github/workflows/`; passing the directory errors)

If `actionlint` is not installed, note this and skip to Step 4.

Distinguish pre-existing errors (also present on `{default_branch}`) from
new errors introduced by the version bump. Only new errors count
against this PR.

**STEP 4 — Pin verification**

Check every `uses:` line in changed workflow files. Verify the
SHA-pin format:

```yaml
# GOOD:
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

# BAD (tag only):
uses: actions/checkout@v4

# BAD (SHA without version comment):
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

Flag tag-only references as a WARN concern (not FAIL).

**STEP 5 — Verdict**

**PASS** — all conditions met:
- actionlint clean (or only pre-existing warnings)
- No breaking changes for major version bumps
- Actions are SHA-pinned with version comments

**WARN** — concerns exist:
- Tag pin instead of SHA pin
- Major version bump with breaking changes that appear handled

**FAIL** — any of:
- New actionlint errors
- Major version bump with unhandled breaking changes

Format the report the same way as library dep evaluations.

---

### 3c. Remove the evaluation worktrees

Once every subagent has reported, remove the worktrees before starting
Phase 4. That phase checks PR branches out in the clone itself, and git
refuses to check out a branch a worktree is holding.

```bash
git worktree remove --force /tmp/depbot-eval-{repo-slug}-wt/{unit_id}
```

Remove every unit's worktree whatever its verdict. `--force` because a
unit that built before failing leaves artifacts behind, and `git worktree
remove` refuses a dirty tree without it.

## Phase 4: Sequential Merge

Collect all subagent evaluation reports. Process work units in the
dependency order established in Phase 2.

### 4a. Merge passing PRs

For each work unit with a **PASS** verdict, in order:

1. Approve the PR:
   ```bash
   gh pr review --repo $REPO --approve {number} \
     --body "Automated evaluation: build, tests, and transitive dependency analysis passed."
   ```

2. Merge with the method resolved up front:
   ```bash
   gh pr merge --repo $REPO "$MERGE_FLAG" {number}
   ```

   No `--admin`. Branch protection and required status checks apply to this
   merge exactly as they would to a human's, which is the point: the Phase 3
   evaluation is a local pre-filter, not a substitute for the repo's own gates.

3. Verify the merge succeeded (gh pr merge produces no output on
   success):
   ```bash
   gh pr view --repo $REPO {number} --json state
   ```
   Confirm `state` is `"MERGED"`. If it is not, the merge was refused —
   red or pending required checks, or an unsatisfied protection rule. Mark
   the work unit **BLOCKED**, record `gh`'s refusal message verbatim for
   Phase 5c, and continue to the next work unit. **Do not re-run the merge
   with `--admin`**, and do not treat the local `PASS` as grounds to override:
   a refusal is the repo reporting something this skill did not test.

   **One refusal is retryable: a branch behind its base.** On a repo that
   requires branches be up to date before merging, every PR after the first
   merge of a wave goes `BEHIND`, and each would otherwise report `BLOCKED` —
   so the run would merge one PR and refuse the rest. Satisfy the rule rather
   than bypass it:

   ```bash
   gh pr update-branch --repo $REPO {number}
   ```

   This re-triggers the PR's checks, so they return to pending. Wait for them,
   then attempt the merge once more. If the turn budget (above) is too tight to
   wait, mark the unit `BLOCKED` and note that it was only behind — that is a
   different report for the human than a failing check. Any other refusal reason
   gets no retry.

4. Update the default branch locally:
   ```bash
   git checkout "$DEFAULT_BRANCH" && git pull origin "$DEFAULT_BRANCH"
   ```

5. **Re-test the next work unit** before merging it. Check out its
   branch and merge the updated default branch into it:
   ```bash
   git checkout pr-{next_number}
   git merge "$DEFAULT_BRANCH" --no-edit
   ```
   Re-run the build and test commands. If the re-test fails, mark **that
   next work unit** as **SKIPPED** with reason: "Passed independent
   evaluation but failed after merging prior PRs. Likely conflicts
   with: {previously merged PR numbers}." Continue past it to the
   following work unit.

For **batched** work units, merge each PR in the batch
sequentially using the same approve-then-merge flow.

### 4b. Handle WARN and FAIL verdicts

- **WARN** — do not merge. Include in final report with specific
  concerns. These need human review.
- **FAIL** — do not merge. Include full error context for diagnosis.

`BLOCKED` is not a verdict but a merge outcome: the unit passed evaluation and
the repo refused the merge (step 3). Report it with the refusal message so the
human can see which gate declined — a red required check needs a different fix
than a protection rule that wants a second reviewer.

## Phase 5: Cleanup & Report

### 5a. Cleanup

Return to the default branch and delete local PR branches:

```bash
git checkout "$DEFAULT_BRANCH"
git branch -D pr-{number} test-batch-{batch_id}  # for each evaluated PR/batch
```

### 5b. Summary report

Print a summary table:

```
## Dependabot PR Summary for $REPO

| PR | Title | Type | Verdict | Action | Notes |
|----|-------|------|---------|--------|-------|
```

Include every evaluated PR with its verdict and outcome.

Below the table, print totals:

```
**Merged:** {count}
**Skipped (WARN — needs human review):** {count}
**Failed:** {count}
**Skipped (post-merge conflict):** {count}
**Blocked (merge refused by branch protection or required checks):** {count}
```

If a dependabot config PR was created in Phase 0:

```
**Dependabot config PR:** #{number}
```

### 5c. Detailed reports for non-merged PRs

For each WARN, FAIL, SKIPPED, or BLOCKED PR, print the full evaluation
report from the subagent so the user has all context needed to
decide or fix the issue. For a BLOCKED PR, add the merge refusal message
from Phase 4a step 3 — the evaluation report alone says `PASS` and does not
explain why the merge did not happen.
