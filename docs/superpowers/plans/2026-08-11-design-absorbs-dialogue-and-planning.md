# `$design` Absorbs the Dialogue and Planning Phases — Implementation Plan

> **For agentic workers:** Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Subagents are not used for this unit.

**Goal:** Collapse the derived `brainstorming` and `writing-plans` skills into `$design` as its `council` and `inscribe` phases, so the design pipeline is one document with no caller/callee split.

**Architecture:** `$design` already sequences brainstorming → ADR review → spec review → writing-plans → plan review. That sequencing is the only reason either callee carries a "Dispatched workflow mode" section, and the only reason the eight-field charter carrier block appears three times in `$design`. Absorbing both callees into the phases that already call them deletes the split and everything that exists to serve it. A behaviour inventory is extracted from each callee first and becomes the regression contract the rewrite is read against.

**Tech Stack:** Markdown skill documents; `bash` 3.2 gates (`scripts/check-skill-shape.sh`); `just` recipes; no runtime code changes.

## Global Constraints

Copied from `docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md`:

- **§4 rule 1** — A skill is instructions, not a program. The default artifact is one `SKILL.md`. Supporting files are the exception and must be argued for.
- **§4 rule 2** — Executable code clears a bar or it does not ship: permitted only when it does something a model cannot do reliably inline.
- **§4 rule 3** — No long-lived processes. No servers, port binding, PID files, lockfiles, daemon lifecycle, or liveness checks against a previous invocation.
- **§4 rule 4** — Nothing automated asserts on prose. No gate greps Markdown for a sentence; no test pins a table row.
- **§1** — "No skill exists merely so another skill can call it. Every 'dispatched workflow mode' section disappears with the caller/callee split that created it."
- **§2 rule 1** — Write from the process, not the text. Source material is the behaviour inventories of §5, the user's global CLAUDE.md, and the first-party skills. Ideas are not copyrightable; expression is. Re-express.
- **§2 rule 2** — The MIT notice, `docs/licenses/`, and ADR 0005 do **not** come out in this unit. Attribution removal is step 5 of §6, gated on the similarity check, and is a separate plan.
- **§3** — **Do not apply the D&D skill rename in this unit.** `design` stays `design`. The rename is §6 step 6, a single mechanical pass over directories, `name:` frontmatter, and every `$invocation`. Only the *absorbed* names (`council`, `inscribe`) land here, because their directories are deleted in this unit and there is nothing left to rename later.
- **§5** — Behaviour inventories are extracted **before** writing, and serve as regression guard, independence mechanism, and YAGNI filter simultaneously.
- Repo `CLAUDE.md` — `adept` is PUBLIC. No host-specific paths, hostnames, addresses, auth headers, API keys, or session state. Use `$WORK` for repository roots in documents.
- Branch: `feat/design-absorbs-dialogue-and-planning`. Never commit to `main`.

## Measured starting state

Established by direct measurement against the tree at `main` (`7e7f969`), not assumed:

| Fact | Value |
|---|---|
| `skills/design/SKILL.md` | 350 lines |
| `skills/brainstorming/SKILL.md` | 203 lines (sole file in the directory) |
| `skills/writing-plans/SKILL.md` | 199 lines (sole file in the directory) |
| Backticked `` `$brainstorming` `` / `` `$writing-plans` `` invocations anywhere in the repo | **0** |
| Bare-name mentions outside the two directories | 8, in 4 files |
| Skill count before | 36 |
| Skill count after this unit | 34 |

The eight mention sites, in full:

```
CLAUDE.md:19                              historical narrative — the deleted visual companion
skills/subagent-driven-development/:437   "- **writing-plans** - Creates the plan this skill executes"
skills/executing-plans/SKILL.md:80        "- **writing-plans** - Creates the plan this skill executes"
skills/design/SKILL.md:64                 "Pass the complete charter to brainstorming ..."
skills/design/SKILL.md:77                 "Use `brainstorming` first if the design space is wide. ..."
skills/design/SKILL.md:80                 "... rather than invoking `writing-plans` itself,"
skills/design/SKILL.md:303                "Pass the same complete charter and root interaction to `writing-plans`:"
skills/design/SKILL.md:314                "Use `writing-plans` to write the plan under"
```

