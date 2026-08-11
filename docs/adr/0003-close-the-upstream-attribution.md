# 0003 — Close the upstream attribution by rewriting the six cited files

## Status

Accepted (2026-08-11)

## Context

[ADR 0002](0002-narrow-the-upstream-attribution.md) narrowed this repository's
`obra/superpowers` attribution to six named files and left their rewrite as a
tracked follow-up. Those six are the entire remaining obligation: three reviewer
prompt templates and three helper scripts, all carried across a directory
boundary in the unit-2 and unit-3 absorptions without being rewritten.

ADR 0002 gave two reasons for not folding the rewrite in. The templates are
dispatch contracts — `$forge`'s party mode gates on the severity words inside
them and `$gauntlet`'s conversion table keys on the same words — so a careless
re-expression breaks a gate silently. And 0002 had refused to vary a 28-token
`git rev-parse` idiom, holding that functional constructs are not what the
licence protects and that changing working code to move a number is theatre.
That appeared to block the two scripts: `review-package` measured 95.98% and is
largely `git log --oneline`, `git diff --stat` and `git diff -U10`.

## Decision

**Rewrite the six files and remove the attribution.**

*Scripts — re-express, change nothing functional.* The conflict with the theatre
principle is an artifact of the shingle length. An 8-token shingle survives only
if eight consecutive tokens match, and the git invocations take their arguments
from *variables*, so renaming those breaks every window spanning them while
leaving each invocation byte-identical. A probe rewrite of `review-package`
measured **0.00% containment, longest shared run 6 tokens**, with every
invocation, flag and exit code preserved. ADR 0002's principle is upheld: the
28-token idiom it protected stays exactly as it was.

*Templates — author from the in-repo contract, do not paraphrase upstream.* What
those three files must contain is already specified here: `skills/forge/SKILL.md`
states the dispatch requirements and `skills/gauntlet/SKILL.md:289-297` fixes the
severity vocabulary. Writing them from that contract rather than rewording the
upstream text is what makes the result independent of upstream *arrangement*, not
merely of its wording. It is also the cheaper correctness story, since the
contract is the thing the templates have to satisfy anyway.

**Threshold**, measured against `obra/superpowers` at
`d884ae04edebef577e82ff7c4e143debd0bbec99` (v6.1.1) by ADR 0002's method: below
**2% containment** and **no shared run over 16 tokens**, except functional
constructs, which are enumerated individually in the pull request. ADR 0002
reported the longest run beside containment because "one 40-word verbatim
passage matters more than the same token count scattered across unavoidable
technical vocabulary", but bounded only the percentage — under which a large file
could sit at 1.9% while keeping a 40-token verbatim passage. Bounding both closes
that, and a stated integer is checkable where "materially above" is not.

