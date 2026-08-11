# `$build-tdd` Absorbs the Execution Modes — Implementation Plan

> **For agentic workers:** Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Subagents are not used for this unit.

**Goal:** Collapse `executing-plans`, `subagent-driven-development`, and `using-git-worktrees` into `$build-tdd` as its `cast`, `party`, and `pocket-dimension` modes, moving the three helper scripts and two prompt templates with them.

**Architecture:** `$build-tdd` already picks the execution mode and dispatches whichever of the three skills fits, declaring itself their dispatched caller. All three exist only to be picked. Absorbing them puts the mode selection and the mode bodies in one document, and deletes the three "Dispatched mode" sections that describe being picked. Unlike unit 1 this unit carries executable code: three scripts that §4 rule 2 names as clearing its bar, and a test fixture whose path is hardcoded in two places.

**Tech Stack:** Markdown skill documents; `bash` 3.2 helper scripts; `just` recipes; `scripts/git-fixture-isolation-test.sh` and `scripts/list-shell-sources.sh` as the discovery mechanisms that must keep finding the moved files.

## Global Constraints

Copied from `docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md`:

- **§4 rule 1** — A skill is instructions, not a program. The default artifact is one `SKILL.md`. Supporting files are the exception and must be argued for.
- **§4 rule 2** — Executable code clears a bar or it does not ship: permitted only when it does something a model cannot do reliably inline. The spec names `sdd-workspace`, `task-brief`, and `review-package` as clearing it, so they move rather than dying.
- **§4 rule 3** — No long-lived processes. Every script runs and exits.
- **§4 rule 4** — Nothing automated asserts on prose.
- **§1** — "No skill exists merely so another skill can call it. Every 'dispatched workflow mode' section disappears with the caller/callee split that created it."
- **§1 disposition** — `subagent-driven-development`'s `sdd-workspace`, `task-brief`, `review-package` scripts move to `skills/build-tdd/scripts/`.
- **§2 rule 1** — Write from the process, not the text; re-express.
- **§2 rule 2** — Attribution removal is **not** in this unit. The MIT notice and `licenses/` stay untouched; that is §6 step 5 and its own plan.
- **§3** — **Do not apply the D&D skill rename.** `build-tdd` stays `build-tdd`. Only the absorbed names (`cast`, `party`, `pocket-dimension`) land here, because their directories are deleted in this unit.
- **§5** — Behaviour inventories extracted **before** writing, serving as regression guard, independence mechanism, and YAGNI filter.
- Repo `CLAUDE.md` — `adept` is PUBLIC. No host-specific paths, hostnames, addresses, auth headers, API keys, or session state.
- Branch: `feat/build-tdd-absorbs-execution-modes`. Never commit to `main`.

## Measured starting state

Measured against `main` at `760c91a`, not assumed:

| Path | Lines |
|---|---|
| `skills/build-tdd/SKILL.md` | 150 |
| `skills/build-tdd/agents/openai.yaml` | 4 |
| `skills/executing-plans/SKILL.md` | 81 |
| `skills/subagent-driven-development/SKILL.md` | 445 |
| `skills/subagent-driven-development/implementer-prompt.md` | 139 |
| `skills/subagent-driven-development/task-reviewer-prompt.md` | 188 |
| `skills/subagent-driven-development/scripts/sdd-workspace` | 79 |
| `skills/subagent-driven-development/scripts/task-brief` | 43 |
| `skills/subagent-driven-development/scripts/review-package` | 50 |
| `skills/using-git-worktrees/SKILL.md` | 242 |
| **Absorbed total** | **1,267** |

Skill count: 34 before, 31 after.

**Backticked `$invocations` of the three absorbed skills: zero.** Every reference is a bare name. As in unit 1, `scripts/check-skill-shape.sh` rule 4 will **not** catch a missed reference — it scans only the `` `$name` `` form. The 21 backticked `$build-tdd` references all name the surviving skill and need no change. The `rg` sweep in Task 5 is the only guard.

The bare-name sites, in full:

```
skills/build-tdd/SKILL.md:11         "`subagent-driven-development`: a fresh implementer subagent per"
skills/build-tdd/SKILL.md:19         "`subagent-driven-development`, or `executing-plans` if the plan's header sends"
skills/challenge/SKILL.md:289        "... `requesting-code-review` and `subagent-driven-development`'s task reviewer ..."
skills/finishing-a-development-branch/SKILL.md:189  "... where `using-git-worktrees` puts one ..."
scripts/git-fixture-isolation-test.sh:110           fixture path, hardcoded
tests/fixtures/subagent-driven-development/sdd-workspace-test.sh:24  script path, hardcoded
```

`CLAUDE.md:15` names the three scripts as rule 2's worked example. The names do not change, so that line needs no edit — verify rather than assume.

## File Structure

**Created:**
- `docs/superpowers/inventories/executing-plans.md`
- `docs/superpowers/inventories/subagent-driven-development.md`
- `docs/superpowers/inventories/using-git-worktrees.md`

**Moved with `git mv`** — so history follows the file and the diff reads as a rename rather than a delete-plus-add:
- `skills/subagent-driven-development/scripts/{sdd-workspace,task-brief,review-package}` → `skills/build-tdd/scripts/`
- `skills/subagent-driven-development/{implementer-prompt.md,task-reviewer-prompt.md}` → `skills/build-tdd/`
- `tests/fixtures/subagent-driven-development/` → `tests/fixtures/build-tdd/`

The two prompt templates are an argued exception to §4 rule 1. They are dispatch payloads copied into a subagent prompt, not instructions the model reads on every invocation; inlining 327 lines of them into `SKILL.md` would put text in context on every build that is needed only at a dispatch. `skills/requesting-code-review/code-reviewer.md` is the same pattern already in the tree.

**Modified:**
- `skills/build-tdd/SKILL.md` — gains the three modes.
- `skills/challenge/SKILL.md:289` — severity-mapping reference re-pointed.
- `skills/finishing-a-development-branch/SKILL.md:189` — worktree-provenance reference re-pointed.
- `scripts/git-fixture-isolation-test.sh:110` — fixture path.
- `tests/fixtures/build-tdd/sdd-workspace-test.sh:24` — script path.

**Deleted:**
- `skills/executing-plans/`, `skills/subagent-driven-development/`, `skills/using-git-worktrees/` (whatever remains after the moves)

---

### Task 1: Behaviour inventories for the three absorbed skills

**Files:**
- Create: `docs/superpowers/inventories/executing-plans.md`
- Create: `docs/superpowers/inventories/using-git-worktrees.md`
- Create: `docs/superpowers/inventories/subagent-driven-development.md`

**Interfaces:**
- Produces: three inventories whose KEEP rows are the regression contract for Tasks 3–5 and whose DROP rows are the deliberate deletions those tasks must not reintroduce.

Follow the format established in `docs/superpowers/inventories/brainstorming.md`: a numbered table of observable behaviours, each with a KEEP or DROP verdict **and a reason**. A DROP without a stated reason is not the deliberate deletion §5 asks for.

- [ ] **Step 1: Write the `executing-plans` inventory**

Read `skills/executing-plans/SKILL.md` in full first. Its behaviours: load the plan and review it critically before starting; raise concerns before executing; create todos from plan items; per task mark in-progress, follow steps exactly, run the specified verifications, mark complete; stop on a blocker rather than guessing; return to review when the plan changes; never start on main/master without consent.

DROP at minimum: the "Announce at start" ritual; the whole "Dispatched mode — no human in the turn" section; the `finishing-a-development-branch` terminal state; the "vs. subagent-driven-development, use that if subagents are available" preamble; and the Integration list naming sibling skills.

- [ ] **Step 2: Write the `using-git-worktrees` inventory**

Read `skills/using-git-worktrees/SKILL.md` in full first. Its behaviours: detect existing isolation before creating anything (`GIT_DIR` vs `GIT_COMMON`) with the submodule guard; ask consent before creating a worktree unless a preference is declared; prefer a native worktree tool **unless it would nest**; refuse nesting inside the repo tree under any circumstances, `.gitignore` included; directory priority of explicit instruction > existing sibling root > `../<repo>-worktrees/`; verify the created path resolves outside the repo root; sandbox-denial fallback to working in place; auto-detect and run project setup; verify a clean test baseline before implementing; the three-way branch on a failing baseline.

