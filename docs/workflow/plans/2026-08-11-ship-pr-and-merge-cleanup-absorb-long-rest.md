# Unit 4 — `$ship-pr` + `$merge-cleanup` Absorb `finishing-a-development-branch`

> **For agentic workers:** execute task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Delete `skills/finishing-a-development-branch/` after writing the three
behaviours the inventory found genuinely uncovered into `$ship-pr` and
`$merge-cleanup`.

**Architecture:** This is the fourth absorption unit of the first-party skill
rewrite (`docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md`
§1). The source skill implements a four-option integration menu; this repo's
pipeline has one integration path and forbids two of the four options outright.
The behaviour inventory
(`docs/superpowers/inventories/finishing-a-development-branch.md`) records 3 ADD,
10 CARRIED, 13 DROP. Only the three ADDs are written; the ten CARRIED rows are
verified, not restated, because a second copy of a rule is the drift surface
spec §1 objects to.

**Tech stack:** Markdown skills, `just verify`, `scripts/check-skill-shape.sh`.

## Global Constraints

- This repository is **public**. No host-specific configuration, absolute user
  paths, hostnames, addresses, auth headers, API keys, or session state. Plans
  and specs name the checkout root as `$WORK`.
- Anatomy rule 1: a skill is instructions, not a program — `SKILL.md` is the
  default artifact.
- Anatomy rule 4: nothing automated asserts on prose. Verification in this plan
  is structural (`check-skill-shape.sh`) plus explicit `rg` assertions on
  *references*, never on sentences.
- `rg` in any assertion passes `--no-config`.
- Conventional commits, imperative mood, subject ≤ 72 characters, one logical
  change per commit.
- Never commit to `main`. Work happens on
  `refactor/absorb-finishing-a-development-branch`.
- Run gates bare — no pipes that swallow an exit code, no `|| true`.

## Two premises this plan does **not** rely on

Both were checked before writing, because the equivalent premises were wrong in
units 1, 2 and 3.

**1. The shape gate cannot catch a missed reference here.** Rule 4 of
`check-skill-shape.sh` scans only the backticked `` `$name` `` invocation form.
`finishing-a-development-branch` has no `$`-prefixed invocation form and is never
written that way, so deleting the directory cannot produce a shape-gate failure.
Every reference check in this plan is therefore an explicit `rg` assertion.

**2. `git status` cannot show a leftover empty directory.** Git does not track
empty directories. `skills/finishing-a-development-branch/` holds exactly one
file, so `git rm` empties it and the directory itself may survive on disk. In
unit 2 this produced a shape-gate failure (`no SKILL.md`) after a clean
`git status`. Task 3 removes it explicitly with `rmdir`, which self-verifies by
refusing a non-empty directory.

## Measured starting state

```
skills/finishing-a-development-branch/SKILL.md   284 lines
skills/ship-pr/SKILL.md                           85 lines
skills/merge-cleanup/SKILL.md                    112 lines
```

Every reference to the source skill outside its own file, the spec, and the
historical unit-2 plan: **none**. Verified with
`rg --no-config -n 'finishing-a-development-branch' .` at `eaab678`.

`README.md:31` reads "30 skills covering design, TDD, adversarial review,
shipping, and campaign". It becomes 29.

---

### Task 1: `$ship-pr` gains the detached-HEAD branch requirement

Inventory row 5. `$build-tdd` detects a detached HEAD and explicitly defers the
work — "detached means a branch has to be created at finish time" — and finish
time is `$ship-pr`, whose §2 currently opens "Push the branch and open a PR"
with no branch to push.

**Files:**
- Modify: `skills/ship-pr/SKILL.md` — §2 "Create the PR"

- [ ] **Step 1: Confirm the gap is real**

```bash
rg --no-config -n 'detach|HEAD' skills/ship-pr/SKILL.md
```

Expected: no match (`rg` exit 1). If it matches, the behaviour is already
present — re-read it, mark row 5 CARRIED in the inventory instead, and skip to
Task 2.

- [ ] **Step 2: Confirm `$build-tdd` really defers it**

```bash
rg --no-config -n 'branch has to be created at finish time' skills/build-tdd/SKILL.md
```