Because there are zero backticked invocations, `scripts/check-skill-shape.sh` rule 4 will **not** catch a missed reference in this unit. The bare-name sweep of Task 4 is the only guard, and it is a `rg` sweep asserted to return no matches. Do not rely on the shape gate here.

## File Structure

**Created:**
- `docs/superpowers/inventories/brainstorming.md` — behaviour inventory, one row per observable behaviour, with a KEEP/DROP verdict and the reason. The regression contract for the `council` phase.
- `docs/superpowers/inventories/writing-plans.md` — same, for the `inscribe` phase.

`docs/superpowers/inventories/` is new. It is argued for rather than assumed: §5 requires the inventory to exist as a durable design artifact ("the rewritten skill is read against it"), and §2 requires it as the provenance for "written from the process, not the text" when the step-5 similarity gate runs. A list that lives only in a session transcript satisfies neither. These are documents, not skill supporting files, so §4 rule 1 does not apply to them.

**Modified:**
- `skills/design/SKILL.md` — gains a `council` phase (§1) and an `inscribe` phase (§4); loses the two repeated charter carrier blocks that existed to cross a skill boundary.
- `skills/subagent-driven-development/SKILL.md:437` — integration bullet re-pointed.
- `skills/executing-plans/SKILL.md:80` — integration bullet re-pointed.
- `CLAUDE.md:19` — narrative reference made past-tense-explicit.

**Deleted:**
- `skills/brainstorming/` (whole directory)
- `skills/writing-plans/` (whole directory)

---

### Task 1: Behaviour inventories for both absorbed skills

**Files:**
- Create: `docs/superpowers/inventories/brainstorming.md`
- Create: `docs/superpowers/inventories/writing-plans.md`

**Interfaces:**
- Produces: two inventory documents whose KEEP rows are the regression contract Tasks 2 and 3 are checked against, and whose DROP rows are the deliberate deletions those tasks must not silently reintroduce.

This task exists before any rewriting because §5 makes the extraction order load-bearing: writing from an extracted behaviour list rather than from source text is *how* new expression arises, and §2's similarity gate later confirms it. Doing it after the rewrite would make it a rationalisation.

- [ ] **Step 1: Create the inventory directory and write the `brainstorming` inventory**

Each row states an **observable behaviour** — what the skill makes the agent *do* — never a sentence from the source. A verdict of KEEP means the behaviour must be traceable to a line in the rewritten `$design`; DROP means it is deliberately deleted and must not reappear.

`docs/superpowers/inventories/brainstorming.md`:

