# Unit 5 — Three Skills Become References

> **For agentic workers:** execute task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Convert `test-driven-development`, `verification-before-completion` and
`receiving-code-review` into `references/trial-by-fire.md`,
`references/true-seeing.md` and `references/heed-counsel.md`, delete the three
skill directories, and gate the new link class.

**Architecture:** Fifth unit of the first-party skill rewrite
(`docs/superpowers/specs/2026-08-11-first-party-skill-rewrite-design.md` §1).
Unlike units 1–4 this is not an absorption into another skill: it creates a new
artifact class. Spec §1's placement test calls a reference "a standard you
consult while doing something else", as against a procedure you invoke. The
three behaviour inventories under `docs/superpowers/inventories/` record 87 rows
across the three: 57 KEEP, 8 GATE, 22 DROP.

**Tech stack:** Markdown, `just verify`, `scripts/check-skill-shape.sh`, bash 3.2.

## Global Constraints

- This repository is **public**. No host-specific configuration, absolute user
  paths, hostnames, addresses, auth headers, API keys, or session state. Plans
  and specs name the checkout root as `$WORK`.
- Anatomy rule 4: nothing automated asserts on prose. The new gate rule checks
  that a **link resolves** — a file-existence test, not a wording test.
- Bash 3.2 is the floor: no `mapfile`, no `readarray`, no associative arrays.
- `rg` in gate scripts and assertions passes `--no-config`. Capture rg's exit
  status explicitly; never trail `|| true` on a scan.
- Conventional commits, imperative mood, subject ≤ 72 characters.
- Never commit to `main`. Work happens on `refactor/absorb-three-references`.
- Run gates bare — no pipes that swallow an exit code.

## Three decisions, with their derivations

**1. References are created at their themed names now, not at the rename sweep.**

Units 1–4 deliberately deferred the themed names (`council`, `inscribe`,
`petition-council`, `long-rest`) because spec §3 says "the rename lands last".
That does not apply here, and the spec itself says why. §3 describes the sweep as

> a single mechanical pass over directories, `name:` frontmatter, and every
> `$invocation`

A reference has no directory of its own, no `name:` frontmatter, and no
`$invocation` — none of the three things the sweep touches. Creating these at
unthemed names would leave them unthemed permanently. §1's disposition table
already writes the destination as `references/trial-by-fire.md`, so the themed
name **is** the specified destination for this unit.

**2. `references/` sits at the repository root.**

Both §1 and §3 write the path as `references/<name>.md` with no prefix. The
harness copies the whole repository into the plugin cache (`CLAUDE.md`, Layout),
so a root directory ships and is readable from a skill at runtime. Links from
`skills/<name>/SKILL.md` are therefore `../../references/<file>.md`.

**3. A reference is not invoked with `$`.**

`$name` means "run this skill". These are consulted, not run, so they are linked
by path and never written as `$trial-by-fire`. This is what makes decision 1 safe
— there is no invocation for the sweep's gate to find stale.

## Measured starting state

```
skills/test-driven-development/SKILL.md                 371 lines
skills/test-driven-development/testing-anti-patterns.md 299 lines
skills/receiving-code-review/SKILL.md                   213 lines
skills/verification-before-completion/SKILL.md          142 lines
                                                      1,025 total
```

Every inbound reference, measured at `332a7fb`:

| Site | Form | Caught by shape gate rule 4? |
|---|---|---|
| `skills/work-issue/SKILL.md:225` | `` `$receiving-code-review` `` | **Yes** — backticked `$` form |
| `skills/review-loop/SKILL.md:306` | `` `receiving-code-review` `` | No |
| `skills/build-tdd/SKILL.md:363` | `` `test-driven-development` `` | No |
| `skills/systematic-debugging/SKILL.md:195` | `` `test-driven-development` `` | No |
| `skills/systematic-debugging/SKILL.md:303` | `**test-driven-development**` | No |
| `skills/systematic-debugging/SKILL.md:304` | `**verification-before-completion**` | No |

One of six is gate-covered — the first time in five units that the shape gate
catches any of them. The other five are explicit `rg` assertions in Task 4, and
Task 6 closes the class properly.

`README.md:31` reads "29 skills". It becomes 26.

`$systematic-debugging` is rewritten in unit 6. Its three references are
re-pointed here anyway, because this unit deletes what they point at.

