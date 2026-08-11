# Unit 6 — Rewrite `systematic-debugging` In Place

> **For agentic workers:** execute task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace `skills/systematic-debugging/`'s six files with a single
rewritten `SKILL.md`, and remove the `list-shell-sources.sh` exception that
existed only for the deleted script.

**Architecture:** Sixth and final rewrite unit of
`docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md` §1. This
is the only one of the eleven that stays a skill — "invoked directly; nothing
wraps it" — so nothing is absorbed and nothing moves. The behaviour inventory
(`docs/superpowers/inventories/systematic-debugging.md`) records 62 rows: 33
KEEP, 5 FIRST-PARTY, 24 DROP.

**Tech stack:** Markdown, bash 3.2, `just verify`.

## Global Constraints

- This repository is **public**. No host-specific configuration, absolute user
  paths, hostnames, addresses, auth headers, API keys, or session state. Plans
  and specs name the checkout root as `$WORK`.
- `CLAUDE.md` anatomy rule 1: one `SKILL.md` is the default; a supporting file
  must be argued for. Rule 2: a script ships only if it does something a model
  cannot do reliably inline. Rule 4: nothing automated asserts on prose.
- Bash 3.2 floor. `rg` passes `--no-config`; capture its exit status explicitly.
- Conventional commits, imperative mood, subject ≤ 72 characters.
- Never commit to `main`. Work happens on
  `refactor/rewrite-systematic-debugging`.
- Run gates bare — no pipes that swallow an exit code.

## Two things this unit must not lose

**1. The five FIRST-PARTY rows are already independent.** Inventory rows 6–9 and
30 — the `docs/solutions/` prior-art search, the vestige pointer, "a hit is a
hypothesis, not a fix", the `rg` exit-2 note, and the `$compound` write-back —
are this repo's own writing, not upstream. Spec §2's re-expression requirement
does not apply to them, and rewriting them would be churn that risks breaking a
loop `$compound` depends on. **Carry them substantially as-is.**

**2. The two reference links written in unit 5.** `SKILL.md:195` and `:304–305`
point at `references/trial-by-fire.md` and `references/true-seeing.md`. A
from-scratch rewrite is exactly how those get dropped, and shape-gate rule 5
cannot catch a link that no longer exists — it only checks the links that do.
Task 3 asserts on their presence explicitly.

## Measured starting state

```
skills/systematic-debugging/SKILL.md                          321
skills/systematic-debugging/root-cause-tracing.md             169
skills/systematic-debugging/condition-based-waiting-example.ts 158
skills/systematic-debugging/defense-in-depth.md               122
skills/systematic-debugging/condition-based-waiting.md        115
skills/systematic-debugging/find-polluter.sh                   63
                                                              948
```

Inbound references outside the directory: **none in `skills/`**. Verified at
`5905760` — no skill invokes `$systematic-debugging`, consistent with §1's
"nothing wraps it". The only code reference anywhere is
`scripts/list-shell-sources.sh:55`, which Task 2 removes.

`just verify` currently prints `ripgrep-config: ok (36 shell sources)`. After
Task 2 it prints 35.

---

### Task 1: Rewrite `SKILL.md`

**Files:**
- Modify: `skills/systematic-debugging/SKILL.md`

Write from the inventory rows, not from the source text — spec §2 makes that the
independence mechanism the similarity gate at step 5 then confirms. The five
FIRST-PARTY rows are the exception and are carried across.

- [ ] **Step 1: Write it**

Required content, by inventory row:

- **The law** — rows 1, 36: no fix before the investigation has run; reading the
  scope as advisory is breaking it.
- **When it binds** — rows 2, 3, 4: any technical issue, and especially under
  time pressure, when a quick fix looks obvious, and after a fix already failed.
- **Investigation** — rows 5, 10, 11, 12: read the error and the whole trace;
  reproduce before theorising and gather data rather than guess when you cannot;
  check what changed; and in a multi-component system instrument every boundary
  and run once to find *where* it breaks before proposing anything.
- **Prior art** — rows 6, 7, 8, 9, carried substantially as-is from the current
  text, including the `rg -li '<distinctive error string>' docs/solutions/`
  recipe, the vestige pointer, "a hit is a hypothesis, not a fix", and the rg
  exit-2 note.
- **Tracing** — rows 13, 37, 38, 39, 40, 41: trace the bad value backward to its
  origin and fix there; when manual tracing runs out, log the value, the working
  directory, the relevant environment and a captured stack immediately *before*
  the dangerous operation, to stderr rather than through a logger that may be
  suppressed; and to find a test polluting shared state, run the files one at a
  time checking for the artifact after each.