```markdown
# Behaviour inventory — `brainstorming` (absorbed into `$design` as `council`)

Extracted from `skills/brainstorming/SKILL.md` at commit `7e7f969` before any
rewriting, per the rewrite spec §5. Rows are observable behaviours, not wording.
KEEP rows are the regression contract for the `council` phase. DROP rows are
deliberate deletions — the YAGNI filter of §5 — and must not reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Read project state — files, docs, recent commits — before asking anything | KEEP | The cheapest correction of a wrong premise |
| 2 | Assess scope before detail: flag a request spanning independent subsystems instead of refining one of them | KEEP | Prevents spending the whole dialogue on a project that needed decomposing |
| 3 | Decompose an oversized project into sub-projects, each getting its own spec → plan → implementation cycle | KEEP | The only stated remedy for behaviour 2 |
| 4 | Ask exactly one question per message | KEEP | Named in spec §5 as a lesson that lives in an unremarkable sentence |
| 5 | Prefer multiple-choice questions over open-ended where the choice is closed | KEEP | Cheap to answer, and forces the asker to have thought |
| 6 | Propose 2–3 approaches with trade-offs before settling, recommendation first | KEEP | Named in §5's key principles as surviving |
| 7 | Present the design in sections scaled to complexity, confirming after each | KEEP | Incremental validation; a whole design rejected at the end is wasted |
| 8 | Refuse to skip the design for a "simple" project; allow the design to be short | KEEP | Explicitly an anti-pattern section in the source; the failure it prevents is unexamined assumptions |
| 9 | Design for isolation: one purpose per unit, defined interfaces, independently understandable | KEEP | Directly serves the repo's own file-size and clarity standards |
| 10 | In an existing codebase, follow established patterns and include targeted improvements to code being touched, but not unrelated refactoring | KEEP | Scope discipline; the "don't propose unrelated refactoring" half is the load-bearing one |
| 11 | Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit it | KEEP | The durable artifact; `$design`'s context checkpoint depends on it existing |
| 12 | Self-review the written spec for placeholders, internal contradiction, scope, and two-way ambiguity | KEEP | Catches the defect class cheapest at the spec |
| 13 | Apply YAGNI to the design itself, removing unnecessary features | KEEP | Driver 2 of the rewrite |
| 14 | Announce the skill and its resolved mode at start | DROP | A phase inside a document does not announce itself; the mode it announced does not survive |
| 15 | Carry a "dispatched workflow mode" section mapping each gate to a dispatched replacement | DROP | §1: the section exists only because `$design` calls this skill. The call is gone |
| 16 | Return design-changing ambiguity through a `SCOPE CHECKPOINT` block reproduced in full | DROP | `$design`'s own "External scope authority" section already owns the charter and the checkpoint. Two copies is the drift surface §1 objects to |
| 17 | Render the process as a `dot` digraph duplicating the numbered checklist | DROP | Two representations of one sequence; the numbered phases are the one a reader follows |
| 18 | Create a task per checklist item and complete them in order | DROP | Restates the phase order as bookkeeping; the phases are already ordered |
| 19 | Stop at a HARD-GATE until the user approves the design | KEEP | The gate itself survives; its dispatched-mode escape hatch (row 15) does not |
| 20 | Terminate by invoking `writing-plans`, and no other skill | DROP | Both are phases of one document now; there is no invocation and no terminal state to police |
| 21 | Ask the user to review the written spec and wait for a response | DROP | `$design` step 3 already adversarially reviews the spec; the source itself says so |
| 22 | Offer a browser visual companion for questions better shown than described | DROP | Already deleted in `aca0ba2` under §4 rule 3; recorded here so the rewrite does not reintroduce it |
```

- [ ] **Step 2: Write the `writing-plans` inventory**

`docs/superpowers/inventories/writing-plans.md`:

```markdown
# Behaviour inventory — `writing-plans` (absorbed into `$design` as `inscribe`)

Extracted from `skills/writing-plans/SKILL.md` at commit `7e7f969` before any
rewriting, per the rewrite spec §5. Rows are observable behaviours, not wording.
KEEP rows are the regression contract for the `inscribe` phase. DROP rows are
deliberate deletions — the YAGNI filter of §5 — and must not reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Write for an engineer with zero repo context and unknown taste | KEEP | The premise that makes every other rule in the phase necessary |
| 2 | Map which files are created and modified, and each one's responsibility, before defining tasks | KEEP | This is where decomposition is actually decided |
| 3 | Prefer smaller focused files; split by responsibility, not by technical layer | KEEP | Repo standard, and it makes edits more reliable |
| 4 | Follow established patterns in an existing codebase rather than restructuring unilaterally | KEEP | Same discipline as `council` row 10 |
| 5 | Right-size a task to the smallest unit carrying its own test cycle and worth a reviewer's gate | KEEP | The rule that stops both 20-task busywork and 3-task monoliths |
| 6 | Fold setup, config, scaffolding, and docs into the task whose deliverable needs them | KEEP | Corollary of row 5; prevents orphan setup tasks |
| 7 | Split tasks only where a reviewer could reject one and approve its neighbour | KEEP | The operational test for row 5 |
| 8 | End every task with an independently testable deliverable | KEEP | What makes a task reviewable at all |
| 9 | Make each step one action of roughly 2–5 minutes | KEEP | Bite-sized granularity; a step that spans an hour is a task |
| 10 | Order steps as failing test → confirm it fails → minimal implementation → confirm it passes → commit | KEEP | TDD, and the "confirm it fails" step is the one people skip |
| 11 | Start the plan with a fixed header: goal, architecture, tech stack, global constraints | KEEP | Global constraints bind every task implicitly; without the block they are re-derived per task |
| 12 | Copy project-wide requirements into Global Constraints verbatim, with exact values | KEEP | A paraphrased version floor is a wrong version floor |
| 13 | Give each task exact file paths, an Interfaces block naming what it consumes and produces, and complete code in every step | KEEP | A context-free implementer cannot infer a signature |
| 14 | Refuse named placeholder patterns — "TBD", "add appropriate error handling", "similar to Task N", references to undefined types | KEEP | Enumerated failures, not a vague exhortation; this is why the list is a list |
| 15 | Repeat code rather than cross-referencing another task, since tasks are read out of order | KEEP | The one place DRY is deliberately not applied, and the reason is stated |
| 16 | Self-review the finished plan for spec coverage, placeholders, and type-name consistency across tasks | KEEP | Catches the `clearLayers()`/`clearFullLayers()` class before an implementer hits it |
| 17 | Add a task when self-review finds a spec requirement with no task | KEEP | Makes row 16 actionable rather than advisory |
| 18 | Suggest splitting into one plan per subsystem when the spec spans several | KEEP | The plan-level counterpart of `council` row 2 |
| 19 | Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` | KEEP | Durable artifact; `$design`'s context checkpoint depends on it |
| 20 | Announce the skill and its resolved mode at start | DROP | Same as `council` row 14 |
| 21 | Carry a "dispatched workflow mode" section defining caller-owned sequencing | DROP | §1: exists only because `$design` calls this skill |
| 22 | Consume and carry forward an eight-field scope charter from the caller | DROP | No skill boundary is crossed any more; `$design` holds the charter once |
| 23 | Offer the user a choice between subagent-driven and inline execution at the end | DROP | `$build-tdd` picks the execution mode from what the plan looks like; the source's own dispatched mode already deletes this |
| 24 | Note that an isolated worktree should have been created by `using-git-worktrees` | DROP | Workspace setup belongs to `$build-tdd` per §1's disposition table |
| 25 | Name `subagent-driven-development` or `executing-plans` as the required next skill | DROP | Both are absorbed into `$build-tdd` in a later unit; naming them here would be a phantom reference the moment that lands |
```

- [ ] **Step 3: Verify the inventories are complete against their sources**

Read `skills/brainstorming/SKILL.md` and `skills/writing-plans/SKILL.md` top to bottom, and confirm every section of each source maps to at least one inventory row. This is a reading check, not a gate — §4 rule 4 forbids automating an assertion over prose.

Expected: every heading in both sources is represented. If a section maps to no row, add the row before proceeding — a behaviour that reaches neither KEEP nor DROP is one that gets lost by inertia, which is exactly what §5 says the inventory exists to prevent.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/inventories/
git commit -m "docs: extract behaviour inventories for the two absorbed skills"
```

---

### Task 2: Absorb `brainstorming` into `$design` as the `council` phase

**Files:**
- Modify: `skills/design/SKILL.md` — section `## 1. Spec + ADR` (currently lines 62–110) and the charter carrier block at lines 64–73
- Delete: `skills/brainstorming/SKILL.md` and its directory

**Interfaces:**
- Consumes: `docs/superpowers/inventories/brainstorming.md` from Task 1 — every KEEP row is a requirement of this task.
- Produces: a `## 1. Council — dialogue to spec + ADR` section in `skills/design/SKILL.md` that the `inscribe` task (Task 3) leaves untouched.

- [ ] **Step 1: Rewrite section 1 of `skills/design/SKILL.md`**

Retitle `## 1. Spec + ADR` to `## 1. Council — dialogue to spec + ADR`.

Delete the eight-field charter carrier block at lines 64–73 and the sentence introducing it (`Pass the complete charter to brainstorming without changing root interaction:`). It exists to hand a charter across a skill boundary that no longer exists; `## External scope authority` above already freezes the charter for the whole document. Replace with a single sentence stating that the charter frozen there governs every phase below.

Replace `Use `brainstorming` first if the design space is wide.` and the dispatched-caller paragraph that follows it (lines 77 through the sentence `Say so when you invoke it.` in line 82) with the council dialogue itself, carrying inventory KEEP rows 1–13 and 19. Structure it as: read project state first; scope check and decompose before detail; one question per message, multiple-choice where the choice is closed; 2–3 approaches with trade-offs and a recommendation; design presented in sections scaled to complexity with confirmation after each; the design-for-isolation tests; the existing-codebase discipline; then the spec written to `docs/superpowers/specs/` and committed; then the self-review.

