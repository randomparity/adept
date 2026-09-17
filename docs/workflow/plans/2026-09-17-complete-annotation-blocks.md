# Complete annotation blocks — implementation plan

**Goal.** Make a hand-composed `WORK:*` annotation fail loudly at write time when it is missing
either whole-line marker, and make that check reachable from every site that composes one by hand.

**Architecture.** `skills/quest-log/SKILL.md` owns the annotation convention and its recipes. This
change hardens two of its sections — the worked block and `post_annotation` — and adds one link
from each hand-write call site to the recipe. No executable ships; no reader contract changes.

**Tech stack.** Markdown instruction files. The recipe snippets are bash read by a model, not
sourced by anything.

Spec: [`docs/workflow/specs/2026-09-17-complete-annotation-blocks-design.md`](../specs/2026-09-17-complete-annotation-blocks-design.md).

## Global Constraints

- **Bash 3.2 is the floor** (macOS ships 3.2.57): no `mapfile`, no `readarray`, no associative
  arrays. `${var#pattern}` is fine.
- The fenced recipe snippets in `skills/quest-log/SKILL.md` use that file's existing snippet style,
  **two-space** indentation (`ensure_label`, lines 108-117) — not the tab indentation that governs
  shipped `.sh` files.
- `.claude-plugin/plugin.json` `version` is the mandatory shared per-PR edit (ADR 0022). This row's
  reserved version is **`5.13.0`** exactly.
- This repository is public: no absolute user paths, hostnames, or session state. The checkout root
  is named `$WORK`.
- Guardrails run bare — no pipes that swallow an exit code, no `|| true`.
- `BASE_BRANCH` is `main`. Branch: `feat/complete-annotation-blocks-390`.

Expected implementation size: 70–110 changed lines (M) — basis: two rewritten sections in
`skills/quest-log/SKILL.md`, one added sentence in each of seventeen call sites across eight files,
one added passage in `skills/resurrection/SKILL.md`, one version line. The range sits below the M
denominator because the band was frozen from blast radius (ten files, one shared contract consumed
by nine skills) rather than from line count; the denominator bounds design size and is carried
forward unchanged.

## File map

| File | Currently owns | Will own |
|---|---|---|
| `skills/quest-log/SKILL.md` | Annotation convention (421-434); `post_annotation` recipe (511-521) | Same, with a real-type worked block and a write-time marker check |
| `skills/quest/SKILL.md` | 4 hand-write sites: the `Posting the annotation` subsection, `:275`, `:666`, `:1057` | Same, each linking the recipe |
| `skills/campaign/SKILL.md` | 3 hand-write sites: `:377`, `:663`, `:730` | Same, each linking the recipe |
| `skills/counterspell/SKILL.md` | 3 hand-write sites: `:94`, `:133`, `:148` | Same, each linking the recipe |
| `skills/saga/SKILL.md` | 1 hand-write site: `:106-107` | Same, linking the recipe |
| `skills/return-to-town/SKILL.md` | 2 hand-write sites: `:24-28`, `:211` | Same, each linking the recipe |
| `skills/restock/SKILL.md` | 2 hand-write sites: `:698-700`, `:720` | Same, each linking the recipe |
| `skills/warding/SKILL.md` | 1 hand-write site: `:50` (`GROOM:STALE`) | Same, linking the recipe |
| `skills/divination/SKILL.md` | 1 hand-write site: `:73`, already naming the recipe in prose | Same, with that prose turned into a resolving link |
| `skills/resurrection/SKILL.md` | Reader of parked-phase notes (`:45-54`) | Same, stating the stale-block consequence |
| `.claude-plugin/plugin.json` | `version: 5.11.2` | `version: 5.13.0` |

No file is created, moved, or removed. No caller migration and no obsolete path: this extends the
existing owner of the annotation convention.

**Line numbers in this plan are pre-edit**, against `main` at `d72807b`. Task 1's own steps shift
`skills/quest-log/SKILL.md` by about +8 lines, so anchor every edit to the quoted text rather than
to a number.

---

## Task 1 — Harden the owning definition

**Files modified:** `skills/quest-log/SKILL.md`.

