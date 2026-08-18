# ADR rejections declare an evidence class — implementation plan

**Goal.** Make `$spellcraft`'s ADR contract require every `Considered & rejected` bullet to
declare how its ground was established, have the ADR-review focus enforce it, and restate
the requirement in `$tome-of-lore`'s ADR template.

**Architecture.** Two prose edits to two `SKILL.md` files. No scripts, no gates, no tests —
this repository forbids automated assertions on prose, and the decision record says
enforcement is by reading.

**Stack.** Markdown only. `just verify` is the guardrail suite.

Design: [spec](../specs/2026-08-18-adr-rejection-evidence-class-design.md) ·
[ADR 0019](../../adr/0019-adr-rejections-declare-an-evidence-class.md) · issue
[#137](https://github.com/randomparity/adept/issues/137)

## Global Constraints

- Repository instruction file is `CLAUDE.md`; there is no `AGENTS.md`.
- **Anatomy rule 1** — a skill is instructions, not a program. No new files ship.
- **Anatomy rule 4** — nothing automated asserts on prose. Do not touch
  `scripts/check-records.sh`, `.github/scripts/`, or `skills/tome-of-lore/assets/`.
- Issue #138 owns the review-side reproduction mechanics. `skills/trial-loop/SKILL.md` is
  not modified; needing to modify it means the work has crossed into #138.
- `docs/adr/README.md` carries no index table and gains no row.
- Never commit to `main`. Work is on `feat/adr-rejection-evidence-class-137`.
- The repository is public: no host paths, hostnames, credentials, or session state.
- Guardrail command: `just verify`. Run it bare — no pipes, no `|| true`.
- Wrap prose at the 100-character line limit already used in both files.

## Task 1 — state the contract and the review clause in `$spellcraft`

**Modifies:** `skills/spellcraft/SKILL.md`
**Creates / tests:** nothing.
**Fits:** this is the authority for the contract (ADR 0019). Task 2 restates it.

**Interfaces.** Task 2 consumes the two token names `verified:` and `judgment:` and the
two-class split exactly as written here. No other task depends on this one.

### Step 1.1 — insert the contract after the size paragraph

Anchor: the ADR-section paragraph ending `State the decision and stop.` The paragraph
immediately after it begins `Use the orchestrator-assigned ADR number`. Insert the
following between them, as its own paragraph block. Do not alter the five-section list
above it, the numbering paragraph below it, or the `### Spec self-review` subsection.

```markdown
Every `Considered & rejected` bullet names its alternative, then opens the ground that
sank it with one of two tags saying how that ground was established:

- **`verified:`** — a factual ground. It carries the command run and what that command
  produced, plus the environment wherever the result could depend on it — a commit, a
  released version, a platform — named so a later reader can return to it, since "this
  branch" is gone after the merge and the record is not. Where the ground is factual but
  no command settles it, `verified:` carries the source that does.
- **`judgment:`** — complexity, fit, taste, or cost. It carries no evidence; the token is
  the obligation, and naming which of the four applies is optional.

Both are legitimate grounds. A judgment presented as a fact is not. The tag classes the
ground, so it does not exempt a factual premise sitting inside that ground: a `judgment:`
resting on an unrun behaviour claim is the same defect wearing the other label. Where an
alternative is sunk by both a measured fact and a judgment, lead with `verified:` — the
factual half is the half that owes evidence.

What the tag replaces is the paragraph of justification behind the ground, never the
sentence or two that states the ground. A tagged bullet reads
`verified: prek install exits 2 under a global hooks path (prek 0.2.4, macOS)` or
`judgment: a second index adds a merge-conflict surface for a lookup nothing performs`,
in place of the reasoning it summarises. A rejected alternative is a road nobody drives,
so nobody re-tests the reason it was rejected; the tag is what tells a later reader which
grounds were checked.
```

**Acceptance:** the section states both tokens, the factual class's three parts, the
judgment class as legitimate-without-a-command with the sub-class optional, the
non-exemption rule, the mixed-ground precedence, the displacement sentence, and one
one-line example per tag. Requirements R1, R2, R3, R3b, R3c, R6.

### Step 1.2 — extend the ADR-review focus

Anchor: step 2's `focus:` string, the one beginning `Focus on the soundness of the
decision under its stated context`. Insert the following two sentences immediately after
`its remedy is cutting rather than more text.` and before `This ADR file is the review
target`. Change nothing else in the string, and leave the spec-review and plan-review
focus strings alone.

```
Evidence class is in scope: a rejection whose ground is stated as fact but carries no
command, result, or source is a finding, as is a claim about a rejected alternative's
behaviour that you cannot reproduce from what the bullet states — whichever tag precedes
it, since a judgment resting on an unrun behaviour claim is the same defect relabelled.
The command and result a factual ground carries are the ground, not argument, so the size
clause above does not ask for them to be cut. A record carrying no tags at all predates
this contract: say so once rather than filing a finding per bullet.
```

**Acceptance:** the focus names both R4 conditions, is tag-insensitive, reconciles with
the size clause (R4b), and yields one observation on a wholly untagged record.

### Step 1.3 — verify

Run `just verify` bare. Expected: every gate passes, exit 0. Then re-read the inserted
text against the spec's requirement table, row by row.

### Step 1.4 — commit

`docs: require an evidence class on ADR rejected alternatives`, body naming issue #137.

## Task 2 — restate the requirement in `$tome-of-lore`'s ADR template

**Modifies:** `skills/tome-of-lore/SKILL.md`
**Creates / tests:** nothing.
**Fits:** the writer who copies the template never reads `$spellcraft`'s section list, so
the template has to carry the rule (R5).

**Interfaces.** Consumes the token names from Task 1. Nothing depends on this task.

### Step 2.1 — extend the template placeholder inside the fence

Anchor: inside the fenced ADR template block, the line reading
`Alternatives, and why each was not chosen.` — the last content line before the closing
fence. Replace that line with:

```
Alternatives, and why each was not chosen. Each ground opens with `verified:` — the
command run, what it produced, and the environment where that matters — or `judgment:`
for complexity, fit, taste, or cost.
```

Do not change the five section headings, the H1 line, or the status line inside the fence.

### Step 2.2 — name the authority below the fence

Insert one sentence as its own paragraph immediately after the template block's closing
fence, before the paragraph beginning `` `## Status` reads ``:

```markdown
`$spellcraft` owns those two tags and states the rule in full; it is the authority if the
two ever disagree.
```

It sits **outside** the fence deliberately: text inside is copied verbatim into every new
record, and a sentence about which skill owns the rule is instruction, not record content.

### Step 2.3 — verify

Run `just verify` bare. Expected: exit 0. `just records` in particular must stay green —
the ADR profile asserts on the `## Considered & rejected` *heading*, not on the template
prose beneath it, so extending that line cannot redden it. Confirm rather than assume.

### Step 2.4 — commit

`docs: restate the evidence-class rule in the ADR template`, body naming issue #137.

## Rollback

Both tasks are additive prose in tracked files. `git revert` of either commit restores the
prior text with no migration, no state, and no consumer to notify.