Keep the HARD-GATE (KEEP row 19) as prose in this section: no implementation action until a design has been presented and approved. Do not reproduce the source's `<HARD-GATE>` tag — the tag was an addressing mechanism for a separate document being invoked, and this is now a numbered phase in the document that owns the gate.

Keep the "too simple to need a design" refusal (KEEP row 8) as two or three sentences, not its own section.

Everything already in section 1 below the brainstorming paragraph — the ADR guidance, the ADR-index rules, the AI-surface eval plan, the security threat model — is unchanged first-party content. Do not touch it.

- [ ] **Step 2: Confirm every KEEP row is traceable**

Read `docs/superpowers/inventories/brainstorming.md` beside the rewritten section. For each of the 14 KEEP rows, point to the line or lines in `skills/design/SKILL.md` that carry it. For each of the 8 DROP rows, confirm it is absent.

Expected: 14 KEEP rows traced, 8 DROP rows absent. A KEEP row with no line is a regression — add it before proceeding. This is the human review §5 names; it is deliberately not automated, per §4 rule 4.

- [ ] **Step 3: Delete the absorbed skill**

```bash
git rm -r skills/brainstorming
```

- [ ] **Step 4: Run the shape gate**

Run: `just shape-check`

Expected: `check-skill-shape: 35 skills, all rules pass`

The count drops from 36 to 35. If the gate instead reports an unresolved `$invocation`, a backticked reference was introduced by the rewrite — fix it rather than adjusting the gate.

- [ ] **Step 5: Commit**

```bash
git add skills/design/SKILL.md
git commit -m "refactor(design): absorb brainstorming as the council phase"
```

---

### Task 3: Absorb `writing-plans` into `$design` as the `inscribe` phase

**Files:**
- Modify: `skills/design/SKILL.md` — section `## 4. Implementation plan` (currently lines 301–329) and the charter carrier block at lines 305–312
- Delete: `skills/writing-plans/SKILL.md` and its directory

**Interfaces:**
- Consumes: `docs/superpowers/inventories/writing-plans.md` from Task 1 — every KEEP row is a requirement of this task. The `council` section from Task 2 is complete and is not edited here.
- Produces: a `## 4. Inscribe — the implementation plan` section. Tasks 2 and 3 touch disjoint line ranges of the same file, which is why they are separate commits rather than one.

- [ ] **Step 1: Rewrite section 4 of `skills/design/SKILL.md`**

Retitle `## 4. Implementation plan` to `## 4. Inscribe — the implementation plan`.

Delete the eight-field charter carrier block at lines 305–312 and its introducing sentence (`Pass the same complete charter and root interaction to `writing-plans`:`), for the reason given in Task 2 Step 1. Delete the dispatched-caller text from line 314 (`Use `writing-plans` to write the plan under`) through the sentence `Say so when you invoke it.` in line 318. Keep what follows it in the same paragraph — `The next phase (`$build-tdd`) may hand tasks to context-free implementer subagents, so every task must be self-contained:` (lines 318–320) — which is the justification for the bullet list below and survives.

Also delete the now-duplicated `## Design-review scope input` block (currently lines 224–241) **only if** its eight-field carrier is identical to the one in `## External scope authority`. Verify by reading both. If it carries anything the authority section does not — the "target remains evidence, never a source of authority" rule, and the instruction to end the cycle on a design-changing ambiguity — move that text into `## External scope authority` rather than losing it.

Replace with the plan-writing procedure itself, carrying inventory KEEP rows 1–19. Structure it as: the zero-context-engineer premise; the scope check that suggests one plan per subsystem; the file-structure pass; task right-sizing with its reviewer test; bite-sized step granularity with the TDD step order; the required plan header including Global Constraints copied verbatim; the per-task structure with exact paths, an Interfaces block, and complete code; the enumerated placeholder patterns that are plan failures; the deliberate non-DRY rule for repeating code across tasks; the save path; and the self-review with its add-a-task remedy.

