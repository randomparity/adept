# 0003 — Close the upstream attribution by rewriting the six cited files

## Status

Proposed

Filled and flipped to `Accepted (YYYY-MM-DD)` **in this change, before merge** —
the consequences are licensed by that measurement, and the record must not reach
`main` with pending cells.

## Context

[ADR 0002](0002-narrow-the-upstream-attribution.md) narrowed this repository's
`obra/superpowers` attribution to six named files and left their rewrite as a
tracked follow-up. Those six are the entire remaining obligation: three reviewer
prompt templates and three helper scripts, all carried across a directory
boundary in the unit-2 and unit-3 absorptions without being rewritten.

ADR 0002 gave two reasons for not folding the rewrite in. The templates are
dispatch contracts — `$forge`'s party mode gates on the severity words inside
them and `$gauntlet`'s conversion table keys on the same words — so a careless
rewrite breaks a gate silently. And 0002 had refused to vary a 28-token
`git rev-parse` idiom, holding that functional constructs are not what the
licence protects and that changing working code to move a number is theatre.
That appeared to block the two scripts: `review-package` measured 95.98% and is
largely `git log --oneline`, `git diff --stat` and `git diff -U10`.

## Decision

**Rewrite the six files and remove the attribution.**

*Scripts — re-express, change nothing functional.* A probe rewrite of
`review-package` measured 0.00% containment with a longest shared run of 6
tokens, every invocation, flag and exit code preserved: renaming the variables
the git commands read breaks the matching windows without touching a single
invocation. ADR 0002's theatre objection does not bite, and its protected idiom
is untouched.

*Templates — author from the in-repo contract, do not paraphrase upstream.* What
those three files must contain is already specified here: `skills/forge/SKILL.md`
states the dispatch requirements and `skills/gauntlet/SKILL.md:289-297` fixes the
severity vocabulary. Writing them from that contract, rather than rewording the
upstream text, makes the result independent of upstream *arrangement* and not
merely of its wording.

