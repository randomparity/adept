# Complete annotation blocks — design

Issue: [#390](https://github.com/randomparity/adept/issues/390). Governing record:
[ADR 0069](../../adr/0069-the-park-path-stays-prose.md).

## Problem

A `WORK:*` annotation is framed by two whole-line HTML-comment markers. Every reader selects on
**both** and takes `last`, so a block missing its closing sentinel is worse than incomplete: the
newest *earlier* complete block is returned in its place — a wrong answer, not an absent one.

A post-merge audit on one issue found **all five** hand-written blocks missing the sentinel, while
the one block that worker did not hand-write — the pull request's `WORK:REVIEW`, emitted by
`publish-forge-review` — carried its marker correctly. A second worker's audit reproduced it.

Two corrections to the premises this change inherits, both verified against source:

- **The issue's stated cause is wrong.** #390 blames a worked example that shows only the opening
  marker. `skills/quest-log/SKILL.md:421-426` already shows both. The actual mechanism is the
  placeholder: the template is written as `TYPE`/`<Type>`, so copying it needs **two**
  substitutions and the second is the one dropped. Supporting evidence — the only two sites showing
  a worked block with a **real** type (`divination:54-67`, `campaign:668-673`) are both correct,
  and `divination` is also the only hand-write site that points at the shared recipe and demands
  both markers on readback (`divination:73-75`).
- **ADR 0069's reachability premise does not hold yet.** It assigns this fix to the shared recipe
  because "every hand-composed block already goes through quest-log's annotation recipe".
  `post_annotation` occurs **once** tree-wide, at its own definition (`skills/quest-log/SKILL.md:517`);
  nothing invokes or links to it. The only cross-skill links into quest-log are four to
  `#model-and-session-handoffs` (plus one from `references/model-selection.md`) and one to
  `#receiving-the-handoff`. That sentence describes the end state this change creates. Its
  comparative inference — shared instructions reach every call site, a composer reaches one —
  survives, and is why the fix pairs the check with the links that make it reachable. The record is
  append-only and its decision is unaffected.

## Scope

Three parts, one owning definition.

**A. The owning definition — `skills/quest-log/SKILL.md`.**

- A1, the annotation convention: replace the `TYPE`/`<Type>` template with a complete worked block
  using a real type, and state the marker-pair rule for every shipped type, including the one whose
  pair is not `WORK:`-prefixed.
- A2, the post-annotation recipe: `post_annotation` refuses a body file missing either whole-line
  marker **before** posting. It derives both markers from one full type token — opening `<!-- $3 -->`,
  closing `<!-- ${3#*:}:COMPLETE -->` — so `WORK:TRAJECTORY` and `GROOM:STALE` both express
  correctly, and rejects a token carrying no colon.

  A2 checks **framing presence only**. Type-specific shape rules — `WORK:REVIEW`'s exactly-once and
  unindented outer markers (`quest-log:458-461`, `quest:1004-1005`) — stay with their owning
  readers and are not duplicated here.

**B. Reachability — one pointer per hand-write call site** to A2, so the check reaches the writer.
Seventeen sites: `quest` (4), `campaign` (3), `counterspell` (3), `saga` (1), `return-to-town` (2),
`restock` (2), `warding` (1), `divination` (1).

**C. The reader — `skills/resurrection/SKILL.md`.** State the consequence a sentinel-less block has
for the sweep, so writer and reader agree on framing (#380 criterion 3, left to prose by ADR 0069).

Ownership: quest-log already owns the annotation convention and its recipes; this is a clean
extension of that owner, not a transition. No call site acquires its own copy of the rule, and no
executable ships — anatomy rules 1-3 untouched, rule 4 untouched because the check runs at write
time rather than asserting on prose in a gate.

`counterspell:92-95` is classified a **disposition record**, not a park write: it pairs the note
with reopening an issue into a workable state, where `:133` and `:148` pair it with
`status:blocked`/`status:needs-human`. No difference to the diff — both take the same pointer — and
recorded because #385 asked for it explicitly.

### Alternatives considered

- **Duplicate the full worked block at all seventeen sites.** Rejected: seventeen copies of one rule
  is the drift problem `CLAUDE.md` removed when it declined a second instruction file, and it still
  leaves no write-time detection.
- **Check in `post_annotation` only, no pointers.** Rejected: nothing links to that recipe, so the
  check reaches no writer and #390 ships short of its own acceptance — which ADR 0069 names as the
  thing that reopens #381.
- **Normalise `GROOM:STALE` to a `WORK:`-prefixed type** so one `WORK:$3` derivation covers every
  type. Rejected: it changes a published marker every existing reader of that block matches on,
  which is a reader-contract change this row's exclusions assign elsewhere.
- **A fixture that extracts the fenced snippet and runs it against a stubbed `gh`.** Rejected: it
  would test an extracted copy rather than the shipped instruction, and would need to stay in sync
  with the fence. The derivation's correctness is instead checked by walking it against every row of
  the type table — the step whose absence let the `GROOM:STALE` defect through in review.
- **A new ADR for this shape.** Declined: ADR 0069 already decided the governing question and
  pre-authorised a check at the shared recipe. `docs/adr/*` is an approved exclusion (owner #381).

## Failure model

**Actors and deployments.** A model composing an annotation inside a skill run, in this repository
and in any consumer checkout where the plugin is installed. `$resurrection` and the merge gate as
readers. No anonymous or networked actor; no CI job writes an annotation.

**Invariants and assets at stake.**

- A posted annotation is either complete or absent — never a truncated block that shadows a newer
  state with an older one.
- The latest-complete selection contract, consumed by nine skills, stays unchanged. This adds a
  writer-side check; it does not alter what readers select.
- `WORK:SCOPE`'s role as `$resurrection`'s liveness signal.
- The marker pair published for each type in the table at `quest-log:436-442`. The recipe must
  derive exactly those bytes, for every row.

**Accepted failure classes.**

- A writer that ignores the pointer and posts with a bare `gh ... comment` is not caught. Accepted:
  prose is the shape ADR 0069 chose, and instruction-following is the residual it recorded. Bounded
  by A1 making the complete block the only worked example a writer can copy.
- The interrupted park — note posted, worker gone before the label swap — is unchanged. Accepted:
  ADR 0069's recorded residual, owned by #380.
- A malformed block whose markers are present but whose body is wrong is not detected. Accepted:
  framing is what the audit measured; body correctness is a reading problem (anatomy rule 4).
- Type-specific shape rules beyond framing presence are not enforced by A2. Accepted: they are held
  by their owning readers, named in Scope A2.
- The single `gh ... comment` call the recipe already made is unbounded. Accepted:
  `references/network-bounds.md` governs shipped executables, and this is a prose snippet; this
  design adds no network call of its own.

**Covered elsewhere.**

- The park composer's shape and the park path's own residual → ADR 0069, #380.
- The merge gate's handshake selection → #378 (closed).
- Claim TTL ageing past a legitimate orchestrator wait → reported to the campaign orchestrator as
  an adjacent finding; no owner filed by this row.

## Success

1. The annotation convention shows a complete worked block using a real type, and states the
   marker-pair rule in a form that covers a type whose pair is not `WORK:`-prefixed. *(criterion 1)*
2. `post_annotation` fails, with a message naming the file and the missing marker, when its body
   file lacks either whole-line marker — before any comment is posted. *(criterion 2)*
3. `post_annotation` derives the correct marker pair for every type this repository ships, and
   rejects a type token carrying no colon. "Every" is bounded to these seven, the complete set:
   `GROOM:STALE`, `WORK:CLOSE-NOT-PLANNED`, `WORK:DIVINATION`, `WORK:RESCORE`, `WORK:REVIEW`,
   `WORK:SCOPE`, `WORK:TRAJECTORY`. *(criterion 1, criterion 5)*
4. Each of the seventeen hand-write call sites enumerated in Scope B carries a resolving link to the
   post-annotation recipe. "Each" is bounded to that enumerated set; sites outside it are readers or
   negative instructions, covered in the failure model. *(criterion 4)*
5. `skills/resurrection/SKILL.md` states that a sentinel-less block is filtered out and that an
   older complete block is returned in its place. *(criterion 5)*
6. `just verify` is green and `.claude-plugin/plugin.json` declares `5.13.0`. *(ADR 0022)*

## Validation

| Contract | Mode | Evidence |
|---|---|---|
| `post_annotation` refuses a body file missing either marker | `task-test-not-applicable` | Nothing in the repository sources this fenced snippet — `scripts/list-shell-sources.sh` classifies by `.sh` name or bash shebang, so a harness would exercise an extracted copy rather than a live call path. Correctness is checked by reading, against the concrete walk in the plan's Task 1 Step 1.4. |
| The marker derivation is correct for every shipped type | `focused-test` | Structural and machine-checkable. Plan Task 1 Step 1.4 enumerates the shipped type tokens and walks the derivation against each; red is any type whose derived pair differs from the one its call site and readers use. |
| Call-site links resolve and number seventeen | `focused-test` | Plan Task 2 Step 2.10. Red on the unedited tree: total count `0`. Green: `17`, distributed as the step states. `check-skill-shape.sh` rule 5 covers only `../../references/*.md`, so nothing else validates these. |
| Plugin version is bumped and well-formed | `focused-test` | `just version-check` locally checks presence and `MAJOR.MINOR.PATCH` shape only; the bump rule needs `BASE_SHA`, so its reachable red is the CI required check, not a local run. |
| Whole repository stays green | `focused-test` | `just verify`, exit 0. |