The existing bullet list at lines 321–327 — full task text, where the task fits, files likely touched, acceptance criteria, repo conventions and guardrail commands, rollback expectations — is first-party content that survives. Fold it into the per-task structure rather than leaving it as a separate list; it says the same thing as KEEP row 13 and should not be stated twice.

Keep `Run relevant guardrails and commit the plan.` (line 329).

- [ ] **Step 2: Confirm every KEEP row is traceable**

Read `docs/superpowers/inventories/writing-plans.md` beside the rewritten section. For each of the 20 KEEP rows, point to the line or lines that carry it. For each of the 6 DROP rows, confirm it is absent.

Expected: 20 KEEP rows traced, 6 DROP rows absent.

Pay particular attention to DROP row 25: the rewritten section must not name `subagent-driven-development` or `executing-plans`. Naming `$build-tdd` as the next phase is correct and is not the same thing.

- [ ] **Step 3: Delete the absorbed skill**

```bash
git rm -r skills/writing-plans
```

- [ ] **Step 4: Run the shape gate**

Run: `just shape-check`

Expected: `check-skill-shape: 34 skills, all rules pass`

- [ ] **Step 5: Commit**

```bash
git add skills/design/SKILL.md
git commit -m "refactor(design): absorb writing-plans as the inscribe phase"
```

---