---

### Task 1: Write `references/trial-by-fire.md`

**Files:**
- Create: `references/trial-by-fire.md`

Source: `docs/superpowers/inventories/test-driven-development.md` — 21 KEEP rows
(two folded), 4 GATE, 11 DROP. Write from the inventory rows, not from the
source text; spec §2 makes that the independence mechanism the similarity gate
at step 5 then confirms.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p references
```

- [ ] **Step 2: Write the file**

Required content, by inventory row:

- A one-line statement of what the reference is for and when to read it.
- **The law and its enforcement** — rows 1, 9, 10: no production code without a
  failing test first; code written first is deleted rather than adapted or kept
  as reference; the scope (features, bugfixes, refactors, behaviour changes) and
  the three exceptions that need the human's agreement.
- **Why the order is the whole point** — rows 2, 3, 4, 7: watch it fail; confirm
  it fails for the expected reason and not a typo; a test that passes
  immediately is testing existing behaviour, so fix the test; when it fails
  after implementing, fix the code and not the test.
- **What a good test looks like** — rows 11, 12, 13: one behaviour, an "and" in
  the name means split it, name it for the behaviour, drive real code.
- **Bugs** — row 14: reproduce with a failing test before fixing.
- **Mocks** — rows 16, 17, 18, 19, 20, 21: never assert a mock exists in place
  of real behaviour; no production method only tests call; know the real side
  effects before mocking and mock at the lowest level that preserves what the
  test needs; mock the complete structure, not the fields this test reads;
  when mock setup outgrows the test, prefer an integration test; and the check —
  a test that fails only because the mock is gone was testing the mock.
- **The arguments against it** — rows 26 and 27 folded: the distinct
  rationalizations only, each with its answer.
- **When stuck** — row 29: the four difficulty-to-design-signal conversions.
- Row 34's letter-versus-spirit line, once.

Do **not** write: a Graphviz digraph (row 22), Good/Bad TypeScript pairs (23), a
worked example (24), a Good Tests table (25), a Red Flags list (28), a
verification checklist (30 — `true-seeing` owns completion claims), Gate Function
pseudocode (31), the anti-patterns Quick Reference (32), or any "your human
partner's rule" attribution (35, 36).

Do not restate the four GATE rows as a second gate: `$build-tdd`'s `## TDD rules`
owns the numbered cycle, minimal implementation, green verification, and the
edge/error coverage list.

- [ ] **Step 3: Verify the drops actually stayed out**

```bash
rg --no-config -n 'digraph|your human partner|Gate Function|Verification Checklist' references/trial-by-fire.md
```

Expected: no match (`rg` exit 1).

- [ ] **Step 4: Commit**

```bash
git add references/trial-by-fire.md
git commit -m "docs(references): add trial-by-fire, the TDD standard"
```

---

### Task 2: Write `references/true-seeing.md`

**Files:**
- Create: `references/true-seeing.md`

Source: `docs/superpowers/inventories/verification-before-completion.md` — 16
KEEP (two compressed), 2 GATE, 6 DROP.

- [ ] **Step 1: Write the file**

Required content, by inventory row:

- **The law** — row 1: no completion, fixed, or passing claim without
  verification run in this same message. A previous run does not license it.
- **The gate** — rows 2, 3, 4, 5, 6: identify the command that proves the claim;
  run it in full; read the output, check the exit code, count failures; for any
  done/passing/mergeable claim also run `git status --porcelain`, because an
  untracked file is one the check never saw; and when the output does not
  confirm, state the real status with evidence.
- **Each claim needs its own command** — rows 7, 8, 10: a linter passing is not
  a build claim; a build passing is not a test claim; tests passing is not
  requirements met, which is checked line by line against the plan; and a
  subagent's success report is checked against the diff, not believed.
- **Regression tests** — row 9: write, pass, revert the fix, watch it fail,
  restore, pass. Nothing else in the repo states the retrofit case.
- **How the rule gets evaded** — rows 11, 12, 13: hedging words are the tell;
  satisfaction is a completion claim; the rule binds paraphrase and implication,
  not a list of phrases.
- **Claim/evidence table** — row 15, compressed: keep the distinct triples.
- **The arguments against it** — row 16, compressed: drop the two that are
  rows 7 and 8.
- Rows 22 and 23: the thesis line and the letter-versus-spirit line, once each.