**Interfaces.** Defines the anchor `#recipe-post-an-annotation` (from the existing heading
`### Recipe: post an annotation`), which Task 2 links to from every call site. Defines
`post_annotation() { # kind(issue|pr) number type bodyfile }` — four positional parameters, same
arity and order as today. **`$3` changes meaning**: it is now the *full* type token as the
convention names it (`WORK:TRAJECTORY`, `GROOM:STALE`), not the bare suffix. Nothing in the
repository calls this function today, so there is no caller to migrate.

**Where this fits.** The owning definition. Task 2 makes it reachable; nothing else depends on it.

### Verification

| Contract | Mode | Detail |
|---|---|---|
| The marker derivation is correct for every shipped type | `focused-test` | Step 1.4 enumerates the shipped type tokens and walks the derivation against each. Red: any type whose derived pair differs from the pair its call site and readers use — which is the state before this task, where the hardcoded `WORK:` prefix cannot express `GROOM:STALE`. Green: all seven derive correctly. |
| `post_annotation` refuses a body file missing either marker | `task-test-not-applicable` | Nothing sources this fenced snippet — `scripts/list-shell-sources.sh` classifies shell sources by `.sh` name or bash shebang, so a harness would exercise an extracted copy rather than a live call path. Checked by reading. |
| Worked block uses a real type and carries both markers | `task-test-not-applicable` | Illustrative prose; nothing executes or parses it. Checked by reading. |

### Steps

**Step 1.1.** Replace the worked block at `skills/quest-log/SKILL.md:421-426`. Current:

```markdown
<!-- WORK:TYPE -->
## <Type> — issue #N
<structured body, short labelled bullets>
<!-- TYPE:COMPLETE -->
```

Replace with a real-type block:

```markdown
<!-- WORK:TRAJECTORY -->
## Trajectory — issue #412
- Outcome: parked at step 6 (adversarial review).
- Branch/PR: `feat/widget-412`, PR #418.
- Guardrails: `just verify` green at `a1b2c3d`.
- Needs: operator decision on the unresolved retry-budget finding.
<!-- TRAJECTORY:COMPLETE -->
```

**Step 1.2.** Replace the first bullet following that block (currently `:428-429`, quoted here to
anchor it):

```markdown
- The `TYPE:COMPLETE` sentinel distinguishes a finished annotation from a comment whose
  write died midway. A block without its sentinel is treated as absent.
```

Replace with:

```markdown
- **Both markers are required, and the closing one is what gets dropped.** The sentinel
  distinguishes a finished annotation from a comment whose write died midway. The pair is the type
  token itself, then its text after the first colon plus `:COMPLETE` — `WORK:TRAJECTORY` closes
  with `TRAJECTORY:COMPLETE`, and `GROOM:STALE` closes with `STALE:COMPLETE`, which is why the
  opening marker is never assumed to start with `WORK:`. A writer who changes the opening line and
  forgets the closing one produces a block every reader treats as absent — worse than absent, in
  fact, because latest-complete-wins then returns the newest *earlier* complete block in its place,
  so a stale hand-off reads as current. Post through the
  [post-annotation recipe](#recipe-post-an-annotation), which refuses a block missing either.
```

**Step 1.3.** Replace the recipe body (currently `:516-521`). Current:

```bash
post_annotation() { # kind(issue|pr) number type bodyfile
  # bodyfile already contains the full block incl. <!-- WORK:$3 --> ... <!-- $3:COMPLETE -->
  gh "$1" comment "$2" --body-file "$4"
}
```

Replace with:

```bash
post_annotation() { # kind(issue|pr) number type bodyfile
  # type is the full token the convention names, e.g. WORK:TRAJECTORY or GROOM:STALE.
  local open="<!-- $3 -->" close="<!-- ${3#*:}:COMPLETE -->"
  case $3 in
    *:*) : ;;
    *) echo "post_annotation: type '$3' needs the full token, e.g. WORK:TRAJECTORY" >&2; return 1 ;;
  esac
  # Refuse before posting. A block missing either whole-line marker reads as absent
  # to every consumer, and latest-complete-wins then hands back an older complete
  # block in its place -- a wrong answer, not a missing one.
  grep -qxF "$open" "$4" ||
    { echo "post_annotation: $4 lacks the whole-line opening marker $open" >&2; return 1; }
  grep -qxF "$close" "$4" ||
    { echo "post_annotation: $4 lacks the whole-line closing sentinel $close" >&2; return 1; }
  gh "$1" comment "$2" --body-file "$4"
}
```

