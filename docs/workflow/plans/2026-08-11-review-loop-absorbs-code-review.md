# `$review-loop` Absorbs the Code-Review Request — Implementation Plan

> **For agentic workers:** Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Subagents are not used for this unit.

**Goal:** Delete `requesting-code-review` by moving its dispatch template to the mode that actually uses it and confirming its procedural content is already carried by `$review-loop` and `$build-tdd`.

**Architecture:** This unit is mostly a deletion. `requesting-code-review` is a 108-line wrapper around a 172-line template; measurement against the tree shows that almost every behaviour in the wrapper is already stated at one of its two absorbing destinations. The template's only consumer is `$build-tdd`'s party mode, alongside the two dispatch templates already in that directory. So the template moves to its consumer, the handful of genuinely uncovered behaviours are added where they belong, and 108 lines of restatement go.

**Tech Stack:** Markdown skill documents; `scripts/check-skill-shape.sh`; `just` recipes. No executable code changes.

## Global Constraints

Copied from `docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md`:

- **§4 rule 1** — A skill is instructions, not a program. The default artifact is one `SKILL.md`. Supporting files are the exception and must be argued for.
- **§4 rule 4** — Nothing automated asserts on prose.
- **§1** — "No skill exists merely so another skill can call it."
- **§2 rule 1** — Write from the process, not the text; re-express.
- **§2 rule 2** — Attribution removal is **not** in this unit. `licenses/` and the MIT notice stay untouched; that is §6 step 5.
- **§3** — **Do not apply the D&D skill rename.** `review-loop` stays `review-loop`, `challenge` stays `challenge`. Only the absorbed name `petition-council` lands here.
- **§5** — Behaviour inventory extracted **before** writing.
- Repo `CLAUDE.md` — `adept` is PUBLIC. No host-specific paths or session state.
- Branch: `feat/review-loop-absorbs-code-review`. Never commit to `main`.

## Measured starting state

Measured against `main` at `eec533f`:

| Path | Lines |
|---|---|
| `skills/requesting-code-review/SKILL.md` | 108 |
| `skills/requesting-code-review/code-reviewer.md` | 172 |
| `skills/review-loop/SKILL.md` | 559 |
| `skills/challenge/SKILL.md` | 348 |

Skill count: 31 before, 30 after.

**Consumers of the skill or its template — two, both bare-name:**

```
skills/build-tdd/SKILL.md:207    "`requesting-code-review`'s `code-reviewer.md`, on the most capable model."
skills/challenge/SKILL.md:289    "... `requesting-code-review` and `$build-tdd`'s task reviewer — grade ..."
```

No backticked `` `$requesting-code-review` `` invocation exists, so as in units 1 and 2 the shape gate cannot catch a missed reference. The `rg` sweep in Task 4 is the only guard.

### What the destinations already carry

This is the finding that determines the unit's shape. Checked directly rather than assumed:

| `requesting-code-review` behaviour | Already stated at | Evidence |
|---|---|---|
| Dispatch a reviewer with crafted context, never session history | `$build-tdd` party | "Subagents inherit nothing"; "construct exactly what each one needs" |
| Base is the commit recorded before the work — never `HEAD~1` | `$build-tdd` party | "using the BASE you recorded **before** dispatching — never `HEAD~1`, which silently drops all but the last commit of a multi-commit task" |
| Fix Critical immediately, Important before proceeding, note Minor | `$build-tdd` party | the fix-subagent rule and the Minor-to-ledger rule |
| Review after each task in subagent-driven development | `$build-tdd` party | the per-task loop, step 6 |
| Push back when the reviewer is wrong, with reasoning | `$review-loop` | "its recommendation is input, not instruction — you own the disposition" (`:325`), plus the whole disposition system |
| Dispatch the reviewer in a subagent | `$review-loop` | The Loop step 1: "Run `$challenge` in a **subagent**" |

Six of the skill's nine behaviours are already carried. The unit therefore adds very little text and deletes 108 lines.