Do **not** write: a Key Patterns section (row 17), a Red Flags list (18), When
To Apply / Rule applies to lists (19), "From 24 failure memories" or its incident
list (20), the quoted instruction-file line about being replaced (21), or a
closing "non-negotiable" restatement (24).

- [ ] **Step 2: Verify the drops stayed out**

```bash
rg --no-config -n '24 failure memories|you.ll be replaced|Red Flags' references/true-seeing.md
```

Expected: no match (`rg` exit 1).

- [ ] **Step 3: Commit**

```bash
git add references/true-seeing.md
git commit -m "docs(references): add true-seeing, evidence before claims"
```

---

### Task 3: Write `references/heed-counsel.md`

**Files:**
- Create: `references/heed-counsel.md`

Source: `docs/superpowers/inventories/receiving-code-review.md` — 20 KEEP (three
reworded or narrowed), 2 GATE, 5 DROP.

- [ ] **Step 1: Write the file**

Required content, by inventory row:

- **The thesis** — row 18: external feedback is suggestions to evaluate, not
  orders to follow.
- **The response pattern** — row 25, with rows 1, 2, 3, 4 as its steps: read it
  all before reacting; restate the requirement or ask; verify against the
  codebase; judge whether it is sound for *this* codebase.
- **What not to say** — rows 5, 6, 7, 21 narrowed: no performative agreement, no
  "let me implement that now" before verification. State the fix or make it
  rather than thanking. State the *behaviour*, not a banned wordlist.
- **Unclear items** — row 8: stop and clarify **all** of them before
  implementing any, because items may be related.
- **Pushing back** — rows 9, 11, 15, 16: the five conditions that justify it;
  the third answer when you cannot verify — say so and name what you need;
  correcting a wrong pushback factually without apology or defence; and naming
  the discomfort rather than staying quiet.
- **Checking the reviewer** — rows 12, 26: grep for callers before building a
  feature "properly"; the five questions for an external reviewer.
- **Doing the work** — row 13: blocking issues, then simple fixes, then complex
  ones, testing each individually.
- **Sources** — row 19 reworded: feedback from the operator is trusted after
  understanding; external feedback is verified first. Written in this repo's
  voice, without quoting another project's operator.
- **GitHub threads** — row 17: reply in the comment thread with
  `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`, not as a
  top-level comment.

Do **not** write: the "your human partner's rule" quotations (row 20), a Common
Mistakes table (22), the Real Examples vignettes (23), the unclear-feedback
worked example (24), or a closing restatement (27).

Do not restate the two GATE rows: `$review-loop` step 5 owns
`rejected-with-evidence` and step 6 owns `blocked`. This reference decides
whether a finding is right; the loop decides what it becomes.

- [ ] **Step 2: Verify the drops stayed out**

```bash
rg --no-config -n 'your human partner|Real Examples|Common Mistakes' references/heed-counsel.md
```

Expected: no match (`rg` exit 1).

- [ ] **Step 3: Commit**

```bash
git add references/heed-counsel.md
git commit -m "docs(references): add heed-counsel, evaluating review feedback"
```

---

### Task 4: Re-point all six inbound references

**Files:**
- Modify: `skills/work-issue/SKILL.md:225`
- Modify: `skills/review-loop/SKILL.md:306`
- Modify: `skills/build-tdd/SKILL.md:363`
- Modify: `skills/systematic-debugging/SKILL.md:195`, `:303`, `:304`

- [ ] **Step 1: List them again before editing**

```bash
rg --no-config -n 'test-driven-development|verification-before-completion|receiving-code-review' skills/
```

Expected: the six sites in the table above, plus the frontmatter and self-
references inside the three directories being deleted. Anything else is a site
this plan missed — re-point it too.

- [ ] **Step 2: Re-point each**

Every site becomes a markdown link with a relative path from
`skills/<name>/SKILL.md`:

- `[trial-by-fire](../../references/trial-by-fire.md)`
- `[true-seeing](../../references/true-seeing.md)`
- `[heed-counsel](../../references/heed-counsel.md)`

`skills/work-issue/SKILL.md:225` currently reads `` run `$receiving-code-review`
over each ``. The `$` form must go — a reference is not invoked. It becomes
`apply [heed-counsel](../../references/heed-counsel.md) to each`.