Expected: one match. This is the forward reference Task 1 answers.

- [ ] **Step 3: Write the paragraph**

Insert at the head of `## 2. Create the PR`, before "Push the branch and open a
PR against `BASE_BRANCH`":

```markdown
**If HEAD is detached there is no branch to push.** An externally managed
workspace can hand you one — `$build-tdd` detects the case and leaves it here,
because this is the first step that needs a branch name. Create one at the
current commit (`git switch -c <name>`) before pushing; derive the name from the
work and say what you chose.
```

- [ ] **Step 4: Verify**

```bash
rg --no-config -c 'detached' skills/ship-pr/SKILL.md
```

Expected: `1`.

- [ ] **Step 5: Commit**

```bash
git add skills/ship-pr/SKILL.md
git commit -m "feat(ship-pr): create a branch when HEAD is detached"
```

---

### Task 2: `$merge-cleanup` gains harness-tool teardown and `git worktree prune`

Inventory rows 6 and 7. Both attach to the same numbered teardown list, so they
are one task: a reviewer could not meaningfully accept one and reject the other.

Row 6: `$build-tdd` warns that running `git worktree add` behind a harness's
native worktree tool "creates phantom state it cannot see". Teardown is the same
hazard and nothing says so — `$merge-cleanup` step 2 reaches straight for
`git worktree remove`.

Row 7: step 6 reads "Prune remote-tracking branches", which is `git remote
prune`. Nothing prunes **worktree registrations**, which is a different command
clearing different state.

**Files:**
- Modify: `skills/merge-cleanup/SKILL.md` — the "After a merge (yours or the
  user's)" list and the prose under it

- [ ] **Step 1: Confirm both gaps are real**

```bash
rg --no-config -n 'worktree prune' skills/merge-cleanup/SKILL.md skills/ship-pr/SKILL.md skills/build-tdd/SKILL.md
```

Expected: no match (`rg` exit 1).

```bash
rg --no-config -n 'workspace-exit|native worktree tool|EnterWorktree' skills/merge-cleanup/SKILL.md
```

Expected: no match (`rg` exit 1).

- [ ] **Step 2: Rewrite step 2 of the numbered list**

Replace:

```markdown
2. Remove any external worktree **this run created** for this issue
   (`git worktree remove`).
```

with:

```markdown
2. Remove any external worktree **this run created** for this issue. If the
   harness created it with its own tool — `EnterWorktree`, a `/worktree`
   command, a `--worktree` flag — tear it down with that tool's counterpart.
   Reaching past it for `git worktree remove` leaves the harness holding a
   workspace it still believes is live, the teardown half of the phantom state
   `$build-tdd` warns about on the way in. Otherwise `git worktree remove`,
   then `git worktree prune` to clear any registration a previous removal left
   behind — that is worktree bookkeeping, and unrelated to step 6.
```

- [ ] **Step 3: Verify both behaviours landed and step 6 still reads as remotes**

```bash
rg --no-config -c 'git worktree prune' skills/merge-cleanup/SKILL.md
rg --no-config -n 'Prune remote-tracking branches' skills/merge-cleanup/SKILL.md
```

Expected: `1`, then one match on the step 6 line — the two prunes stay distinct.

- [ ] **Step 4: Commit**

```bash
git add skills/merge-cleanup/SKILL.md
git commit -m "feat(merge-cleanup): tear down worktrees with the tool that made them"
```

---

### Task 3: Delete the absorbed skill

**Files:**
- Delete: `skills/finishing-a-development-branch/SKILL.md`
- Delete: `skills/finishing-a-development-branch/` (the directory itself)

- [ ] **Step 1: Re-confirm nothing outside the spec and prior plans references it**

```bash
rg --no-config -n 'finishing-a-development-branch' skills/ scripts/ tests/ README.md CLAUDE.md .claude-plugin/ .codex-plugin/
```

Expected: exactly one match — `skills/finishing-a-development-branch/SKILL.md:2`,
its own frontmatter `name:`. Any other match is a reference that must be
re-pointed before deletion.

- [ ] **Step 2: Remove the file and then the directory**