DROP at minimum: the "Announce at start" ritual; the `## Mode` section's dispatched-authority apparatus; and the Quick Reference / Common Mistakes / Red Flags tables, which restate the steps a third and fourth time — note in the reason column that the *content* of any row not already carried by a step must be folded into that step rather than lost.

- [ ] **Step 3: Write the `subagent-driven-development` inventory**

Read `skills/subagent-driven-development/SKILL.md` in full first — it is 445 lines and the largest single source in this unit. Its behaviours include: fresh implementer per task plus a two-stage review; the pre-flight plan review for self-contradiction; model selection by task complexity with the turn-count-beats-token-price rule; the four implementer statuses and the distinct response to each; never retry an unchanged prompt after `BLOCKED`; resolve reviewer "cannot verify from diff" items yourself; the reviewer-prompt construction rules including never pre-judging a finding's severity; file handoffs via `task-brief` / `review-package` rather than pasted text; the durable progress ledger and its `.agent/` ignore contract; one fix subagent for the whole final-review findings list, not one per finding; and the Red Flags list.

DROP at minimum: the "Announce at start" ritual; the "Dispatched mode — no human in the turn" section; the `## When to Use` digraph choosing between this skill and `executing-plans`, which becomes `$build-tdd`'s own mode selection; the `## Advantages` and `## Example Workflow` sections; and the Integration list.

`## Advantages` and `## Example Workflow` are 100 lines between them and are the largest single deletion in this unit — give the reason column a real argument rather than "verbose". The example is a transcript of a fictional session, and the advantages section argues for a choice `$build-tdd` now makes on the reader's behalf.

- [ ] **Step 4: Verify each inventory against its source**

For each of the three, read the source top to bottom and confirm every heading maps to at least one row. This is a reading check; §4 rule 4 forbids automating an assertion over prose.