Notes for the implementer. `grep -qxF` is whole-line (`-x`) and fixed-string (`-F`), matching the
whole-line-anchored contract stated two bullets above the recipe; `grep` is used rather than `rg` so
no personal ripgrep configuration can steer the check. The check is framing **presence** only —
`WORK:REVIEW`'s exactly-once and unindented rules stay with their owning reader
(`quest-log:458-461`). There is deliberately no post-write readback: `gh` already fails non-zero on
a failed write, and a readback-and-repost instruction here would contradict three call sites that
govern re-writes themselves — `divination:73` permits "exactly one comment-write attempt", while
`restock:701` and `return-to-town:28` permit one retry *only* after a readback proves the write
absent.

**Step 1.4.** Walk the derivation against every shipped type. First enumerate them:

```sh
cd "$WORK" && rg -o --no-config '(WORK|GROOM):[A-Z-]+' skills/ references/ --no-filename | sort -u
```

Expected: eight tokens — the seven live types in the table below, plus the `WORK:TYPE` placeholder
Step 1.1 removes. A token outside that set means a type was added since this plan was written and
must be added to the walk.

Then confirm by hand that `open="<!-- $3 -->"` and `close="<!-- ${3#*:}:COMPLETE -->"` produce, for
each of the seven live tokens, the pair its call site and readers actually use:

| `$3` | derived opening | derived closing |
|---|---|---|
| `WORK:TRAJECTORY` | `<!-- WORK:TRAJECTORY -->` | `<!-- TRAJECTORY:COMPLETE -->` |
| `WORK:SCOPE` | `<!-- WORK:SCOPE -->` | `<!-- SCOPE:COMPLETE -->` |
| `WORK:REVIEW` | `<!-- WORK:REVIEW -->` | `<!-- REVIEW:COMPLETE -->` |
| `WORK:DIVINATION` | `<!-- WORK:DIVINATION -->` | `<!-- DIVINATION:COMPLETE -->` |
| `WORK:RESCORE` | `<!-- WORK:RESCORE -->` | `<!-- RESCORE:COMPLETE -->` |
| `WORK:CLOSE-NOT-PLANNED` | `<!-- WORK:CLOSE-NOT-PLANNED -->` | `<!-- CLOSE-NOT-PLANNED:COMPLETE -->` |
| `GROOM:STALE` | `<!-- GROOM:STALE -->` | `<!-- STALE:COMPLETE -->` |

Cross-check the last three against their call sites — `campaign:668,673`, `campaign:379-380`, and
`warding:50` with the type table row at `quest-log:442`. A row that does not match is the red state
this step exists to catch.

**Step 1.5.** Confirm no line still teaches the placeholder form as a template.

```sh
cd "$WORK" && rg -n --no-config 'WORK:TYPE|<Type>' skills/quest-log/SKILL.md
```

Expected: exactly one hit — the `Whole-line-anchored matching` bullet, which cites
`^<!-- WORK:TYPE -->$` as a *matching pattern* rather than as a template to copy. Leave it.

**Step 1.6.** Commit.

```sh
cd "$WORK" && just commit-check && git add skills/quest-log/SKILL.md &&
  git commit -m "fix(quest-log): require both annotation markers at write time"
```

Expected: `just commit-check` exits 0; the commit succeeds.

### Acceptance criteria

- The worked block uses a real type; the convention states the pair rule in a form covering a
  non-`WORK:` type; Step 1.4's table matches for all seven live types.
- `post_annotation` returns non-zero before posting when either marker is absent, naming the file
  and the missing marker, and rejects a colon-less token.
- Four positional parameters, same order; no post-write readback.

---

## Task 2 — Make the check reachable, and state the reader's side

