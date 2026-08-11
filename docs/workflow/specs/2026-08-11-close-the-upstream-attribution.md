# Close the upstream attribution

Design for [#32](https://github.com/randomparity/adept/issues/32). Decision
record: [ADR 0003](../../adr/0003-close-the-upstream-attribution.md).

## Context

ADR 0002 measured every shipped file against `obra/superpowers@d884ae04` and
found the tree splits cleanly: everything *rewritten* during the six absorption
units is below 2% containment, and everything *moved* across a directory
boundary without being rewritten is at or near total overlap. Six files were in
the second group, so the attribution was narrowed to name them rather than
removed.

Those six are the whole of the remaining obligation. Rewriting them ends it, and
`licenses/superpowers.LICENSE` plus the README's attribution list go with it.

ADR 0002 left this as a tracked follow-up rather than a rider, for two stated
reasons: the three prompt templates are dispatch contracts other skills gate on,
and the scripts carry (or lack) behaviour suites. Both are addressed below.

## The measurement

The checker is not in the tree and does not enter it — ADR 0002 rejected
shipping it twice, and nothing here reopens that. It is rebuilt from ADR 0002's
recorded method for the duration of this change and its output is transcribed
into ADR 0003:

> lowercase; keep every run of `[a-z0-9]` and discard everything else; cut into
> overlapping 8-token shingles; for candidate C against the union U of all
> upstream shingles, `containment(C) = |shingles(C) ∩ U| / |shingles(C)|`.

The rebuild is validated before it is trusted: run against the tree as it stands
it must reproduce all six of ADR 0002's containments **and** all six longest
shared runs exactly. It does — 100.00%/1139, 100.00%/816, 100.00%/663,
95.98%/152, 95.27%/127, 11.60%/45, and 1.82%/28 for the excluded
`skills/forge/SKILL.md`.

Two caveats bound what that proves. The rebuild compares against all **171**
files in the upstream tree where ADR 0002 reports **140** (166,165 distinct
shingles against 161,753). Containment rises monotonically with the size of the
union, so these figures are an **upper bound** on 0002's corpus — a file under
threshold here is under it there, which is the direction that favours caution.
And exact agreement across a superset is a consistency check, not proof of an
identically constructed instrument.

### Baseline

| File | Containment | Longest shared run |
|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
| `skills/forge/implementer-prompt.md` | 100.00% | 816 |
| `skills/forge/code-reviewer.md` | 100.00% | 663 |
| `skills/forge/scripts/review-package` | 95.98% | 152 |
| `skills/forge/scripts/task-brief` | 95.27% | 127 |
| `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |

### The candidate set, and what else is in it

The scan covers **every tracked file — 129 of them**. ADR 0002 never stated its
candidate set, and its claim that "no other shipped file reaches 2%" does not
hold over that set. **Five** tracked files sit above it, not four: the first is
`licenses/superpowers.LICENSE` itself at 100.00% / run 170 — it *is* the upstream
notice, and R4 deletes it. Of the rest, `LICENSE` (95.71%, run 163) is the MIT text both projects
share, `scripts/pre-push-hook` (6.06%, run 9) is one `set -euo pipefail` /
`git rev-parse --show-toplevel` idiom, and two records quote the upstream
behaviour they inventory and retire —
`docs/workflow/inventories/subagent-driven-development.md` (2.51%, run 16) and
`docs/workflow/plans/2026-08-11-strip-companion-and-realign-migration.md`
(2.25%, run 51).

**Neither of those two names `obra/superpowers` in its own prose.** The string
occurs in exactly five tracked files, and the inventory cites only the retired
`agent-config` skill path it was extracted from. So the argument that they carry
no obligation is *not* that the source is named: it is that the quotation is
short and documentary, inside records describing behaviour being removed rather
than reusing the software. That is the owner's judgment and ADR 0003 records it
as one. Adding the attribution line is out of surface, tracked as
[#35](https://github.com/randomparity/adept/issues/35).

None creates an obligation, so R4 stands. ADR 0003 records the correction, since
its own "no shipped file is substantially upstream expression" consequence is
only auditable with the denominator stated. No file outside the six is edited
for this reason.

## The theatre question, settled by measurement

ADR 0002 refused to vary `skills/forge/SKILL.md`'s 28-token
`git rev-parse --git-dir` / `--git-common-dir` idiom, on the grounds that
functional constructs are not what the licence protects and changing working
code to move a number is theatre. That principle governs here too, and it is
the reason the two scripts looked like the hard case: `review-package` at 95.98%
is mostly `git log --oneline`, `git diff --stat`, `git diff -U10`, and
`git rev-list --count`, none of which may change.

The apparent conflict is an artifact of the shingle length, and it dissolves
under measurement. An 8-token shingle survives only if *eight consecutive
tokens* match. Those git invocations take their arguments from **variables**, so
renaming `base`/`head` and introducing a single variable for the range breaks
every window that spans them, while leaving each invocation byte-identical. The
unavoidable command names then sit in runs shorter than the shingle floor.

A probe rewrite of `review-package` written this way measures **0.00%
containment with a longest shared run of 6 tokens** — under the 8-token floor —
with every git invocation, flag, and exit code preserved. So:

**Nothing functional changes.** What changes is comment prose, diagnostic
wording, variable naming, and statement structure. That is the expression the
licence protects, and it is the only thing this change touches.

If any file cannot reach the threshold without altering a functional construct,
that file keeps its attribution and the obligation stays open for it — the
rewrite spec's §2 fallback.

**The probe is n=1 and does not generalise across the three scripts.** Its
mechanism is variable renaming breaking windows that span `git` invocations, and
`review-package` is where that works best. `task-brief` embeds an awk program
whose density is pattern text rather than variables — renaming `infence` and
`intask` leaves the regex literals intact. `sdd-workspace` starts at 11.60% with
a 45-token run that must come below 16, in logic R3 pins in place. Those two are
the likeliest to hit the fallback, so the plan sequences them **first**, where a
miss is cheap to discover.

## Requirements

### R1 — the six files fall below the threshold

Measured by the validated rebuild against `obra/superpowers@d884ae04`, after the
rewrite, for each of the six individually: **below 2% containment** and **no
shared run over 16 tokens** — twice the shingle width, so a run is two disjoint
shingles before it counts as a passage rather than an idiom.

A run may be exempted only if it is **command syntax rather than prose** *and*
**no longer than 28 tokens**, the longest construct this repository has blessed
(ADR 0002's `git rev-parse` idiom). Both limits are load-bearing; without them
the exemption reopens the hole the run bound closes. Exemptions are recorded in
ADR 0003's table — the durable record — with the pull request carrying a copy.

**The final scan runs after the last rewrite commit, not against the baseline.**
This change adds tracked files (R6's two suites) and the candidate set is every
tracked file, so the denominator moves. ADR 0003 records that file count beside
the per-file figures, and names the tracked deltas that land after the scan and
are therefore not in it: the deleted `licenses/superpowers.LICENSE`, the README
and `CLAUDE.md` edits, and this record's own table fill. None of those can raise
a containment figure — one is a deletion and the rest are first-party prose.

The bar itself governs **the six rewritten files**. Every other candidate is
reported, and anything above 2% is dispositioned in ADR 0003's prose the way the
existing five are. The new suites are candidates like anything else; R6 keeps
upstream wording out of them, which is what should keep them low.

Containment alone is the wrong control. ADR 0002 reported the longest run beside
it because "one 40-word verbatim passage matters more than the same token count
scattered across unavoidable technical vocabulary", yet bounded only the
percentage — under which a large template could sit at 1.9% while keeping a
40-token verbatim passage, the exact case the notice exists for. A stated
integer is checkable where "materially above the floor" is not.

Not a requirement: reaching 0%. Short unavoidable idioms are acceptable residue,
which is why the threshold is 2% rather than nil.

Feasibility is evidenced for the scripts and not the templates: the probe was a
shell script, and its variable-renaming argument does not transfer to prose.

If any file misses, the rewrite spec's §2 fallback applies and **R4 does not
happen** — it is not reducible. Its first bullet deletes `licenses/` outright, so
one surviving citation means the notice and a shortened README list stay. Because
the measurement runs inside this change, that branch resolves before merge and
the ADR states the outcome that happened rather than carrying a conditional into
the merged record.

### R2 — the three dispatch templates keep their contract

Two reviewer prompts and one implementer prompt, all consumed by dispatched
subagents. **They do not share a vocabulary, and the gated tokens differ per
file** — a bulk "the severity words survive" requirement would leave the one file
where the risk is highest completely unprotected.

**`task-reviewer-prompt.md` and `code-reviewer.md`** keep the literal words
`Critical`, `Important`, `Minor`. Gated at:

- `skills/forge/SKILL.md:203` — "On Critical or Important findings, dispatch a
  fix subagent, then re-review."
- `skills/forge/SKILL.md:361-367` — states outright that rewriting the severity
  words at the dispatch site breaks the party mode's gates.
- `skills/gauntlet/SKILL.md:289-297` — the severity-conversion table.

**`implementer-prompt.md` carries none of those words** — zero occurrences. Its
gated vocabulary is a four-value status enum, `Status: DONE |
DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT` (implementer-prompt.md:127,
restated at :136-137). All four literals survive verbatim. Gated at
`skills/forge/SKILL.md:213-223`, "Four statuses, four responses", which
dispatches differently on each, and again at :167 and :223 for `BLOCKED`.

Normalising `DONE_WITH_CONCERNS` to something tidier is exactly the kind of edit
an author writing "from the contract" would make, and `$forge`'s party mode would
then fall through its dispatch on every implementer report. No gate can catch it;
see *Verification*.

Each template's placeholder set and required output shape survive too.

**Author these three from the in-repo contract, do not paraphrase the upstream
text.** What each must contain is already specified here — `skills/forge/SKILL.md`
states the dispatch requirements and `skills/gauntlet/SKILL.md:289-297` fixes the
severity vocabulary. Writing from that contract makes the result independent of
upstream *arrangement*, not merely of its wording, which a containment metric
does not measure. Read the existing template to extract the contract it
satisfies, then write the replacement from the contract.

The inventory each template must still satisfy after the rewrite — placeholders,
severity grades, output sections, and the caller that reads them — is written
into the plan as a per-file checklist, because it is the only check available;
see *Verification* below.

### R3 — behaviour of the three scripts is preserved exactly

Same arguments, same exit codes, same files written, same stdout contract, same
diagnostics on stderr in kind (wording may change; behaviour may not). These two
scripts have one stdout line each, a status line naming what was written: its
*wording* is a diagnostic and may change, and what is frozen is that it names the
output path.
`sdd-workspace` in particular keeps its three-way tracked / untracked /
unanswerable handling, its `check-ignore` verification on the tracked path, and
its atomic temp-file-and-rename write with the cleanup trap — that logic exists
because `$campaign`'s fail-closed reader would otherwise see a truncation gap.

### R4 — the attribution is removed

- `licenses/superpowers.LICENSE` is deleted, and `licenses/` with it.
- `CLAUDE.md`'s *Layout* entry at line 33 — "`licenses/` — attribution for skills
  still derived from upstream work" — goes with the directory. Leaving it is a
  documented path that does not exist, which this repository treats as a defect
  in its own right.
- `README.md`'s *Licence* section loses the six-file list and the
  `licenses/superpowers.LICENSE` link, keeping MIT and the pointer to the
  decision record.
- `skills/gauntlet/SKILL.md`'s stale attribution goes — **the whole passage, not
  just the sentence**. Line 289's "both derived from vendored superpowers
  prompts" clause stops being true, and so does the conversion table's own header
  two lines below it at :291, `| superpowers | here |`, which is the same claim in
  table form. Relabel that column for the scale's owner (`| $forge | here |`) and
  reword :289 to identify the two templates by role rather than ancestry. The
  table is the normative conversion `skills/forge/SKILL.md:361-367` points callers
  at, so a column named for a retired provenance is a live cross-reference.
  `rg -n --no-config -i superpowers skills/gauntlet/SKILL.md` before calling R4
  done.

### R5 — the measurement is recorded as ADR 0002 recorded its own

A new record, ADR 0003, carrying the method reference, the before/after table,
and the consequences.

**It also records the file-selection predicate**, which ADR 0002 did not. This
change is the first attempt to reproduce 0002's method with that record in hand,
and it produced a corpus 22% larger (171 files against 140). The tokeniser,
shingle width and containment formula transferred; the predicate — what counts as
an upstream file, which directories and extensions are in or out — did not,
because it was never written down. "Recorded in enough detail to reproduce" has
now been tested once and failed, so ADR 0003 records, for both sides: the
upstream ref, the exact enumeration used, any exclusions, and the resulting file
and distinct-shingle counts. That is the missing artifact — not the checker,
which stays out under anatomy rule 2. ADR 0002 gets the one edit a merged record permits: a
supersession banner on its `## Status`.

ADR 0003 lands as **`Proposed`** with its *After* column marked pending, and the
change that completes the rewrite flips it to `Accepted (YYYY-MM-DD)` in the same
commit that fills that column. The consequences — deleting `licenses/`, stripping
the README list, dropping the `$gauntlet` citation — are licensed by the
post-rewrite measurement, so the record must not assert them before it holds
them. A merged ADR whose own evidence lives only in a pull-request body is a
weaker record than the one it supersedes.

The issue asks for ADR 0002's consequences to be "updated to match". That is not
available: the `adr` profile sets `APPEND_ONLY_SECTIONS="*"`, so every level-2
section the base ref had is protected, and `docs/adr/README.md` says to
supersede with a new record rather than rewrite in place. Superseding delivers
the same outcome — a reader lands on 0002, sees the banner, and follows it to
the record that governs.

No index row: `docs/adr/README.md` deliberately has no table, and the profile
*warns* (`W-INDEX-TABLE`) if numbered rows appear.

### R6 — the two uncovered scripts gain behaviour coverage

`task-brief` and `review-package` have no suite today. Rewriting untested code
and asserting the behaviour is unchanged is an unbacked claim, so each gets a
suite under `tests/fixtures/forge/`, written against the **current** behaviour
and passing **before** the rewrite. That ordering is what makes them a
regression check rather than a description of whatever the rewrite produced.

**What the suites may assert.** R3 lets diagnostic *wording* change, and R6 wants
the suites green before the rewrite and still green after it, untouched. Both hold
only if the suites never pin a diagnostic string. So they assert: exit status;
argument handling including the arity errors (exit 2) and `task-brief`'s
not-found path (exit 3); the output file path; the structural sections of the
written file; and *that* stderr is non-empty on each error path — never the text
of a message, and never the wording of the stdout status line, only that the
named output path exists and is non-empty.

That also keeps upstream wording out of new tracked files, which matters because
those files land in the candidate set R1 rescans.

`sdd-workspace`'s existing 8-assertion suite stays green untouched.

## Verification

`just verify` at every commit, bare.

**Commit order is fixed**, because three requirements impose one and a public
branch should never carry a state that outruns its evidence:

1. the two new suites, green against the *current* scripts (R6);
2. the six rewrites, `sdd-workspace` and `task-brief` first (they are likeliest
   to hit the fallback);
3. the measurement against the merge-candidate tree (R1);
4. R4's deletions and the README edit — licensed only by step 3;
5. the ADR 0003 flip to `Accepted`, filling the table in the same commit (R5).

Doing R4 early would publish a branch where six files at 95–100% containment ship
with no notice, and point the README at a record still marked `Proposed`.

**Close-out sweep.** Before calling R4 done, run
`rg -n --no-config -i 'superpowers|licenses/'` over the tree. The expected
surviving hits, and nothing else: ADR 0002 and ADR 0003, this spec, the rewrite
spec, and the `docs/workflow/` inventories and plans that name the retired
`docs/superpowers/` paths as history. A hit in `README.md`, `CLAUDE.md`,
`skills/`, or `licenses/` means the close-out is incomplete.

Suites are auto-discovered — `just test` walks `git ls-files -z -- '*-test.sh'`
and `scripts/list-shell-sources.sh` finds shell sources by shebang — so a new
suite needs no recipe edit. It does need one registration:
`scripts/git-fixture-isolation-test.sh` carries a hand-maintained `suites=()`
list, and a new suite that touches git must be added to it or it goes unchecked
for ambient-repo pollution.

**The per-file checklist carries a literal check per gated token**, run by the
implementer and again at branch review:

    rg -c --no-config -F 'DONE_WITH_CONCERNS' skills/forge/implementer-prompt.md

and the same for `DONE`, `BLOCKED`, `NEEDS_CONTEXT`, and for `Critical`,
`Important` and `Minor` in the two reviewer prompts. R2's failure mode is a
missing literal, which is mechanically checkable by the instrument R4 already
uses — there is no reason to leave it to the eye. Reading stays the control for
output shape and placeholders, which are not literals.

This is not a gate and does not become one: it is a command a person runs from a
checklist, not an assertion wired into `just verify`.

**No automated gate asserts on the prompt templates' prose, and none will be
added.**
Repository anatomy rule 4 forbids it, and a gate grepping a Markdown file for
the word `Critical` is exactly the prohibited shape. R2 is therefore verified by
reading the per-file checklist in the plan against the rewritten file — by the
implementer, and again by branch review. Stating this plainly is better than
inventing a check the repository's own rules would reject.

## Not in scope

- `skills/forge/SKILL.md`'s residual 1.82% — issue #32 *Not in scope*, ADR 0002
  *Considered & rejected*.
- Shipping the checker — ADR 0002, anatomy rule 2.
- Changing what any template instructs or any script does. Re-expression only.

## Security and AI-surface determination

**No threat model required.** Nothing here adds or widens a trust boundary: no
new entry point, no authn/authz or tenancy logic, no secret, no new parser, no
permission grant, no dependency or lockfile change. The one safety-relevant
behaviour in scope — `sdd-workspace` refusing to clobber a tracked
`.agent/.gitignore`, and writing atomically so a concurrent fail-closed reader
never sees a truncation gap — is *preserved*, not modified, and R3 plus the
existing suite are what hold it.

**No eval plan required, and none is possible here.** The three templates are an
AI surface, but this change does not alter what they instruct — R3's
counterpart for prose. The surface's contract is unchanged by construction, and
the only honest check is the reading described under *Verification*; anatomy
rule 4 rules out an automated one. An eval harness asserting on prompt text
would be the phantom feature this repository was built to stop shipping.