Expected: every heading represented. A section mapping to no row gets one before proceeding — that is the inertia loss §5 exists to prevent, and it caught a real gap in unit 1.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/inventories/
git commit -m "docs: extract behaviour inventories for the three execution skills"
```

---

### Task 2: Move the scripts, prompt templates, and test fixture

**Files:**
- Move: three scripts, two prompt templates, one fixture directory (paths in File Structure above)
- Modify: `tests/fixtures/build-tdd/sdd-workspace-test.sh:24`
- Modify: `scripts/git-fixture-isolation-test.sh:110`

**Interfaces:**
- Produces: `skills/build-tdd/scripts/{sdd-workspace,task-brief,review-package}` and `skills/build-tdd/{implementer-prompt.md,task-reviewer-prompt.md}`, the paths Tasks 3–5 reference.

This task moves executable code and its test with no prose rewriting, so it is separately reviewable and separately revertible from the absorption. Doing it first means Tasks 3–5 write against paths that already exist.

- [ ] **Step 1: Move everything with `git mv`**

```bash
mkdir -p skills/build-tdd/scripts
git mv skills/subagent-driven-development/scripts/sdd-workspace   skills/build-tdd/scripts/
git mv skills/subagent-driven-development/scripts/task-brief      skills/build-tdd/scripts/
git mv skills/subagent-driven-development/scripts/review-package  skills/build-tdd/scripts/
git mv skills/subagent-driven-development/implementer-prompt.md    skills/build-tdd/
git mv skills/subagent-driven-development/task-reviewer-prompt.md  skills/build-tdd/
git mv tests/fixtures/subagent-driven-development tests/fixtures/build-tdd
```

Use `git mv`, not `cp` — the scripts carry history worth following, and a rename shows in the diff as a rename.

- [ ] **Step 2: Confirm the executable bits survived**

```bash
ls -l skills/build-tdd/scripts/
```

Expected: all three are `-rwxr-xr-x`. `git mv` preserves mode, but the suites invoke these by path and a lost `+x` fails as "command not found" rather than as a permissions error. If a bit is missing, `chmod +x` it and say so.

- [ ] **Step 3: Repoint the hardcoded script path in the fixture**

`tests/fixtures/build-tdd/sdd-workspace-test.sh:24` reads:

```bash
SCRIPT="$SCRIPT_DIR/../../../skills/subagent-driven-development/scripts/sdd-workspace"
```

Change to:

```bash
SCRIPT="$SCRIPT_DIR/../../../skills/build-tdd/scripts/sdd-workspace"
```

The `../../../` depth is unchanged: `tests/fixtures/build-tdd/` is the same depth as `tests/fixtures/subagent-driven-development/`.

- [ ] **Step 4: Repoint the fixture path in the isolation suite**

`scripts/git-fixture-isolation-test.sh:110` names `tests/fixtures/subagent-driven-development/sdd-workspace-test.sh`. Change it to `tests/fixtures/build-tdd/sdd-workspace-test.sh`.

- [ ] **Step 5: Prove both suites still run**

Run, bare:

```bash
./tests/fixtures/build-tdd/sdd-workspace-test.sh
./scripts/git-fixture-isolation-test.sh
```

Expected: the first prints its `sdd-workspace` header and ends `N passed, 0 failed`; the second ends `git-fixture-isolation-test: all 6 suites passed`, listing the new fixture path among them.

A suite that passes because it silently skipped a moved file is the failure mode here. Confirm the isolation suite's output names `tests/fixtures/build-tdd/sdd-workspace-test.sh` — if it names only five suites, the path edit did not take.

- [ ] **Step 6: Confirm shell-source discovery still finds the moved scripts**

Run: `./scripts/list-shell-sources.sh --all`

Expected: the three moved scripts appear under their new `skills/build-tdd/scripts/` paths. They are discovered by Bash shebang rather than by extension, so the move should be transparent — verify rather than assume, because `list-shell-sources.sh` is what feeds `just lint`, `just format-check`, and the ripgrep-config gate. A script that drops out of that inventory is silently ungated.

- [ ] **Step 7: Commit**

```bash
git add -A skills/build-tdd skills/subagent-driven-development tests/fixtures scripts/git-fixture-isolation-test.sh
git commit -m "refactor(build-tdd): move the execution helpers and their fixture"
```

---

### Task 3: Absorb `using-git-worktrees` as the `pocket-dimension` mode

**Files:**
- Modify: `skills/build-tdd/SKILL.md` — the `## Subagent execution` section's worktree paragraph (lines 51–56)
- Delete: `skills/using-git-worktrees/`

**Interfaces:**
- Consumes: `docs/superpowers/inventories/using-git-worktrees.md`.
- Produces: a `## Pocket dimension — the isolated workspace` section that Tasks 4 and 5 leave untouched.

This lands first of the three absorptions because `$build-tdd` already carries a compressed version of the placement rule at lines 51–56, and both execution modes depend on the workspace existing before they run.

- [ ] **Step 1: Write the `pocket-dimension` section**

Add `## Pocket dimension — the isolated workspace` before `## Subagent execution`, carrying the KEEP rows: detection before creation with the submodule guard and its exact `git rev-parse` commands, consent, native tool preferred unless it nests, the absolute no-nesting rule, directory priority, the post-creation containment check, the sandbox fallback, project setup, and the clean-baseline verification with its three-way branch on failure.

Keep the shell blocks — they are exact commands a model would otherwise reconstruct inconsistently, which is the same argument §4 rule 2 makes for the scripts.

Delete the existing lines 51–56 paragraph in `## Subagent execution`; the new section states the rule once, in full, and leaving the compressed copy creates exactly the two-places-one-rule drift §1 objects to.

- [ ] **Step 2: Confirm every KEEP row is traceable, and every DROP row absent**

Read the inventory beside the new section and trace each row to a line. Pay attention to the Quick Reference / Common Mistakes / Red Flags rows marked DROP: confirm the *content* each carried is in a step, not merely that the tables are gone.

- [ ] **Step 3: Delete the absorbed skill and run the shape gate**

```bash
git rm -r skills/using-git-worktrees
just shape-check
```

Expected: `check-skill-shape: 33 skills, all rules pass`