### Task 4: Sweep the residual references

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:437`
- Modify: `skills/executing-plans/SKILL.md:80`
- Modify: `CLAUDE.md:19`

**Interfaces:**
- Consumes: the deletions from Tasks 2 and 3.
- Produces: a repository in which no document names a skill that does not exist.

This task is separate from Tasks 2 and 3 because it touches three files that are not `skills/design/SKILL.md`, and because a reviewer could reasonably approve the absorption and reject a reference edit.

`scripts/check-skill-shape.sh` rule 4 does **not** cover these: it scans only the backticked `` `$name` `` form, and all three sites use bare names. The `rg` assertion in Step 4 is the whole guard.

- [ ] **Step 1: Re-point the two integration bullets**

Both files carry the identical line `- **writing-plans** - Creates the plan this skill executes`. Both skills are themselves absorbed into `$build-tdd` in a later unit, but leaving them naming a deleted skill in the interim is a phantom reference.

In `skills/subagent-driven-development/SKILL.md:437` and `skills/executing-plans/SKILL.md:80`, replace that line with:

```markdown
- **`$design`** - Its `inscribe` phase writes the plan this skill executes
```

- [ ] **Step 2: Correct the narrative reference in `CLAUDE.md`**

`CLAUDE.md:19` currently reads, in part: `The `brainstorming` skill shipped a Node HTTP server with shell PID lifecycle management`. After this unit there is no `brainstorming` skill, so the present-tense naming is wrong.

Change that clause to: `The inherited `brainstorming` skill — since absorbed into `$design` — shipped a Node HTTP server with shell PID lifecycle management`.

Leave the rest of the sentence and the paragraph unchanged: it is the worked example that justifies §4 rule 3, and the deletion is the point it makes.

- [ ] **Step 3: Confirm the skill inventory in `CLAUDE.md` is still accurate**

Read `CLAUDE.md`'s layout section. If it states a skill count or enumerates `skills/` contents, update it to 34. If it does not, change nothing.

- [ ] **Step 4: Assert no reference survives**

Run this, bare:

```bash
rg --no-config -n 'brainstorming|writing-plans' --glob '!docs/superpowers/**' .; echo "rg exit=$?"
```

Expected: only `CLAUDE.md:19` (the corrected historical clause) and the two re-pointed bullets' surrounding context if they still mention the words, with `rg exit=1` if nothing else matches. Any hit naming either as a live skill to invoke is a miss — fix it.

`docs/superpowers/**` is excluded because the spec, this plan, and both inventories name the skills deliberately as historical record.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md CLAUDE.md
git commit -m "docs: re-point references to the absorbed skills"
```

---

### Task 5: Verify and open the pull request

**Files:** none (verification and integration only).

**Interfaces:**
- Consumes: Tasks 1–4 complete and committed.

- [ ] **Step 1: Run the full guardrail suite bare**

Run: `just verify`

Run it with no pipe, no redirect, and no `|| true` — a pipeline returns the last command's status and hides the real failure. Expected: exit 0, with `check-skill-shape: 34 skills, all rules pass` among the output.

- [ ] **Step 2: Confirm the reduction is real**

```bash
git diff --stat main...HEAD
```

Expected: `skills/brainstorming/SKILL.md` and `skills/writing-plans/SKILL.md` deleted (203 and 199 lines), `skills/design/SKILL.md` net changed, two inventories added. Record the net line delta across `skills/` in the PR body — the rewrite's first driver is less machinery, and a unit that grows `skills/` has not delivered it.

If `skills/` grew, stop and report it rather than opening the PR. That is a design failure, not a formatting detail: it would mean the absorption copied two documents into a third instead of collapsing them.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/design-absorbs-dialogue-and-planning
gh pr create --base main --title "refactor(design): absorb the dialogue and planning phases" --body "<body>"
```

The body states: what the two phases are, the net line delta from Step 2, that the D&D rename is deliberately not in this diff (spec §3), that attribution is deliberately not removed (spec §2 rule 2, gated on step 5's similarity check), and links both inventories as the regression contract a reviewer should read the rewrite against.

- [ ] **Step 4: Poll checks and merge**

Poll `gh pr checks <n> --json name,state` and `gh pr view <n> --json mergeable,mergeStateStatus` on a backing-off interval, never `--watch`. Merge only on checks green **and** state `CLEAN`. Use `--rebase`; never squash — per-commit history is load-bearing here, since Tasks 2 and 3 are separately revertible.

---

## Self-Review

**1. Spec coverage.** §1's disposition table rows for `brainstorming` and `writing-plans` → Tasks 2 and 3. §1's "every dispatched workflow mode section disappears" → the DROP rows and the carrier-block deletions in both. §2 rule 1 (write from the process) → Task 1 before Tasks 2–3, enforced by ordering. §2 rule 2 (attribution stays) → Global Constraints, and asserted in the PR body. §3 (rename lands last) → Global Constraints, with the `council`/`inscribe` exception argued. §4 rules 1–4 → Global Constraints; rule 4 is why Task 1 Step 3 and Tasks 2–3 Step 2 are reading checks rather than gates. §5 (inventory as regression guard, independence mechanism, YAGNI filter) → Task 1, with all three purposes served by the KEEP/DROP/reason columns.

**Gap found and closed:** §5's "behaviours examined and rejected are deleted deliberately rather than carried forward by inertia" needed the DROP rows to carry a *reason*, not just a verdict, or the deletion is not deliberate. The reason column is required in both inventories.

**Gap found and closed:** the plan originally assumed the shape gate would catch missed references. Measurement showed zero backticked invocations, so it would not. Task 4 Step 4 now carries an explicit `rg` assertion, and the task text says the gate does not cover it.

**2. Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task N". The one `<body>` token in Task 5 Step 3 is immediately followed by the sentence enumerating what it must contain, which is the content an engineer needs. Tasks 2 and 3 Step 1 specify structure and the behaviour rows to carry rather than embedding the finished prose — the inventories are the contract, and reproducing the target document inside the plan would duplicate it into two places that then drift.

**3. Type consistency.** Phase names are `council` and `inscribe` in the spec §3 table, the inventory titles, the section headings of Tasks 2 and 3, and the re-pointed bullet in Task 4 — checked. Skill counts are consistent and decreasing: 36 before, 35 after Task 2, 34 after Task 3, asserted at both points. Inventory row counts are consistent: `brainstorming` 22 rows (14 KEEP, 8 DROP), `writing-plans` 26 rows (20 KEEP, 6 DROP), and Tasks 2–3 Step 2 assert those same totals.

**Amended during execution.** Task 1 Step 3's completeness check found `writing-plans`' `## Remember` section mapping to no row: "exact commands with expected output" was carried by none of rows 1–25. Added as row 26 (KEEP), appended rather than inserted so that the "DROP row 25" citation in Task 3 Step 2 stays valid. This is the check doing its job — a behaviour that reaches neither KEEP nor DROP is the inertia loss §5 exists to prevent.