**What containment does and does not establish.** It measures surviving verbatim
wording. Derivative-work status also turns on selection, arrangement and
sequence, which a metric of this kind does not see — and for the scripts this
change preserves arrangement deliberately. Authoring the templates from the
in-repo contract addresses that for the files where the risk was largest; for the
three scripts the residual is that a low score is evidence of independent
expression rather than proof of it. Removing the notice on that evidence is a
judgment, made by the repository owner in
[#32](https://github.com/randomparity/adept/issues/32), and recorded here as a
judgment rather than as a measurement result.

Baseline, from a checker rebuilt off ADR 0002's recorded method:

| File | Containment | Longest shared run |
|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
| `skills/forge/implementer-prompt.md` | 100.00% | 816 |
| `skills/forge/code-reviewer.md` | 100.00% | 663 |
| `skills/forge/scripts/review-package` | 95.98% | 152 |
| `skills/forge/scripts/task-brief` | 95.27% | 127 |
| `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |

The rebuild reproduces all six of ADR 0002's containments and longest runs
exactly. Two caveats keep that from being proof it is the same instrument. It
compares against all **171** files in the upstream tree where 0002 reports
**140** (166,165 distinct shingles against 161,753); since containment rises
monotonically with the size of the union, this run's figures are an upper bound
on 0002's corpus, so a file under threshold here is under it there. And exact
agreement across a superset is a consistency check, not a proof of identical
construction.

The candidate set is **every tracked file — 129 of them**. ADR 0002 never stated
its own, and its claim that "no other shipped file reaches 2%" does not hold over
that set: four files sit above the line and none creates an obligation — the MIT
`LICENSE` both projects share, one `set -euo pipefail` / `git rev-parse` idiom in
`scripts/pre-push-hook`, and two `docs/workflow/` records quoting the upstream
behaviour they catalogue and retire. The measurements are in the pull request.
`skills/forge/SKILL.md` re-measures at 1.82% / 28 tokens on the current tree.

**Fallback**, from the rewrite spec
`docs/workflow/specs/2026-08-11-first-party-skill-rewrite-design.md` §2: a file
that cannot reach the threshold keeps its attribution and stays cited. If that
fires, the measurement will show it before this record merges, and this record is
replaced by one that states the outcome that happened and enumerates the reduced
cited list — 0002's enumeration does not survive its supersession.

## Consequences

- `licenses/superpowers.LICENSE` is deleted and `licenses/` goes with it.
- `README.md`'s *Licence* section loses the six-file list, keeping MIT and
  re-aiming its measurement pointer at **this** record.
- `$gauntlet`'s citation of the two reviewer templates as "derived from vendored
  superpowers prompts" is dropped. ADR 0002 made that line correct; it becomes
  false, and a stale attribution is a defect in the direction nobody checks.
- **ADR 0002's narrowing is superseded**, and only its narrowing. Its *Method*
  section and its measurement survive as the definition of the metric this record
  and any future re-derivation use.
- The templates keep the literal words `Critical`, `Important` and `Minor` with
  their placeholders and output shape, because two skills gate on them. The
  accepted risk is that a careless rewrite breaks `$forge`'s party-mode dispatch
  silently — no gate can catch it, since anatomy rule 4 forbids asserting on
  prose, so a per-file contract checklist read at implementation and again at
  branch review is the whole control.
- `task-brief` and `review-package` gain behaviour suites, written against
  current behaviour and green *before* the rewrite touches them.
- After closure the repository makes an unbounded first-party claim with nothing
  watching it. No in-tree artifact reproduces the measurement, and where 0002
  left a cited exception, 0003 leaves none — so fresh upstream text entering a
  new skill would be an uncovered use rather than a stale list. The accepted
  control is that new skills are authored first-party; re-measurement is manual
  and rebuilds the checker, as this change did.

## Considered & rejected

**Do nothing.** The honest trade: keeping the attribution costs little — the one
move that has occurred, the rename sweep, cost a provenance addendum and six
README entries — while closing it costs re-expressing three live dispatch
contracts, rewriting two untested scripts, and writing two suites first. So this
is discretionary, chosen because the obligation is bounded and closable now and
because a cited file list must be kept true as files move.

**Rewrite the six but keep `licenses/superpowers.LICENSE`** as a voluntary
provenance record. Obtains nearly everything for the cost of one 1 KB file, and
avoids resting a licence judgment on a metric proxy. Rejected because the
judgment above is made deliberately rather than avoided, and the provenance
survives in git history and two decision records. Recorded because deleting the
notice is a separate decision from rewriting the files, and the one part of this
change that a reader cannot infer was considered.

**Rewrite the three templates and leave the scripts cited.** Strictly smaller,
and it retires the wholesale-upstream files. Rejected because the probe shows the
scripts are the cheap half, so stopping short leaves the notice standing for the
least work saved.

**Edit ADR 0002's consequences in place**, as issue #32 literally asks. Rejected:
the `adr` profile sets `APPEND_ONLY_SECTIONS="*"` and `docs/adr/README.md`
directs superseding rather than rewriting in place.

**Rewrite the prompts freely and re-point the gates.** Rejected as scope this
change has no authority for: the gates encode a working contract between `$forge`
and `$gauntlet`.

**Drive `skills/forge/SKILL.md`'s 1.82% to zero.** Rejected as 0002 rejected it:
the shared run is a `git rev-parse` idiom with no different spelling.

**Add a gate asserting the severity vocabulary survives.** Rejected under anatomy
rule 4 — a gate grepping Markdown for the word `Critical` is exactly the prose
assertion that rule forbids.

## Provenance

Supersedes [0002](0002-narrow-the-upstream-attribution.md). Requested by
[#32](https://github.com/randomparity/adept/issues/32); designed in
`docs/workflow/specs/2026-08-11-close-the-upstream-attribution.md`.