- [ ] **Step 4: Commit**

```bash
git add skills/build-tdd/SKILL.md
git commit -m "refactor(build-tdd): absorb using-git-worktrees as the pocket-dimension mode"
```

---

### Task 4: Absorb `executing-plans` as the `cast` mode

**Files:**
- Modify: `skills/build-tdd/SKILL.md`
- Delete: `skills/executing-plans/`

**Interfaces:**
- Consumes: `docs/superpowers/inventories/executing-plans.md`. The `pocket-dimension` section from Task 3 is complete and is not edited here.
- Produces: a `## Cast — direct execution` section.

`cast` is the smaller of the two execution modes and lands before `party` so that the mode-selection rewrite in Task 5 has both bodies to point at.

- [ ] **Step 1: Write the `cast` section**

Add `## Cast — direct execution`, carrying the KEEP rows: read the plan and review it critically before starting, raising concerns before executing rather than discovering them mid-task; create todos from the plan's tasks; per task, follow the steps exactly and run the verifications the plan specifies; stop on a genuine blocker rather than guessing past it; return to the plan review when the plan itself changes; never start on main or master without explicit consent.

State plainly when this mode is chosen: no plan because the change is a trivial bugfix or a caller-verified `governed-small-change`, or a plan whose tasks are too tightly coupled to hand out. That selection currently lives at lines 14–16 and is re-stated in Task 5.

- [ ] **Step 2: Confirm every KEEP row is traceable, and every DROP row absent**

In particular confirm the section does not name `finishing-a-development-branch` as a terminal state. `$build-tdd` is not the end of the pipeline, and the existing text at lines 21–26 already says so.

- [ ] **Step 3: Delete the absorbed skill and run the shape gate**

```bash
git rm -r skills/executing-plans
just shape-check
```

Expected: `check-skill-shape: 32 skills, all rules pass`

- [ ] **Step 4: Commit**

```bash
git add skills/build-tdd/SKILL.md
git commit -m "refactor(build-tdd): absorb executing-plans as the cast mode"
```

---

### Task 5: Absorb `subagent-driven-development` as the `party` mode

**Files:**
- Modify: `skills/build-tdd/SKILL.md` — including the mode-selection preamble at lines 7–26
- Delete: `skills/subagent-driven-development/`

**Interfaces:**
- Consumes: `docs/superpowers/inventories/subagent-driven-development.md`; the moved scripts and prompt templates from Task 2, at their `skills/build-tdd/` paths. Sections from Tasks 3 and 4 are complete and are not edited here.
- Produces: the finished `$build-tdd`.

- [ ] **Step 1: Write the `party` section**

Add `## Party — subagent-driven execution`, carrying the KEEP rows: the pre-flight plan review; fresh implementer per task with a two-stage review; model selection by complexity including the turn-count rule; the four implementer statuses and the distinct response to each, with "never retry an unchanged prompt after BLOCKED"; resolving reviewer "cannot verify from diff" items yourself; the reviewer-prompt construction rules — above all that a dispatch never pre-judges a finding or tells a reviewer what not to flag; file handoffs through `task-brief` and `review-package` rather than pasted text; the durable progress ledger with its `.agent/` ignore contract and the `git check-ignore` confirmation; and one fix subagent for the whole final-review findings list.

Fold the existing `## Subagent execution` section (lines 44–91, minus the worktree paragraph Task 3 removed) into this section rather than leaving both — it is the same subject, and its model-selection and report-contract content overlaps the inventory's rows directly. Keep its severity-mapping paragraph: it is `$build-tdd`-level content about carrying findings outward to `$challenge`'s scale.

Reference the prompt templates at their new paths: `implementer-prompt.md` and `task-reviewer-prompt.md`, and the scripts as `scripts/task-brief`, `scripts/review-package`, `scripts/sdd-workspace`, all relative to `skills/build-tdd/`.

- [ ] **Step 2: Rewrite the mode-selection preamble**

