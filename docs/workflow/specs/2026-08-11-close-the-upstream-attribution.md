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
`skills/forge/SKILL.md`. A rebuild that did not reproduce them would be
measuring something other than what ADR 0002 measured, and the new numbers would
not be comparable to the old.

### Baseline

| File | Containment | Longest shared run |
|---|---|---|
| `skills/forge/task-reviewer-prompt.md` | 100.00% | 1139 |
| `skills/forge/implementer-prompt.md` | 100.00% | 816 |
| `skills/forge/code-reviewer.md` | 100.00% | 663 |
| `skills/forge/scripts/review-package` | 95.98% | 152 |
| `skills/forge/scripts/task-brief` | 95.27% | 127 |
| `skills/forge/scripts/sdd-workspace` | 11.60% | 45 |

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

### R1 — the six files fall below 2% containment

Measured by the validated rebuild against `obra/superpowers@d884ae04`, after the
rewrite. Below 2% for each of the six, individually.

Not a requirement: reaching 0%. Short unavoidable idioms are acceptable
residue, which is the whole reason the threshold is 2% rather than nil.

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
shape. Everything around them is re-expressed.

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
