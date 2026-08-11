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
hold over that set: `LICENSE` (95.71%, run 163) is the MIT text both projects
share, `scripts/pre-push-hook` (6.06%, run 9) is one `set -euo pipefail` /
`git rev-parse --show-toplevel` idiom, and two `docs/workflow/` records (2.51%
run 16, 2.25% run 51) quote the upstream behaviour they inventory and retire,
naming the source in their own prose.

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
that file keeps its attribution and the obligation stays open for it — ADR
0002's own §2 fallback. The probe says this will not arise.

## Requirements

### R1 — the six files fall below the threshold

Measured by the validated rebuild against `obra/superpowers@d884ae04`, after the
rewrite, for each of the six individually: **below 2% containment** and **no
shared run over 16 tokens**, except functional constructs, each of which is
enumerated individually in the pull request rather than asserted in bulk.

Containment alone is the wrong control. ADR 0002 reported the longest run beside
it because "one 40-word verbatim passage matters more than the same token count
scattered across unavoidable technical vocabulary", yet bounded only the
percentage — under which a large template could sit at 1.9% while keeping a
40-token verbatim passage, the exact case the notice exists for. A stated
integer is checkable where "materially above the floor" is not.

Not a requirement: reaching 0%. Short unavoidable idioms are acceptable residue,
which is why the threshold is 2% rather than nil.

Feasibility is evidenced for the scripts and not the templates: the probe was a
shell script, and its variable-renaming argument does not transfer to prose. If
a file misses, the rewrite spec's §2 fallback applies — it keeps its attribution
and R4 is reduced accordingly. Because the measurement runs inside this change,
that branch resolves before merge; the ADR states the outcome that happened
rather than carrying a conditional into the merged record.

### R2 — the three reviewer templates keep their dispatch contract

These are prompts consumed by dispatched subagents, and two other places gate on
their vocabulary:

- `skills/forge/SKILL.md:203` — "On Critical or Important findings, dispatch a
  fix subagent, then re-review."
- `skills/forge/SKILL.md:361-367` — states outright that rewriting the severity
  words at the dispatch site breaks the party mode's gates.
- `skills/gauntlet/SKILL.md:289-297` — a severity-conversion table keyed on
  `Critical` / `Important` / `Minor`.

So the literal words **`Critical`, `Important`, `Minor`** survive verbatim in
all three templates, as does each template's placeholder set and required output
shape.

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

Same arguments, same exit codes, same stdout contract, same files written, same
diagnostics on stderr in kind (wording may change; behaviour may not).
`sdd-workspace` in particular keeps its three-way tracked / untracked /
unanswerable handling, its `check-ignore` verification on the tracked path, and
its atomic temp-file-and-rename write with the cleanup trap — that logic exists
because `$campaign`'s fail-closed reader would otherwise see a truncation gap.

### R4 — the attribution is removed

- `licenses/superpowers.LICENSE` is deleted, and `licenses/` with it.
- `README.md`'s *Licence* section loses the six-file list and the
  `licenses/superpowers.LICENSE` link, keeping MIT and the pointer to the
  decision record.
- `skills/gauntlet/SKILL.md`'s "both derived from vendored superpowers prompts"
  citation is dropped — it stops being true, and a stale attribution is a
  correctness defect in the opposite direction.

### R5 — the measurement is recorded as ADR 0002 recorded its own

A new record, ADR 0003, carrying the method reference, the before/after table,
and the consequences. ADR 0002 gets the one edit a merged record permits: a
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

`sdd-workspace`'s existing 8-assertion suite stays green untouched.

## Verification

`just verify` at every commit, bare.

Suites are auto-discovered — `just test` walks `git ls-files -z -- '*-test.sh'`
and `scripts/list-shell-sources.sh` finds shell sources by shebang — so a new
suite needs no recipe edit. It does need one registration:
`scripts/git-fixture-isolation-test.sh` carries a hand-maintained `suites=()`
list, and a new suite that touches git must be added to it or it goes unchecked
for ambient-repo pollution.

**No gate asserts on the prompt templates' prose, and none will be added.**
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