Lines 7–26 currently pick between two skills and declare `$build-tdd` their dispatched caller. There are no callees now. Rewrite to select between the three sections in this document, keeping the pipeline-position statement — `$review-loop`, `$simplify-changes`, `$ship-pr` and `$merge-cleanup` follow, so this skill takes no merge, push, or discard — which is first-party content and the reason the callees' dispatched modes existed at all.

Keep the `**Caller contract.**` paragraph at lines 40–42 unchanged: it is about `$build-tdd` inside `$work-issue`, a live boundary.

- [ ] **Step 3: Confirm every KEEP row is traceable, and every DROP row absent**

Confirm specifically that the reviewer-prompt rule survives in full: a dispatch must not contain "do not flag", "at most Minor", or any other pre-judgment. It is the longest single KEEP row and the one most easily lost to compression.

- [ ] **Step 4: Delete the absorbed skill and run the shape gate**

```bash
git rm -r skills/subagent-driven-development
just shape-check
```

Expected: `check-skill-shape: 31 skills, all rules pass`

The directory should contain nothing but `SKILL.md` by now — Task 2 moved everything else. If `git rm -r` reports other files, they were missed by Task 2; move them rather than deleting them.

- [ ] **Step 5: Commit**

```bash
git add skills/build-tdd/SKILL.md
git commit -m "refactor(build-tdd): absorb subagent-driven-development as the party mode"
```

---

### Task 6: Sweep the residual references

**Files:**
- Modify: `skills/challenge/SKILL.md:289`
- Modify: `skills/finishing-a-development-branch/SKILL.md:189`
- Verify: `CLAUDE.md:15`, `README.md` skill count

**Interfaces:**
- Consumes: the deletions from Tasks 3–5.
- Produces: a repository in which no document names a skill that does not exist.

- [ ] **Step 1: Re-point the severity-mapping reference**

`skills/challenge/SKILL.md:289` reads `` The vendored superpowers review skills — `requesting-code-review` and `subagent-driven-development`'s task reviewer — grade `Critical / Important / Minor` instead. ``

Change the second name to `` `$build-tdd`'s task reviewer ``. Leave `requesting-code-review` alone — it is absorbed in unit 3, not this one, and changing it now would name a phase that does not exist yet.

- [ ] **Step 2: Re-point the worktree-provenance reference**

`skills/finishing-a-development-branch/SKILL.md:189` reads `` A worktree is **ours** when it sits where `using-git-worktrees` puts one ``.

Change to `` where `$build-tdd`'s pocket-dimension mode puts one ``. The sibling-root and nested-`.worktrees` paths named in the rest of that sentence are unchanged and still correct.

- [ ] **Step 3: Verify `CLAUDE.md:15` needs no edit**

It names `sdd-workspace`, `task-brief`, `review-package` as rule 2's worked example. The script *names* are unchanged by this unit — only their directory moved — so the line should still be accurate. Read it and confirm. If it names a path rather than a bare script name, update the path.

- [ ] **Step 4: Update the skill count**

`README.md` says `34 skills` after unit 1. Change to `31`.

Check `CLAUDE.md`'s layout section for a count or a `skills/` enumeration; unit 1 found it carries neither, but the layout section does describe `scripts/`, and `skills/build-tdd/scripts/` is now a second place scripts live. If the description implies `scripts/` at the repo root is the only such directory, correct it.

- [ ] **Step 5: Assert no reference survives**

Run, bare:

```bash
rg --no-config -n 'executing-plans|subagent-driven-development|using-git-worktrees' --glob '!docs/superpowers/**' .; echo "rg exit=$?"
```

Expected: no hit naming any of the three as a live skill. `docs/superpowers/**` is excluded because the spec, the plans, and the inventories name them deliberately as historical record.

Note that `tests/fixtures/build-tdd/sdd-workspace-test.sh` legitimately contains the string `sdd-workspace` — that is the script's own name, which survives. A hit there is expected and correct.

- [ ] **Step 6: Commit**

```bash
git add skills/challenge/SKILL.md skills/finishing-a-development-branch/SKILL.md README.md CLAUDE.md
git commit -m "docs: re-point references to the absorbed execution skills"
```

---

### Task 7: Verify and open the pull request

**Files:** none (verification and integration only).

- [ ] **Step 1: Run the full guardrail suite bare**