**`petition-council` is applied to an existing step, not to a new section.** Spec §3 says the absorbed names survive "as named phases inside whatever absorbs them". `$review-loop`'s The Loop step 1 — dispatch `$challenge` in a subagent under the charter — *is* the petition. Naming it costs one line. Inventing a section to justify the name would add the surface this whole rewrite exists to remove.

## File Structure

**Created:**
- `docs/superpowers/inventories/requesting-code-review.md`

**Moved with `git mv`:**
- `skills/requesting-code-review/code-reviewer.md` → `skills/build-tdd/code-reviewer.md`

The template joins `implementer-prompt.md` and `task-reviewer-prompt.md`, which are already there and which `$challenge:289` groups it with on the shared `Critical / Important / Minor` scale. It is the final-review counterpart to the per-task reviewer, consumed by the same mode. This is the same argued exception to §4 rule 1 taken in unit 2, and it follows the precedent §1 itself set by relocating `subagent-driven-development`'s scripts to their consumer rather than to the skill's absorbing destination.

**Modified:**
- `skills/review-loop/SKILL.md` — names step 1 the petition, and gains the two uncovered behaviours.
- `skills/build-tdd/SKILL.md:207` — template reference repointed to the local path.
- `skills/challenge/SKILL.md:289` — severity-scale reference repointed.
- `README.md` — skill count.

**Deleted:**
- `skills/requesting-code-review/`

---

### Task 1: Behaviour inventory

**Files:**
- Create: `docs/superpowers/inventories/requesting-code-review.md`

**Interfaces:**
- Produces: the regression contract for Tasks 2 and 3.

This inventory uses **three** verdicts rather than two, because the measured
finding above makes the usual KEEP/DROP split lossy:

- **ADD** — must be written at a destination in this unit.
- **CARRIED** — already stated at a named destination. Verify it is there; do
  **not** restate it. A CARRIED row that turns out not to be present becomes an
  ADD row.
- **DROP** — deliberately deleted, with a reason.

The distinction matters: a CARRIED row recorded as KEEP invites a duplicate, and
duplicating a rule across two documents is the drift surface §1 objects to. A
CARRIED row recorded as DROP loses the audit trail that says where it went.

- [ ] **Step 1: Write the inventory**

Read `skills/requesting-code-review/SKILL.md` and `code-reviewer.md` in full
first. Every CARRIED row must name its destination **and** the evidence — the
line or phrase that carries it — so the claim is checkable rather than asserted.

Behaviours to cover, at minimum: the crafted-context/no-session-history rule;
review timing (after each task, after a major feature, before merge to main, and
the optional cases — when stuck, before refactoring, after a complex bug fix);
computing the base correctly and never `HEAD~1`; filling the template's four
placeholders; acting on findings by severity; pushing back with technical
reasoning when the reviewer is wrong; never skipping review because the change
looks simple; the reviewer's read-only constraint on the checkout; and the
example transcript.

The read-only constraint deserves its own row and close attention: it lives in
the *template*, not the wrapper, and says a review must not mutate the working
tree, index, HEAD, or branch state, checking out into a separate worktree if it
needs another revision. That is a real safety rule and it moves with the file
rather than being restated.

- [ ] **Step 2: Verify the inventory against both sources**

Read both files top to bottom and confirm every heading maps to at least one
row. A reading check, not a gate — §4 rule 4.

- [ ] **Step 3: Verify every CARRIED row against its named destination**

For each CARRIED row, open the destination and confirm the evidence is actually
there at the quoted wording. This is the step that makes a three-verdict
inventory safe: a CARRIED row is a claim that deletion is lossless, and an
unverified one silently deletes a behaviour.