`skills/systematic-debugging/SKILL.md:303-304` are entries in a related-skills
list. They become reference links in the same list, worded as reading rather
than using: "read [trial-by-fire](…)" rather than "use the … skill".

- [ ] **Step 3: Verify no old name survives in `skills/`**

```bash
rg --no-config -n 'test-driven-development|verification-before-completion|receiving-code-review' \
  --glob '!skills/test-driven-development/**' \
  --glob '!skills/verification-before-completion/**' \
  --glob '!skills/receiving-code-review/**' \
  skills/
```

Expected: no match (`rg` exit 1).

- [ ] **Step 4: Verify every new link resolves, from the linking file's directory**

```bash
for f in skills/*/SKILL.md; do
  d=$(dirname "$f")
  rg --no-config -o -N '\.\./\.\./references/[a-z-]+\.md' "$f" | sort -u | while IFS= read -r rel; do
    test -f "$d/$rel" || echo "BROKEN: $f -> $rel"
  done
done
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "refactor: point skills at the three new references"
```

---

### Task 5: Delete the three skill directories

**Files:**
- Delete: `skills/test-driven-development/` (2 files)
- Delete: `skills/verification-before-completion/`
- Delete: `skills/receiving-code-review/`

- [ ] **Step 1: Remove them**

```bash
git rm -r -q skills/test-driven-development skills/verification-before-completion skills/receiving-code-review
for d in test-driven-development verification-before-completion receiving-code-review; do
  rmdir "skills/$d" 2>/dev/null || true
done
```

The `rmdir` sweep is the unit-2 lesson: `git rm -r` can leave an empty directory
on disk and `git status` cannot show it, because git does not track empty
directories. `rmdir` refuses a non-empty directory, so it self-verifies. The
`|| true` guards a cleanup whose expected outcome is failure, not a gate.

- [ ] **Step 2: Verify all three are gone from disk**

```bash
for d in test-driven-development verification-before-completion receiving-code-review; do
  test ! -e "skills/$d" || echo "STILL PRESENT: skills/$d"
done
```

Expected: no output.

- [ ] **Step 3: Count**

```bash
ls -d skills/*/ | wc -l
```

Expected: `26`.

- [ ] **Step 4: Commit**

```bash
git add -A skills/
git commit -m "refactor: delete the three skills now carried as references"
```

---

### Task 6: Extend the shape gate so reference links resolve

Rule 4's own comment states the rationale this task reuses: "a stale `$name` is
otherwise silent until someone runs it." A stale reference link is the same
failure in a new artifact class, and this unit is what creates that class. Five
of the six links this unit writes are invisible to every existing gate.

This is a **structural** rule — it asks whether a file exists at a path — and so
is exactly what spec §4 permits: "checking that a `SKILL.md` exists, that its
declared name matches its directory, or that an invocation resolves is
deterministic and catches real breakage."

**Files:**
- Modify: `scripts/check-skill-shape.sh`

- [ ] **Step 1: Add rule 5**

Insert after rule 4's `while` loop and before the final status check:

```bash
# Rule 5: every link into references/ resolves to a file that exists. New
# artifact class, same failure mode as rule 4 -- a reference is consulted by
# path rather than invoked, so a stale link is silent until someone follows it.
# Paths are relative to the linking SKILL.md, which is what gets checked.
links_status=0
rg --no-config -o -N '\.\./\.\./references/[a-z0-9-]+\.md' "$root"/skills/*/SKILL.md \
	>"$workspace/rawlinks" || links_status=$?
if [ "$links_status" -gt 1 ]; then
	printf 'check-skill-shape: scanning reference links failed (rg exit %s)\n' "$links_status" >&2
	exit 1
fi
sort -u "$workspace/rawlinks" >"$workspace/links"
while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	if [ ! -f "$root/skills/x/$rel" ]; then
		report "reference link does not resolve: $rel"
	fi
done <"$workspace/links"
```

`$root/skills/x/$rel` resolves `../../references/<file>.md` back to
`$root/references/<file>.md` without needing the real skill name — every
`SKILL.md` sits at the same depth, so one synthetic sibling stands for all of
them.

- [ ] **Step 2: Run it clean**

```bash
./scripts/check-skill-shape.sh
```

Expected: exit 0, `check-skill-shape: 26 skills, all rules pass`.