**Files modified:** `skills/quest/SKILL.md`, `skills/campaign/SKILL.md`,
`skills/counterspell/SKILL.md`, `skills/saga/SKILL.md`, `skills/return-to-town/SKILL.md`,
`skills/restock/SKILL.md`, `skills/warding/SKILL.md`, `skills/divination/SKILL.md`,
`skills/resurrection/SKILL.md`.

**Interfaces.** Consumes the anchor `#recipe-post-an-annotation` defined by Task 1 in
`skills/quest-log/SKILL.md`. From a file at `skills/<name>/SKILL.md` the link is
`../quest-log/SKILL.md#recipe-post-an-annotation`, matching the existing cross-skill link style at
`skills/campaign/SKILL.md:97` and `skills/forge/SKILL.md:656`. Both harnesses copy the whole
repository into the plugin cache, so these stay siblings and resolve from `<plugin-root>`
independent of cwd.

**Where this fits.** Without this task the Task 1 check reaches no writer, because `post_annotation`
is referenced by nothing today.

**Which sentences count as a site.** A call site is a *governing write contract*, not every sentence
that mentions a write. Where a skill states its tracking contract once and later refers to writes
under it, the contract carries the pointer and those sentences inherit it. Three write instructions
are therefore deliberately left without a pointer of their own, each already governed by a contract
that gets one: `return-to-town:214-216` (under `:24-28`), and `restock:705-706` and `:711-712`
(both under `:698-700`). Do not add pointers there — Step 2.10's count of seventeen will fail.

### Verification

| Contract | Mode | Detail |
|---|---|---|
| Every added link resolves and the count is seventeen | `focused-test` | Step 2.10. Red on the unedited tree: total `0`. Green: `17`, distributed as stated. |
| The reader states the stale-block consequence | `task-test-not-applicable` | Prose describing reader behaviour; nothing parses it. Checked by reading. |

### Steps

Each of Steps 2.1–2.8 adds one sentence per site, adapted only in its leading clause:

> Compose it with both markers and post it through the
> [post-annotation recipe](../quest-log/SKILL.md#recipe-post-an-annotation), which refuses a block
> missing either.

**Step 2.1 — `skills/quest/SKILL.md`, four sites.** The `### Posting the annotation` subsection; the
unattended-park instruction at `:275`; the approved-continuation instruction at `:666`; item 1 of
*On a Blocker -- Park the Issue* at `:1057`.

**Step 2.2 — `skills/campaign/SKILL.md`, three sites.** The `WORK:CLOSE-NOT-PLANNED` instruction at
`:377`; the `WORK:RESCORE` instruction at `:663`; the orchestrator-park instruction at `:730`. Leave
`:729` alone — it records that the worker already posted and instructs no write.

**Step 2.3 — `skills/counterspell/SKILL.md`, three sites.** `:94` (the reopen disposition record),
`:133` (the budget-stop park), `:148` (*On a blocker*).

**Step 2.4 — `skills/saga/SKILL.md`, one site.** The adoption path at `:106-107`.

**Step 2.5 — `skills/return-to-town/SKILL.md`, two sites.** The PR-only tracking contract at
`:24-28`; the operator-merge note at `:211`.

**Step 2.6 — `skills/restock/SKILL.md`, two sites.** The PR tracking contract at `:698-700`; the
`WORK:REVIEW` instruction at `:720`.

**Step 2.7 — `skills/warding/SKILL.md`, one site.** The `GROOM:STALE` instruction at `:50`. This is
the type whose pair is not `WORK:`-prefixed; Task 1's derivation must already handle it before this
link is added.

**Step 2.8 — `skills/divination/SKILL.md`, one site.** At `:73` the text already reads "Use the
quest-log body-file recipe". Turn that phrase into a resolving link to the same anchor; add no new
sentence, because this site already requires both markers on readback.

**Step 2.9 — `skills/resurrection/SKILL.md`, the reader.** In step 4 (`:45-54`), after the sentence
listing held work with its parked-phase note, add:

> A note missing its closing sentinel is not selected at all: latest-complete-wins filters it out
> and returns the newest *earlier* complete block, so an issue can present a stale hand-off as its
> current parked state.

**Step 2.10.** Verify the links. Run both commands **before** the edits to observe red.

```sh
cd "$WORK" && rg -o --no-config --no-filename 'quest-log/SKILL\.md#recipe-post-an-annotation' \
  skills/*/SKILL.md | wc -l
```

Expected: `17` after the edits; `0` before them. Then the distribution:

```sh
cd "$WORK" && rg -c --no-config 'quest-log/SKILL\.md#recipe-post-an-annotation' skills/*/SKILL.md
```

Expected after the edits, exactly these eight lines:

```text
skills/campaign/SKILL.md:3
skills/counterspell/SKILL.md:3
skills/divination/SKILL.md:1
skills/quest/SKILL.md:4
skills/restock/SKILL.md:2
skills/return-to-town/SKILL.md:2
skills/saga/SKILL.md:1
skills/warding/SKILL.md:1
```

Before the edits this second command prints nothing and exits 1 — `rg -c` omits zero-match files
rather than listing them as `0`.

**Step 2.11.** Prerequisite check on the anchor target (no red state claimed; it holds both before
and after, and exists to catch a heading renamed by mistake during Task 1).

```sh
cd "$WORK" && rg -q --no-config '^### Recipe: post an annotation$' skills/quest-log/SKILL.md &&
  echo "anchor-target-present"
```

Expected: `anchor-target-present`.

**Step 2.12.** Commit.

```sh
cd "$WORK" && just commit-check && git add skills/ &&
  git commit -m "fix(skills): route hand-written annotations through the marker check"
```

Expected: `just commit-check` exits 0; the commit succeeds.

### Acceptance criteria

- Seventeen resolving links, distributed exactly as Step 2.10's second expected output.
- `skills/campaign/SKILL.md:729` unchanged.
- `skills/divination/SKILL.md` gains a link, not a duplicated sentence.
- `skills/resurrection/SKILL.md` states that a sentinel-less note yields a stale earlier block.

---

## Task 3 — Bump the plugin version and verify the whole suite

**Files modified:** `.claude-plugin/plugin.json`.

**Interfaces.** Consumes nothing from Tasks 1 and 2. Produces the version
`scripts/check-plugin-version.sh` reads.

**Where this fits.** ADR 0022's mandatory shared per-PR edit; the harness skips an update when the
installed version matches the declared one, so a version left alone never reaches an installed copy.

### Verification

| Contract | Mode | Detail |
|---|---|---|
| Version is present, well-formed, and greater than base | `focused-test` | `just version-check`. **No local red state exists**: locally the gate checks presence and `MAJOR.MINOR.PATCH` shape only and exits 0 either way, because the bump rule needs `BASE_SHA`, which only CI sets. The reachable red is the CI required check on the pull request. |
| Whole repository stays green | `focused-test` | `just verify`, exit 0. |

### Steps

**Step 3.1.** In `.claude-plugin/plugin.json`, change `"version": "5.11.2"` to `"version": "5.13.0"`.
Use exactly `5.13.0` — this row's campaign reservation. Change no other field.

**Step 3.2.** Run the version gate bare.

```sh
cd "$WORK" && just version-check
```

Expected: exit 0, reporting that the bump rule needs `BASE_SHA` and was not checked locally.

**Step 3.3.** Run the full local suite bare.

```sh
cd "$WORK" && just verify
```

Expected: exit 0.

**Step 3.4.** Commit.

```sh
cd "$WORK" && git add .claude-plugin/plugin.json &&
  git commit -m "chore: bump plugin version to 5.13.0"
```

Expected: the commit succeeds.

### Acceptance criteria

- `.claude-plugin/plugin.json` declares `5.13.0`, no prerelease or build suffix.
- No other field in that file changed.
- `just verify` exits 0.

---

## Rollback

Every change is additive prose or a single-line version edit in tracked files. `git revert` of the
three commits restores the prior state; nothing is generated, persisted, or deployed, and no
consumer state depends on the intermediate commits.

## Deferrals carried into this plan

None. The design review disposed of every finding as `accepted-fixed`; no `deferred-tracked`
disposition was taken. Findings arising during branch review are recorded here before `$forge`
reads it.