Any row that fails becomes ADD, and Task 2 or 3 gains it.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/inventories/
git commit -m "docs: extract the behaviour inventory for requesting-code-review"
```

---

### Task 2: Move the template to its consumer

**Files:**
- Move: `skills/requesting-code-review/code-reviewer.md` → `skills/build-tdd/code-reviewer.md`
- Modify: `skills/build-tdd/SKILL.md:207`

**Interfaces:**
- Produces: `skills/build-tdd/code-reviewer.md`, the path Task 4's sweep expects.

- [ ] **Step 1: Move it**

```bash
git mv skills/requesting-code-review/code-reviewer.md skills/build-tdd/code-reviewer.md
```

- [ ] **Step 2: Repoint the reference in `$build-tdd`**

Line 207 currently reads, across two lines:

```
After the last task, dispatch the whole-branch review using
`requesting-code-review`'s `code-reviewer.md`, on the most capable model.
```

Change to name the local file as a link, matching how the same section already
links `implementer-prompt.md` and `task-reviewer-prompt.md`:

```
After the last task, dispatch the whole-branch review with
[code-reviewer.md](code-reviewer.md), on the most capable model.
```

- [ ] **Step 3: Confirm no dangling relative link**

The template's own body contains no relative links out of its directory — verify
by reading it. If it links to a sibling that did not move, fix the link now
rather than leaving a path that resolves only from the old location.

- [ ] **Step 4: Commit**

```bash
git add -A skills/build-tdd skills/requesting-code-review
git commit -m "refactor(build-tdd): move the code-reviewer template to its consumer"
```

---

### Task 3: Name the petition and add what is not carried

**Files:**
- Modify: `skills/review-loop/SKILL.md`
- Delete: `skills/requesting-code-review/`

**Interfaces:**
- Consumes: the inventory's ADD rows from Task 1.

- [ ] **Step 1: Name The Loop's step 1 the petition**

`$review-loop`'s The Loop step 1 dispatches `$challenge` in a subagent under the
charter. Name it — one clause, in the existing step, of the form "**petition the
council**". Do not add a section, do not restate the step, and do not rename the
heading `## The Loop`.

- [ ] **Step 2: Add only the ADD rows**

Write each ADD row from Task 1 at the destination its row names. Expect this to
be a small number of sentences. Do not write a CARRIED row anywhere: it is
already stated, and a second statement is the drift surface.

If Task 1 Step 3 promoted no rows and the ADD set is empty apart from the naming
in Step 1, that is a legitimate outcome — say so in the commit message rather
than inventing content to fill the section. A skill that was entirely
restatement is a finding, not a gap.

- [ ] **Step 3: Delete the absorbed skill**

```bash
git rm -r skills/requesting-code-review
```

Then check for a leftover **empty** directory, which git cannot see because it
does not track empty directories and which unit 2 hit:

```bash
ls -d skills/requesting-code-review 2>/dev/null && rmdir skills/requesting-code-review
```

`rmdir` refuses a non-empty directory, so it self-verifies.

- [ ] **Step 4: Run the shape gate**

Run: `just shape-check`

Expected: `check-skill-shape: 30 skills, all rules pass`

- [ ] **Step 5: Commit**

```bash
git add -A skills/
git commit -m "refactor(review-loop): absorb requesting-code-review as the petition-council phase"
```

---

### Task 4: Sweep the residual references

**Files:**
- Modify: `skills/challenge/SKILL.md:289`
- Modify: `README.md`

- [ ] **Step 1: Repoint the severity-scale reference**

`skills/challenge/SKILL.md:289` reads:

```
The vendored superpowers review skills — `requesting-code-review` and `$build-tdd`'s task reviewer — grade `Critical / Important / Minor` instead.
```

Both named things are now `$build-tdd` templates. Rewrite the clause to name
them as what they are — `$build-tdd`'s task and whole-branch reviewers — rather
than as two skills. Keep the rest of the sentence and the mapping table
unchanged; `$challenge` owns that enum and the conversion.

The phrase "the vendored superpowers review skills" also stops being accurate
once neither is a skill. Adjust it, but do **not** remove the attribution
itself — §2 rule 2 puts that in step 5, gated on the similarity check.

- [ ] **Step 2: Update the skill count**

`README.md` says `31 skills`. Change to `30`.