- **Pattern analysis** — rows 14, 15, 16, 17.
- **Hypothesis** — rows 18, 19, 20, 21.
- **Fixing** — rows 22, 23, 24: a failing test first, linking
  `[trial-by-fire](../../references/trial-by-fire.md)`; one fix, no bundled
  work; verify, linking `[true-seeing](../../references/true-seeing.md)`.
- **Three strikes** — rows 25, 26, 27: count failed fixes, recognise the
  architectural signature, raise it with a human rather than trying a fourth.
- **Defence in depth** — rows 45, 46, 47, 48, 49: after fixing at source, add a
  check at each layer the bad data crossed; the four layer kinds as a clause
  each; map the checkpoints first; test each layer by bypassing the previous
  one; and why one check is not enough.
- **Waiting on conditions** — rows 52, 53, 54, 55, 56.
- **No root cause** — rows 28, 29.
- **Closing the loop** — row 30, carried substantially as-is: `$compound` writes
  the non-obvious root cause to `docs/solutions/`, the write half of the prior-art
  read, and it declines routine bugs so invoking it costs little.
- **Rationalizations** — row 33, compressed: drop the two that are rows 15 and 1.

Do **not** write: a Red Flags list (row 31); the "Signals From Your Human
Partner" quotations (32); a Quick Reference table (34); any "Real-World Impact"
statistics (35, 44, 51, 60); Graphviz digraphs (42, 59); the empty-`projectDir`
worked example in any of its three tellings (43, 51); TypeScript implementations
(50, 58); or a Quick Patterns table (57).

- [ ] **Step 2: Verify the drops stayed out**

```bash
rg --no-config -n 'digraph|Real-World Impact|Ultra-think|projectDir|1847|Quick Reference' skills/systematic-debugging/SKILL.md
```

Expected: no match (`rg` exit 1).

- [ ] **Step 3: Verify the FIRST-PARTY rows survived**

```bash
rg --no-config -c 'docs/solutions/' skills/systematic-debugging/SKILL.md
rg --no-config -n 'vestige|compound|hypothesis, not a fix' skills/systematic-debugging/SKILL.md
```

Expected: at least 2 for the first; at least one match each for vestige,
`$compound`, and the hypothesis clause.

- [ ] **Step 4: Commit**

```bash
git add skills/systematic-debugging/SKILL.md
git commit -m "refactor(systematic-debugging): rewrite as a single skill file"
```

---

### Task 2: Delete the five supporting files and their gate exception

Inventory rows 61 and 62 carry the arguments. `find-polluter.sh` fails anatomy
rule 2; `condition-based-waiting-example.ts` imports another project's modules;
the three technique documents are ~45 lines of substance, now inline.

**Files:**
- Delete: `skills/systematic-debugging/root-cause-tracing.md`
- Delete: `skills/systematic-debugging/defense-in-depth.md`
- Delete: `skills/systematic-debugging/condition-based-waiting.md`
- Delete: `skills/systematic-debugging/condition-based-waiting-example.ts`
- Delete: `skills/systematic-debugging/find-polluter.sh`
- Modify: `scripts/list-shell-sources.sh` — remove the exception and its comment

- [ ] **Step 1: Confirm nothing outside the skill references the five files**

```bash
rg --no-config -n 'root-cause-tracing|defense-in-depth|condition-based-waiting|find-polluter' \
  --glob '!docs/superpowers/**' .
```

Expected: only `scripts/list-shell-sources.sh` (the `find-polluter.sh`
exception at line 55 and the comment at lines 15–16). Anything else must be
re-pointed first.

- [ ] **Step 2: Remove the files**

```bash
git rm -q skills/systematic-debugging/root-cause-tracing.md \
  skills/systematic-debugging/defense-in-depth.md \
  skills/systematic-debugging/condition-based-waiting.md \
  skills/systematic-debugging/condition-based-waiting-example.ts \
  skills/systematic-debugging/find-polluter.sh
```

The directory keeps `SKILL.md`, so no `rmdir` sweep is needed here — unlike
units 2, 4 and 5, this deletion does not empty a directory.

- [ ] **Step 3: Remove the now-dead exception**

In `scripts/list-shell-sources.sh`, delete this line from `is_two_space()`:

```bash
	skills/systematic-debugging/find-polluter.sh) return 0 ;;
```

and these two lines from the header comment:

```
#   - find-polluter.sh predates the format gate at two-space and stays that way
#     to avoid an unrelated full-file reformat.
```

