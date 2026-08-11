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

ADR 0002 declined to fold the rewrite into itself for two reasons that had to be
answered rather than waved past. The templates are dispatch contracts —
`$forge`'s party mode gates on the severity words inside them, and `$gauntlet`'s
severity-conversion table keys on the same words — so re-expressing them
carelessly breaks a gate silently. And ADR 0002 had itself refused to vary a
28-token `git rev-parse` idiom, holding that functional constructs are not what
the licence protects and that changing working code to move a number is theatre.
That refusal appeared to block the two scripts: `review-package` measured 95.98%
and is largely `git log --oneline`, `git diff --stat`, `git diff -U10` and
`git rev-list --count`, none of which may change.

## Decision

**Rewrite the six files as expression only, and remove the attribution.**

The apparent conflict with the theatre principle is an artifact of the shingle
length, and measurement dissolves it. An 8-token shingle survives only if eight
consecutive tokens match. The git invocations take their arguments from
*variables*, so renaming those variables breaks every window spanning them while
leaving each invocation byte-identical, stranding the unavoidable command names
in runs shorter than the shingle floor. A probe rewrite of `review-package`
measured **0.00% containment, longest shared run 6 tokens**, with every
invocation, flag and exit code preserved.

So no functional construct is altered — ADR 0002's principle is upheld, not set
aside, and the 28-token idiom it protected stays exactly as it was. What is
rewritten is comment prose, diagnostic wording, variable naming, and statement
structure: the expression the licence attaches to.

**The threshold**, measured against `obra/superpowers` at
`d884ae04edebef577e82ff7c4e143debd0bbec99` (v6.1.1) by ADR 0002's method: below
**2% containment** *and* **no shared run materially above the 8-token shingle
floor**, functional constructs excepted. ADR 0002 reported the longest run
alongside containment precisely because "one 40-word verbatim passage matters
more than the same token count scattered across unavoidable technical
vocabulary", but bounded only the percentage. A large template could sit at 1.9%
while keeping a 40-token verbatim passage, which is the case the notice exists
for; bounding both closes it.

Baseline, from a checker rebuilt off ADR 0002's recorded method and validated
against the pre-rewrite tree, where it reproduced all six of that record's
containments and all six longest runs exactly — a rebuild that did not would be
measuring something else:

| File | Containment | Longest shared run |
|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
| `skills/forge/implementer-prompt.md` | 100.00% | 816 |
| `skills/forge/code-reviewer.md` | 100.00% | 663 |
| `skills/forge/scripts/review-package` | 95.98% | 152 |
| `skills/forge/scripts/task-brief` | 95.27% | 127 |
| `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |

**Feasibility is evidenced for the scripts, not the templates.** The probe was
run on `review-package`, and its variable-renaming argument is a property of
shell. The three templates are prose at 100% with 1139-, 816- and 663-token
runs; nothing here demonstrates they can reach the threshold while keeping the
literal words `Critical`, `Important` and `Minor`, their placeholders and their
output shape. Substantive re-expression of prose breaks 8-token windows readily,
so they are expected to clear it easily, but that is an expectation and the
fallback below is the route if any of them misses.

**Fallback**, inherited from ADR 0002 §2: a file that cannot reach the threshold
without altering a functional construct keeps its attribution and stays cited.

### What the repository-wide scan actually covers

The candidate set is **every tracked file — 129 of them**, each compared against
the union of all 171 upstream files' shingles. ADR 0002 never stated its
candidate set, and its claim that "no other shipped file reaches 2%" does not
hold over the full tracked set. Four files outside the six sit at or above that
line, and none of them creates an obligation:

| File | Containment | Longest run | Why it is not upstream expression |
|---|---|---|---|
| `LICENSE` | 95.71% | 163 | The MIT text itself. Both projects are MIT; the licence is not either party's expression, and only the copyright line differs. |
| `scripts/pre-push-hook` | 6.06% | 9 | One idiom — `set -euo pipefail` and `git rev-parse --show-toplevel`. ADR 0002's functional-construct exclusion. |
| `docs/workflow/inventories/subagent-driven-development.md` | 2.51% | 16 | A behaviour inventory that quotes the upstream rows it catalogues, naming the source in its own text. |
| `docs/workflow/plans/2026-08-11-strip-companion-and-realign-migration.md` | 2.25% | 51 | A migration plan quoting the upstream behaviour it *removed*. Historical record, attributed in context. |

`skills/forge/SKILL.md` re-measures at **1.82% / 28 tokens** on the current tree
— carried forward from ADR 0002 as a figure but re-derived here, because the
rename sweep changed the file after 0002 measured it.

## Consequences

Conditional on all six landing below the threshold. If any lands on the fallback
instead, that file stays cited, `licenses/superpowers.LICENSE` stays with a
reduced list, and the first three bullets do not apply.

- `licenses/superpowers.LICENSE` is deleted and `licenses/` goes with it.
- `README.md`'s *Licence* section loses the six-file list, keeping MIT and
  re-aiming its measurement pointer at **this** record rather than the one it
  supersedes.
- `$gauntlet`'s citation of the two reviewer templates as "derived from vendored
  superpowers prompts" is dropped. ADR 0002 made that line correct; it becomes
  false, and a stale attribution is a defect in the direction nobody checks.
- **ADR 0002 is superseded.** Its narrowing no longer governs; its measurement
  stands as this record's baseline.
- The templates keep the literal words `Critical`, `Important` and `Minor` with
  their placeholders and output shape, because two skills gate on them. The
  accepted risk is that a careless re-expression breaks `$forge`'s party-mode
  dispatch silently — no gate can catch it, since anatomy rule 4 forbids
  asserting on prose, so a per-file contract checklist read at implementation
  and again at branch review is the whole control.
- `task-brief` and `review-package` gain behaviour suites, written against
  current behaviour and green *before* the rewrite touches them. Rewriting
  untested code and asserting nothing changed is otherwise an unbacked claim.
- After this change no in-tree artifact reproduces the measurement. The method
  stays recorded in ADR 0002 and the numbers in this record and the pull
  request; anyone re-deriving them rebuilds the checker, as this change did.

## Considered & rejected

**Do nothing.** The honest trade: keeping the attribution costs little — the one
move that has occurred, the rename sweep, cost a provenance addendum on ADR 0002
and six README entries — while closing it costs re-expressing three live
dispatch contracts at 663–1139 verbatim tokens, rewriting two untested scripts,
writing two behaviour suites first, and this record. So this is discretionary:
chosen because the obligation is bounded and closable now, and because a cited
file list is a thing that must be kept true as files move, not because the
maintenance burden is heavy today.

**Rewrite the six but keep `licenses/superpowers.LICENSE` anyway**, as a
voluntary provenance record. This obtains nearly everything — the README list
goes, the stale `$gauntlet` citation goes — for the cost of one 1 KB file, and
it avoids resting a licence judgment on a metric proxy. Rejected because
deletion is the point rather than a side effect: a notice retained for files
that are no longer upstream expression asserts an obligation that does not
exist, and the provenance survives in git history and two decision records.
Recording it here because deleting the notice is a separate decision from
rewriting the files, and is the only irreversible part of this change.

**Rewrite the three templates and leave the scripts cited** under the fallback.
Strictly smaller, and it retires the files that are wholesale upstream
expression. Rejected because the probe shows the scripts are the cheap half, so
stopping short would leave the notice standing for the least work saved.

**Edit ADR 0002's consequences in place**, as issue #32 literally asks. Rejected:
the `adr` profile sets `APPEND_ONLY_SECTIONS="*"`, protecting every level-2
section the base ref had, and `docs/adr/README.md` directs superseding rather
than rewriting. A banner plus this record reaches the same reader by the
supported route.

**Rewrite the prompts freely and re-point the gates.** Rejected as scope this
change has no authority for: the gates encode a working contract between
`$forge` and `$gauntlet`, and re-cutting it to make a prose rewrite easier
trades a licence cleanup for a behavioural change nobody asked for.

**Drive `skills/forge/SKILL.md`'s 1.82% to zero while here.** Rejected as ADR
0002 rejected it, for its reason: the shared run is a `git rev-parse` idiom with
no materially different spelling.

**Add a gate asserting the severity vocabulary survives.** Rejected under anatomy
rule 4 — a gate grepping Markdown for the word `Critical` is exactly the prose
assertion that rule forbids, and the false-red history behind it is why.

## Provenance

Supersedes [0002](0002-narrow-the-upstream-attribution.md). Requested by
[#32](https://github.com/randomparity/adept/issues/32); designed in
`docs/workflow/specs/2026-08-11-close-the-upstream-attribution.md`.