- [ ] **Step 3: Assert no reference survives**

Run, bare:

```bash
rg --no-config -n 'requesting-code-review' --glob '!docs/superpowers/**' .; echo "rg exit=$?"
```

Expected: `rg exit=1`, no matches. `docs/superpowers/**` is excluded because the
spec, the plans, and the inventory name it deliberately as historical record.

- [ ] **Step 4: Commit**

```bash
git add skills/challenge/SKILL.md README.md
git commit -m "docs: re-point references to the absorbed code-review skill"
```

---

### Task 5: Verify and open the pull request

- [ ] **Step 1: Run the full guardrail suite bare**

Run: `just verify`

No pipe, no redirect, no `|| true`. Expected: exit 0 with
`check-skill-shape: 30 skills, all rules pass`. It takes several minutes because
`verify-push-test.sh` builds worktrees — run it in the background and read the
result rather than polling in the foreground.

- [ ] **Step 2: Confirm the reduction**

```bash
git diff --numstat -M main...HEAD -- skills/ | awk '{a+=$1; d+=$2} END {printf "added=%d deleted=%d net=%+d\n", a, d, a-d}'
```

Expected: net close to −108, since the template moves rather than changing.
Record it in the PR body.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/review-loop-absorbs-code-review
gh pr create --base main --title "refactor(review-loop): absorb the code-review request" --body "<body>"
```

The body states: that this unit is mostly a deletion and why — six of nine
behaviours were already carried, with the destination named for each; where the
template went and the argument for that placement; that `petition-council` names
an existing step rather than a new section; the net line delta; that the D&D
rename is deliberately absent (§3) and attribution deliberately untouched (§2
rule 2); and links the inventory, calling out its three-verdict format and the
CARRIED-row verification as the thing a reviewer should re-check.

- [ ] **Step 4: Poll checks and merge**

Poll `gh pr checks <n> --json name,state` and
`gh pr view <n> --json mergeable,mergeStateStatus` on a backing-off interval,
never `--watch`. Merge only on checks green **and** state `CLEAN`. Use
`--rebase`; never squash.

---

## Self-Review

**1. Spec coverage.** §1's disposition row for `requesting-code-review` → Tasks 2 and 3, split between `$build-tdd` (the template) and `$review-loop` (the procedure), which is what the row's slash implies. §3's `petition-council` → Task 3 Step 1. §2 rule 1 → Task 1 before Tasks 2–3. §2 rule 2 → Global Constraints and Task 4 Step 1's explicit instruction not to strip the attribution while adjusting its wording. §4 rule 1 → the template placement argued in File Structure. §4 rule 4 → Task 1 Steps 2–3 are reading checks.

**Gap found and closed:** the two-verdict inventory format from units 1 and 2 does not fit this unit. Most of this skill's content is *already stated elsewhere*, which is neither KEEP (that invites a duplicate) nor DROP (that loses the audit trail). Task 1 defines a third verdict, CARRIED, and Task 1 Step 3 verifies each one against its destination — without that step, a CARRIED row is an unchecked assertion that deletion is lossless.

**Gap found and closed:** the read-only-checkout constraint lives in the template rather than the wrapper and would have been missed by an inventory of `SKILL.md` alone. Task 1 Step 1 names it explicitly and Step 2 requires reading both files.

**Gap found and closed:** unit 2 hit a leftover empty directory that `git status` cannot show. Task 3 Step 3 checks for it directly instead of relying on the shape gate to fail first.

**2. Placeholder scan.** No "TBD", no "handle edge cases". The `<body>` token in Task 5 Step 3 is followed by what it must contain. Task 3 Step 2 deliberately permits an empty ADD set and says to report it rather than invent content — that is a stated outcome, not an unfinished step.

**3. Type consistency.** `petition-council` matches spec §3's table and Task 3's commit message. The template path is `skills/build-tdd/code-reviewer.md` in File Structure, Task 2, and Task 4's sweep. Skill counts: 31 before, 30 after, asserted at the gate and in the README.