Run: `just verify`

No pipe, no redirect, no `|| true`. Expected: exit 0, with `check-skill-shape: 31 skills, all rules pass` and `git-fixture-isolation-test: all 6 suites passed` among the output.

This suite takes several minutes because `verify-push-test.sh` builds worktrees. Run it in the background and read the result rather than polling in the foreground.

- [ ] **Step 2: Confirm the reduction is real**

```bash
git diff --numstat main...HEAD -- skills/ | awk '{a+=$1; d+=$2} END {printf "added=%d deleted=%d net=%+d\n", a, d, a-d}'
```

Expected: a negative net. The moved files count as added-and-deleted in this measure, so state both the raw net and the net excluding the six moved files, and record both in the PR body. If `skills/` grew once moves are discounted, stop and report it — that would mean the absorption copied three documents into a fourth.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/build-tdd-absorbs-execution-modes
gh pr create --base main --title "refactor(build-tdd): absorb the execution modes" --body "<body>"
```

The body states: the three modes and what each one is; the net line delta from Step 2 with moves discounted; that the three scripts moved rather than died, and why §4 rule 2 says so; that the two prompt templates are an argued exception to §4 rule 1; that the D&D rename is deliberately absent (§3); that attribution is deliberately untouched (§2 rule 2); and links the three inventories as the regression contract.

- [ ] **Step 4: Poll checks and merge**

Poll `gh pr checks <n> --json name,state` and `gh pr view <n> --json mergeable,mergeStateStatus` on a backing-off interval, never `--watch`. Merge only on checks green **and** state `CLEAN`. Use `--rebase`; never squash — Tasks 2 through 5 are separately revertible and that is worth keeping.

---

## Self-Review

**1. Spec coverage.** §1's disposition rows for all three skills → Tasks 3, 4, 5. §1's script-relocation clause → Task 2. §1's "every dispatched workflow mode section disappears" → the DROP rows in all three inventories, and Task 5 Step 2's rewrite of the caller declaration. §2 rule 1 → Task 1 ordered before Tasks 3–5. §2 rule 2 → Global Constraints, asserted in the PR body. §3 → Global Constraints, with the `cast`/`party`/`pocket-dimension` exception argued. §4 rule 1 → the prompt-template exception argued in File Structure. §4 rule 2 → Task 2, which moves the three scripts the spec names. §4 rule 4 → Task 1 Step 4 and the Step 2s of Tasks 3–5 are reading checks, not gates. §5 → Task 1.

**Gap found and closed:** the plan initially had the absorptions before the moves, which would have left Tasks 3–5 writing references to script paths that did not exist yet. Task 2 now runs first.

**Gap found and closed:** nothing checked that the moved scripts stay inside `list-shell-sources.sh`'s inventory. They are discovered by shebang rather than extension so the move should be transparent, but that inventory feeds `just lint`, `just format-check`, and the ripgrep-config gate — a script that silently drops out is ungated with every gate still green. Task 2 Step 6 asserts it.

**Gap found and closed:** `scripts/git-fixture-isolation-test.sh` hardcodes the fixture path and would have passed with five suites instead of six had the edit been missed, since it enumerates rather than discovers. Task 2 Step 5 asserts the new path appears in its output rather than just checking the exit code.

**2. Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task N". The `<body>` token in Task 7 Step 3 is followed by the sentence enumerating what it must contain. Tasks 3–5 Step 1 specify the structure and the behaviour rows to carry rather than embedding finished prose; the inventories are the contract, and reproducing the target document inside the plan would duplicate it into two places that then drift. This is the same deviation taken in unit 1, and it held.

**3. Type consistency.** Mode names are `cast`, `party`, and `pocket-dimension` in spec §3's table, the inventory titles, the section headings of Tasks 3–5, and the re-pointed reference in Task 6 — checked. Skill counts decrease consistently and are asserted at each deletion: 34 before, 33 after Task 3, 32 after Task 4, 31 after Task 5, 31 in the README. Script paths are `skills/build-tdd/scripts/<name>` in Task 2, in Task 5 Step 1, and in the fixture edit — checked.