```bash
git rm -r skills/finishing-a-development-branch
rmdir skills/finishing-a-development-branch 2>/dev/null || true
```

The `rmdir` is the unit-2 lesson: `git rm -r` can leave the empty directory on
disk and `git status` will not show it. `rmdir` refuses a non-empty directory,
so it self-verifies. The `|| true` is acceptable here **only** because a
successful `git rm -r` may already have removed the directory, making a failure
the expected case — it guards a cleanup, not a gate.

- [ ] **Step 3: Verify the directory is gone from disk**

```bash
test ! -e skills/finishing-a-development-branch
```

Expected: exit 0.

- [ ] **Step 4: Count the skills**

```bash
ls -d skills/*/ | wc -l
```

Expected: `29`.

- [ ] **Step 5: Commit**

```bash
git add -A skills/finishing-a-development-branch
git commit -m "refactor: delete finishing-a-development-branch, now absorbed"
```

---

### Task 4: Sweep the count and the spec's disposition record

**Files:**
- Modify: `README.md:31`

- [ ] **Step 1: Find every stale count**

```bash
rg --no-config -n '\b30 skills\b' README.md CLAUDE.md docs/ .claude-plugin/ .codex-plugin/
```

Expected: `README.md:31` and the two historical unit-3 plan lines. **Plans are
the historical record and are not edited** — unit 3 established this. Only
`README.md` changes.

- [ ] **Step 2: Update the count**

`README.md:31` becomes:

```markdown
29 skills covering design, TDD, adversarial review, shipping, and campaign
```

- [ ] **Step 3: Verify no stale count survives outside the plans**

```bash
rg --no-config -n '\b30 skills\b' README.md CLAUDE.md .claude-plugin/ .codex-plugin/
```

Expected: no match (`rg` exit 1).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: 29 skills after absorbing finishing-a-development-branch"
```

---

### Task 5: Run the guardrail suite and open the PR

- [ ] **Step 1: Shape gate**

```bash
just verify
```

Expected: exit 0, including `check-skill-shape: 29 skills, all rules pass`. Run
it **bare** — no pipe, no redirect. It takes several minutes.

- [ ] **Step 2: Plugin manifest**

```bash
just plugin-check
```

Expected: exit 0 with exactly one warning, the known
`plugins[0] plugin.json → version: No version specified`.

- [ ] **Step 3: Measure the unit**

```bash
git diff --stat main -- skills/
```

Record the net line change in `skills/` for the unit report.

- [ ] **Step 4: Push and open the PR**

Follow `$ship-pr`: push, open the PR against `main`, drive to green **and**
`mergeStateStatus` `CLEAN`. Poll with compact `--json` snapshots on a backing-off
interval; never `--watch` in the foreground.

- [ ] **Step 5: Merge and clean up**

Follow `$merge-cleanup`: merge with `--rebase` (never squash), then checkout
`main`, pull, delete the local and remote-tracking branch, prune, and confirm the
working tree is clean.

## Self-Review

**Spec coverage.** Spec §1 assigns `finishing-a-development-branch` to
`$ship-pr` + `$merge-cleanup`. Task 1 covers `$ship-pr`, Task 2 covers
`$merge-cleanup`, Task 3 completes the absorption. The `long-rest` phase name
from §3 is **not** introduced here: §3 states "the rename lands last", and
naming a phase `long-rest` before the sweep would create a name the sweep then
has to reconcile. Unit 3 made the same call for `petition-council`.

**Placeholder scan.** Every step carries its exact command, its exact expected
output, and the full text of every prose insertion. No "TBD", no "add
appropriate handling", no "similar to Task N".

**Consistency.** Task 3 expects 29 skills and Task 4 writes 29 to `README.md`;
Task 5 expects `check-skill-shape: 29 skills`. Task 2's step 3 asserts the two
`prune` commands stay distinct, which is the whole point of row 7.

**Risk.** The only irreversible step is Task 3's deletion, gated by Task 3 step 1
proving there is exactly one reference — its own frontmatter — and by the
inventory having already dispositioned all 26 behaviours. The file remains in git
history either way.