**Threshold**, applying to the six rewritten files, measured against
`obra/superpowers` at `d884ae04edebef577e82ff7c4e143debd0bbec99` (v6.1.1) by ADR
0002's method: below **2% containment** and **no shared run over 16 tokens** —
twice the shingle width, so a run must be at least two disjoint shingles long
before it counts as a passage rather than an idiom. The bar is two-sided because 0002 reported the run beside containment ("one 40-word
verbatim passage matters more than the same token count scattered across
unavoidable technical vocabulary") but bounded only the percentage, under which a
large file could sit at 1.9% while keeping a 40-token verbatim passage.

A run may be exempted from the bound only if it is **command syntax rather than
prose** and **no longer than 28 tokens** — ADR 0002's `git rev-parse` idiom, the
longest construct this repository has blessed. Each exemption is named in the
table below, so the carve-out is visible rather than asserted. A prose run of any
length, or a longer construct, keeps its citation under the rewrite spec's §2
fallback; without both limits the exemption would reopen one level down the very
hole the run bound closes. The probe suggests no exemption will be needed — if
the measurement produces none, that column comes out with the same commit that
fills the table rather than shipping as empty machinery.

**If any of the six keeps its citation**, the closure does not happen: the notice
and a shortened README list stay, and this record is revised to say so before
merge rather than merged as written.

The excluded `skills/forge/SKILL.md` is not held to this bar; it keeps the 1.82%
/ 28-token idiom ADR 0002 blessed and is out of scope here.

**What containment does and does not establish.** It measures surviving verbatim
wording. Derivative-work status also turns on selection, arrangement and
sequence, which a metric of this kind does not see, and for the scripts this
change preserves arrangement deliberately. Authoring the templates from the
in-repo contract addresses that where the risk was largest; for the scripts the
residual is that a low score is evidence of independent expression rather than
proof of it. Removing the notice on that evidence is a judgment made by the
repository owner in [#32](https://github.com/randomparity/adept/issues/32), and
recorded here as a judgment rather than as a measurement result.

| File | Before | After | Longest run | Exempted constructs |
|---|---|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% / 1139 | *pending* | *pending* | *pending* |
| `skills/forge/implementer-prompt.md` | 100.00% / 816 | *pending* | *pending* | *pending* |
| `skills/forge/code-reviewer.md` | 100.00% / 663 | *pending* | *pending* | *pending* |
| `skills/forge/scripts/review-package` | 95.98% / 152 | *pending* | *pending* | *pending* |
| `skills/forge/scripts/task-brief` | 95.27% / 127 | *pending* | *pending* | *pending* |
| `skills/forge/scripts/sdd-workspace` | 11.60% / 45 | *pending* | *pending* | *pending* |

The candidate set is **every tracked file — 129 of them**. ADR 0002 never stated
its own, and its claim that "no other shipped file reaches 2%" does not hold over
that set. Four files sit above the line and none creates an obligation: the MIT
`LICENSE` both projects share; one `set -euo pipefail` / `git rev-parse` idiom in
`scripts/pre-push-hook`; and two `docs/workflow/` records — a behaviour inventory
and a migration plan — which quote the upstream behaviour they catalogue and
retire, at runs of 16 and 51 tokens. That last pair is documentary quotation
inside records describing what was removed rather than reuse of the software —
the same owner's judgment as above, not a measurement result — and the 16-token
bound governs the six rewritten files rather than the tree.

Neither of those two names `obra/superpowers` in its own prose — the inventory
cites only the retired `agent-config` skill path it was extracted from — so after
closure they are the sole shipped files carrying upstream wording with no
attribution near it. Adding that line is outside this change's surface and is
tracked as [#35](https://github.com/randomparity/adept/issues/35).

## Consequences

- `licenses/superpowers.LICENSE` is deleted and `licenses/` goes with it.
- `README.md`'s *Licence* section loses the six-file list, keeping MIT and
  re-aiming its measurement pointer at **this** record.
- `$gauntlet`'s citation of the two reviewer templates as "derived from vendored
  superpowers prompts" is dropped. ADR 0002 made that line correct; it becomes
  false, and a stale attribution is a defect in the direction nobody checks.
- **ADR 0002's narrowing is superseded.** Its *Method* section and its six
  per-file figures survive as the definition of the metric this record and any
  future re-derivation use. One further claim of 0002's does **not** survive: "no
  other shipped file reaches 2%", which does not hold over the candidate set
  stated above and is replaced by the four-file correction there. A reader
  arriving by 0002's banner should not rely on that sentence.
- The templates keep the literal words `Critical`, `Important` and `Minor` with
  their placeholders and output shape, because two skills gate on them. The
  accepted risk is that a careless rewrite breaks `$forge`'s party-mode dispatch
  silently — no gate can catch it, since anatomy rule 4 forbids asserting on
  prose, so a per-file contract checklist read at implementation and again at
  branch review is the whole control.
- `task-brief` and `review-package` gain behaviour suites, written against
  current behaviour and green *before* the rewrite touches them.
- Between this change and [#35](https://github.com/randomparity/adept/issues/35)
  the tree carries two shipped files with unattributed upstream runs and no
  licence notice anywhere. The owner accepts that interval: the quotation is
  documentary and short, #35 is filed and small, and holding the closure for it
  would keep a notice standing for files it was never about.
- After closure the repository makes an unbounded first-party claim with nothing
  watching it. No in-tree artifact reproduces the measurement, and where 0002 left
  a cited exception, 0003 leaves none — so fresh upstream text entering a new
  skill would be an uncovered use rather than a stale list. The accepted control
  is that new skills are authored first-party; re-measurement is manual and
  rebuilds the checker, as this change did.

## Considered & rejected

**Do nothing.** The honest trade: keeping the attribution costs little — the one
move that has occurred, the rename sweep, cost a provenance addendum and six
README entries — while closing it costs rewriting three live dispatch contracts
and two untested scripts, and writing two suites first. So this is discretionary,
chosen because the obligation is bounded and closable now and because a cited
file list must be kept true as files move. Against it, and the strongest thing
the status quo has: a cited list is a *watched* claim, and closure trades it for
an unwatched one, as the Consequences above concede.

**Rewrite the six but keep `licenses/superpowers.LICENSE`** as a voluntary
provenance record. Obtains nearly everything for the cost of one 1 KB file, and
avoids resting a licence judgment on a metric proxy. Rejected because the
judgment above is made deliberately rather than avoided, and the provenance
survives in git history and two decision records. Recorded because deleting the
notice is a separate decision from rewriting the files, and the one part of this
change a reader could not otherwise tell was considered.

**Re-author the two scripts from their new behaviour suites**, as the templates
are authored from their contract, so that arrangement is derived from the spec
rather than from the upstream file. The suites are a deliverable here anyway, so
the input exists. Rejected because a script's ordering is dictated by the git
operations it must perform and in what sequence — re-authoring reaches the same
lines in the same order and buys no arrangement independence, where the same move
on prose buys a great deal.

**Rewrite the three templates and leave the scripts cited.** Strictly smaller,
and it retires the wholesale-upstream files. Rejected because the probe shows the
scripts are the cheap half, so stopping short leaves the notice standing for the
least work saved.

**Edit ADR 0002's consequences in place**, as issue #32 literally asks. Rejected:
the `adr` profile sets `APPEND_ONLY_SECTIONS="*"` and `docs/adr/README.md`
directs superseding rather than rewriting in place.

## Provenance

Supersedes [0002](0002-narrow-the-upstream-attribution.md). Requested by
[#32](https://github.com/randomparity/adept/issues/32); designed in
`docs/workflow/specs/2026-08-11-close-the-upstream-attribution.md`.

The checker was rebuilt from ADR 0002's recorded method and reproduces all six of
that record's containments and longest runs exactly. It compares against all 171
files in the upstream tree where 0002 reports 140 (166,165 distinct 8-token
shingles against 161,753); containment rises monotonically with the size of the
union, so these figures are an upper bound on 0002's corpus and a file under
threshold here is under it there. Exact agreement across a superset is a
consistency check, not proof of an identically constructed instrument. The
checker is not shipped, for the reasons ADR 0002 gives.
