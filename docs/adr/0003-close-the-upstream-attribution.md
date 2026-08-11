# 0003 — Close the upstream attribution by rewriting the six cited files

## Status

Accepted (2026-08-11)

## Context

[ADR 0002](0002-narrow-the-upstream-attribution.md) narrowed this repository's
`obra/superpowers` attribution from a blanket claim to six named files, and left
their rewrite as a tracked follow-up. Those six are the entire remaining
obligation: three reviewer prompt templates carried across a directory boundary
in the unit-2 and unit-3 absorptions without being rewritten, and three helper
scripts in the same position.

ADR 0002 declined to fold the rewrite into itself for reasons that had to be
answered rather than waved past. The templates are dispatch contracts — `$forge`'s
party mode gates on the severity words inside them, and `$gauntlet`'s
severity-conversion table keys on the same words — so re-expressing the prose
carelessly breaks a gate. And ADR 0002 had itself refused to vary a 28-token
`git rev-parse` idiom in `skills/forge/SKILL.md`, holding that functional
constructs are not what the licence protects and that changing working code to
move a number is theatre.

That refusal appeared to block the two scripts. `review-package` measured 95.98%
and is largely `git log --oneline`, `git diff --stat`, `git diff -U10` and
`git rev-list --count` — none of which may change.

## Decision

**Rewrite the six files as expression only, and remove the attribution.**

The apparent conflict with ADR 0002's theatre principle is an artifact of the
8-token shingle length, and measurement dissolves it. A shingle survives only if
eight consecutive tokens match. The git invocations take their arguments from
variables, so renaming those variables breaks every window spanning them while
leaving each invocation byte-identical; the unavoidable command names are then
stranded in runs shorter than the shingle floor. A probe rewrite of
`review-package` measured **0.00% containment, longest shared run 6 tokens**,
with every invocation, flag and exit code preserved.

So no functional construct is altered. What is rewritten is comment prose,
diagnostic wording, variable naming, and statement structure — the expression
the licence attaches to. ADR 0002's principle is upheld, not set aside: the
28-token idiom it protected stays exactly as it was, and
`skills/forge/SKILL.md` remains out of scope at 1.82%.

The threshold is ADR 0002's: below 2% containment, measured against
`obra/superpowers` at `d884ae04edebef577e82ff7c4e143debd0bbec99` (v6.1.1) by the
method that record sets out. The baseline this change starts from:

| File | Containment | Longest shared run |
|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
| `skills/forge/implementer-prompt.md` | 100.00% | 816 |
| `skills/forge/code-reviewer.md` | 100.00% | 663 |
| `skills/forge/scripts/review-package` | 95.98% | 152 |
| `skills/forge/scripts/task-brief` | 95.27% | 127 |
| `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |

The checker was rebuilt from the method ADR 0002 records and validated against
the pre-rewrite tree, where it reproduced all six of that record's containments
and all six longest shared runs exactly — a rebuild that did not would be
measuring something else, and its numbers would not be comparable. It is not
shipped, for the reasons ADR 0002 gives.

A file that cannot reach the threshold without altering a functional construct
keeps its attribution and stays cited, per ADR 0002 §2's fallback.



## Consequences

- `licenses/superpowers.LICENSE` is deleted and `licenses/` goes with it. No
  shipped file is substantially upstream expression, so nothing requires the
  notice to travel with it.
- `README.md`'s *Licence* section loses the six-file list; MIT and the pointer
  to the measurement remain.
- `$gauntlet`'s citation of the two reviewer templates as "derived from vendored
  superpowers prompts" is dropped. ADR 0002 made that line the correct citation;
  it is now false, and a stale attribution is a defect in the direction nobody
  checks for.
- **ADR 0002 is superseded.** Its narrowing decision no longer governs. Its
  measurement stands as the historical record and this record's baseline.
- The three reviewer templates keep the literal words `Critical`, `Important`
  and `Minor`, along with their placeholders and output shape, because two
  skills gate on them. The rewrite works around that vocabulary.
- `task-brief` and `review-package` gain behaviour suites, written against
  current behaviour and green before the rewrite touches them. Rewriting
  untested code and asserting nothing changed is otherwise an unbacked claim.
- Nothing tracks upstream any more, and now nothing is owed to it either. The
  obligation is closed rather than bounded.

## Considered & rejected

**Do nothing.** ADR 0002's arrangement is stable and legally sound. Rejected
because the obligation is live maintenance overhead — a licence file, a README
list, and a citation in a third skill, all of which must stay accurate as those
files move — and it is closable for one unit of work.

**Edit ADR 0002's consequences in place**, as issue #32 literally asks.
Rejected: the `adr` profile sets `APPEND_ONLY_SECTIONS="*"`, protecting every
level-2 section the base ref had, and `docs/adr/README.md` directs that a
decision be superseded with a new record rather than rewritten. A banner plus
this record reaches the same reader by the supported route.

**Rewrite the prompts freely, then re-point the gates.** Rejected as scope this
change has no authority for. The gates encode a working contract between
`$forge` and `$gauntlet`; re-cutting it to make a prose rewrite easier trades a
licence cleanup for a behavioural change nobody asked for.

**Drive `skills/forge/SKILL.md`'s 1.82% to zero while here.** Rejected, as ADR
0002 rejected it, and for its reason: the shared run is a `git rev-parse` idiom
with no materially different spelling.

**Add a gate asserting the severity vocabulary survives.** Rejected under
anatomy rule 4 — a gate grepping Markdown for the word `Critical` is precisely
the prose assertion that rule forbids, and the false-red history behind it is
why. The contract is checked by reading, against a per-file checklist.

## Provenance

target: licenses/superpowers.LICENSE
target: skills/forge/code-reviewer.md
target: skills/forge/implementer-prompt.md
target: skills/forge/task-reviewer-prompt.md
target: skills/forge/scripts/review-package
target: skills/forge/scripts/sdd-workspace
target: skills/forge/scripts/task-brief

Supersedes [0002](0002-narrow-the-upstream-attribution.md). Requested by
[#32](https://github.com/randomparity/adept/issues/32); designed in
`docs/workflow/specs/2026-08-11-close-the-upstream-attribution.md`.