The `--two-space` subset must stay non-empty or the script fails closed by
design. It does: `.github/scripts/` and `skills/decision-records/assets/` remain.

- [ ] **Step 4: Verify both subsets still resolve**

```bash
./scripts/list-shell-sources.sh --two-space
./scripts/list-shell-sources.sh --tabs | wc -l
```

Expected: the two-space list is non-empty and no longer contains
`find-polluter.sh`; the tabs list is unchanged in content (find-polluter was
never in it).

- [ ] **Step 5: Lint the edited script**

```bash
shellcheck scripts/list-shell-sources.sh
shfmt -d scripts/list-shell-sources.sh
```

Expected: both silent, exit 0.

- [ ] **Step 6: Commit**

```bash
git add -A skills/systematic-debugging scripts/list-shell-sources.sh
git commit -m "refactor: drop the systematic-debugging support files"
```

---

### Task 3: Verify the skill still holds together

Rule 5 of the shape gate checks that the reference links present in a `SKILL.md`
resolve. It cannot notice a link the rewrite dropped, so that is checked here.

- [ ] **Step 1: Both unit-5 reference links survive and resolve**

```bash
rg --no-config -o -N --no-filename '\.\./\.\./references/[a-z-]+\.md' \
  skills/systematic-debugging/SKILL.md | sort -u
```

Expected exactly these two lines, and no others:

```
../../references/trial-by-fire.md
../../references/true-seeing.md
```

`heed-counsel` is not linked from here and must not appear.

- [ ] **Step 2: Frontmatter still matches the directory**

```bash
rg --no-config -m1 -N '^name:' skills/systematic-debugging/SKILL.md
```

Expected: `name: systematic-debugging`.

- [ ] **Step 3: Shape gate**

```bash
./scripts/check-skill-shape.sh
```

Expected: exit 0, `check-skill-shape: 26 skills, all rules pass`. The skill
count is unchanged this unit — nothing is deleted or added at the directory
level.

- [ ] **Step 4: Only one file remains in the directory**

```bash
ls skills/systematic-debugging
```

Expected: `SKILL.md` alone.

---

### Task 4: Guardrails, PR, merge

- [ ] **Step 1: Full suite, bare**

```bash
just verify
```

Expected: exit 0, `check-skill-shape: 26 skills, all rules pass`, and
`ripgrep-config: ok (35 shell sources)` — one fewer than before, because
`find-polluter.sh` is gone. A count of 36 here means the deletion did not take.

- [ ] **Step 2: Measure**

```bash
git diff --stat main -- skills/ scripts/
```

- [ ] **Step 3: Ship**

Follow `$ship-pr` then `$merge-cleanup`: push, open the PR against `main`, poll
compact `--json` snapshots on a backing-off interval, exit only on green checks
**and** `mergeStateStatus` `CLEAN`. Merge `--rebase`, never squash. Then
checkout `main`, pull, delete the local and remote-tracking branch, prune, and
confirm the tree is clean.

## Self-Review

**Spec coverage.** §1's disposition for this skill is "skill, rewritten"; Task 1
rewrites it and Task 2 reduces it to the rule-1 default of one file. §2's
write-from-behaviours requirement governs Task 1 step 1, with the FIRST-PARTY
carve-out stated and justified. §5's inventory-first requirement is satisfied by
`4b86993`. §3's rename to `detect-curse` is **not** applied here — the rename
lands last, and unlike unit 5's references this skill *does* have a directory and
`name:` frontmatter, which is exactly what the sweep touches.

**Placeholder scan.** Every step carries its command and expected output. Task 1
specifies content by inventory row rather than pasting prose, deliberately: a
plan that quoted the replacement text would defeat the independence mechanism it
serves. Its drop-list is explicit and step 2 checks it mechanically.

**Consistency.** Task 3 and Task 4 both expect 26 skills, unchanged from unit 5,
because this unit adds and removes no skill directory. Task 4 expects 35 shell
sources against the 36 measured above, and names what a 36 would mean.

**Risk.** Task 2 deletes five files, gated by Task 1 having already written
their surviving content and Task 2 step 1 proving nothing outside the skill
references them. All five remain in git history. Task 2 also edits a script two
gate recipes consume; step 4 exercises both of its subsets and step 5 lints it.

**Known gap, not fixed here.** Nothing verifies that the rewritten skill's
`$compound` invocation still describes what `$compound` does. That is a prose
claim about another document, which rule 4 forbids gating, and it is checked by
reading rather than by a test.