- [ ] **Step 3: Prove the rule bites**

A new gate is not done until its first real run is reported. Break it, watch it
redden, restore:

```bash
git mv references/true-seeing.md references/true-seeing.md.bak
./scripts/check-skill-shape.sh; echo "exit=$?"
git mv references/true-seeing.md.bak references/true-seeing.md
./scripts/check-skill-shape.sh; echo "exit=$?"
```

Expected: `reference link does not resolve: ../../references/true-seeing.md`
with `exit=1`, then `exit=0`. Record the actual output in the PR body.

- [ ] **Step 4: Lint the script**

```bash
shellcheck scripts/check-skill-shape.sh
shfmt -i 2 -d scripts/check-skill-shape.sh
```

Expected: both silent, exit 0. The file uses tabs; match what is already there
rather than reformatting it.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-skill-shape.sh
git commit -m "feat(shape): check that reference links resolve"
```

---

### Task 7: Document the new artifact class

**Files:**
- Modify: `CLAUDE.md` — Layout
- Modify: `README.md:31` — the count

- [ ] **Step 1: Add the Layout entry**

Insert after the `skills/<name>/SKILL.md` bullet:

```markdown
- `references/<name>.md` — standards consulted while doing something else, as
  against skills, which are procedures you invoke. A reference is linked by
  relative path from the skills that consult it and is never written as a
  `$invocation`. `check-skill-shape.sh` rule 5 checks those links resolve.
```

- [ ] **Step 2: Update the count**

`README.md:31` becomes:

```markdown
26 skills covering design, TDD, adversarial review, shipping, and campaign
```

Check the surrounding sentence still reads correctly with three references now
present but uncounted; mention them if the line reads as a full inventory.

- [ ] **Step 3: Verify**

```bash
rg --no-config -n '\b29 skills\b' README.md CLAUDE.md .claude-plugin/ .codex-plugin/
```

Expected: no match (`rg` exit 1).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: record references as a distinct artifact class"
```

---

### Task 8: Guardrails, PR, merge

- [ ] **Step 1: Full suite, bare**

```bash
just verify
```

Expected: exit 0, `check-skill-shape: 26 skills, all rules pass`. Several
minutes; the push hook runs it again, so expect the push to take as long.

- [ ] **Step 2: Measure**

```bash
git diff --stat main -- skills/ references/
```

- [ ] **Step 3: Ship**

Follow `$ship-pr` and then `$merge-cleanup`: push, open the PR against `main`,
poll compact `--json` snapshots on a backing-off interval, exit only on green
checks **and** `mergeStateStatus` `CLEAN`. Merge `--rebase`, never squash. Then
checkout `main`, pull, delete the local and remote-tracking branch, prune, and
confirm the tree is clean.

## Self-Review

**Spec coverage.** §1 assigns all three to `references/`; Tasks 1–3 write them,
Task 5 deletes the originals, Task 4 re-points every consumer. §3's reference
table supplies the three filenames, used verbatim. §4's structural-gate
allowance is what Task 6 rests on, quoted in the task. §5's inventory-first
requirement is satisfied by the three files committed at `8a60262`.

**Placeholder scan.** Every step carries its command and its expected output.
The three writing tasks specify content by inventory row rather than pasting
prose, which is deliberate — spec §2 requires writing from the behaviour list
rather than the source text, and a plan that quoted the replacement text would
defeat the independence mechanism it is meant to serve. Each of those tasks
carries an explicit drop-list and a mechanical check that the drops stayed out.

**Consistency.** Tasks 5, 6 and 8 all expect 26 skills; Task 7 writes 26. The
link pattern `../../references/[a-z0-9-]+\.md` in Task 6's gate is the same
pattern Task 4 step 4 checks by hand, with digits allowed in the gate because a
future reference name may carry one.

**Risk.** Two irreversible steps. Task 5's deletion is gated by Task 4 step 3
proving no skill still names the old paths, and the files remain in git history.
Task 6 edits a gate every other check depends on; step 3 proves it still fails
when it should, which is the check that matters for a gate.

**Known gap, not fixed here.** Rule 5 scans `skills/*/SKILL.md` only, matching
rule 4's scope. A link written from a supporting file — `code-reviewer.md`,
`implementer-prompt.md` — is not covered. No such link exists today; if one is
written, the rule needs widening rather than the link avoiding.
