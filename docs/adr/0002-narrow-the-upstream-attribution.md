# 0002 — Narrow the upstream attribution to the six files that earned it

## Status

Accepted (2026-08-11)

## Context

Eleven of this repository's skills descended from
[obra/superpowers](https://github.com/obra/superpowers) v6.1.1, commit
`d884ae04`, carried under the retired `agent-config` repository's fork-maintenance
policy. Six units of work replaced all eleven with first-party equivalents:
seven were absorbed into existing skills, three became references under
`references/`, and `systematic-debugging` was rewritten in place.

The rewrite spec's §2 sets the standard for shedding the attribution. A strict
clean-room process was not available and would have been theatre — the migration
had already put several upstream skills in full into an implementing session's
context. The standard adopted instead was **verified low similarity**: compare
each shipped file against its upstream ancestor mechanically, using shingled
n-gram overlap rather than inspection, and remove the notice only where the
measurement supports it.

§2 also fixed the fallback in advance: "If verification is awkward for a given
file, retaining attribution for that file is an acceptable outcome." The
obligation attaches to surviving upstream *expression*, not to whether anyone
read the original.

## Decision

**Retain attribution for six files. Remove the blanket claim covering the rest.**

The measurement is the reason, and it splits the tree cleanly. Every file that
was **rewritten** is below the threshold. Every file that was **moved** — carried
across a directory boundary in units 2 and 3 without being rewritten, because
rewriting them was never in scope — is at or near total overlap:

| File | Containment | Longest shared run |
|---|---|---|
| `skills/build-tdd/task-reviewer-prompt.md` | 100.00% | 1139 tokens |
| `skills/build-tdd/implementer-prompt.md` | 100.00% | 816 |
| `skills/build-tdd/code-reviewer.md` | 100.00% | 663 |
| `skills/build-tdd/scripts/review-package` | 95.98% | 152 |
| `skills/build-tdd/scripts/task-brief` | 95.27% | 127 |
| `skills/build-tdd/scripts/sdd-workspace` | 11.60% | 45 |

No other shipped file reaches 2%. The highest is `skills/build-tdd/SKILL.md` at
1.82%, whose longest shared run is a 28-token shell idiom for resolving
`--git-dir` against `--git-common-dir` — a functional construct with no
meaningfully different way to write it, deliberately left alone rather than
varied for the sake of variation.

### Method

Each file is reduced to a token stream: lowercased, every run of `[a-z0-9]`
kept, everything else discarded. That erases Markdown, casing, punctuation and
line wrapping, so reformatting cannot hide copied wording. The stream is cut
into overlapping 8-token shingles, and for candidate file C against the union U
of all upstream shingles:

    containment(C) = |shingles(C) ∩ U| / |shingles(C)|

Containment rather than Jaccard, because the question is one-directional: what
fraction of *this* file is upstream expression? Jaccard would be diluted by the
size difference between a 138-line reference and a 20,000-token corpus. The
longest run of consecutive matching tokens is reported alongside, because one
40-word verbatim passage matters more than the same token count scattered across
unavoidable technical vocabulary.

Every candidate is compared against **all** 140 upstream files rather than a
hand-assigned ancestor, so a wrong pairing assumption cannot hide a match.

### What the first run found, and what changed because of it

The gate did not merely confirm the rewrite. Its first run failed on three files
that had been rewritten, and each finding was real:

- `skills/systematic-debugging/SKILL.md` carried its upstream `description:`
  frontmatter verbatim. Unit 6 rewrote 948 lines of body and left the four lines
  above it untouched. Nothing but a mechanical check would have caught that.
- `skills/design/SKILL.md` retained three passages from upstream `writing-plans`
  — the task right-sizing definition, the placeholder blocklist, and the
  file-mapping instruction — at up to 25 tokens.
- `skills/build-tdd/SKILL.md` retained eight passages from upstream
  `subagent-driven-development`, the longest 39 tokens.

All were re-expressed. §2 requires that any passage above a low threshold be
"rewritten or cited"; these were rewritten. After that pass:

| File | Before | After |
|---|---|---|
| `skills/build-tdd/SKILL.md` | 6.76% | 1.82% |
| `skills/design/SKILL.md` | 1.43% | below 0.10% |
| `skills/systematic-debugging/SKILL.md` | 0.65% | 0.00% |

## Consequences

- `LICENSE` remains MIT and now names this project rather than its predecessor.
- `licenses/superpowers.LICENSE` **stays**. It is not vestigial: six shipped
  files are substantially upstream expression, and MIT requires the notice to
  travel with them.
- `README.md` no longer claims vaguely that "some skills derive from" upstream.
  It names the six files, so a reader can see the extent of the obligation
  instead of inferring it.
- `$challenge`'s note that `$build-tdd`'s reviewer templates are "derived from
  vendored superpowers prompts" was already accurate and is now the correct
  citation rather than an incidental remark.
- The re-vendor ritual is gone regardless. Nothing here tracks upstream any
  more; the six files are a snapshot with a licence attached, not a fork being
  maintained.
- The obligation is now bounded and closable. Rewriting those six files would
  end it completely, which is tracked as a follow-up rather than folded into
  this change — they are prompt templates and tested scripts, and rewriting them
  is a unit of work, not a tidy-up.
- The checker itself is not shipped. It is a one-time verification, and
  repository anatomy rule 2 admits a script only when it does something a model
  cannot do reliably inline and is needed on an ongoing basis. Its method is
  recorded above in enough detail to reproduce, and its full output is in the
  pull request that carried this record.

## Considered & rejected

**Remove the attribution entirely.** The measurement forbids it. Three files are
100% upstream expression and two more are above 95%; dropping the notice would
be a licence violation dressed up as a milestone.

**Rewrite the six now, then remove everything.** This is the better end state and
is exactly why it is a tracked follow-up rather than a rider on this change. The
three prompt templates are dispatch contracts that `$build-tdd`'s gates key on,
and the three scripts have behaviour suites; changing them is implementation
work with its own review, not part of recording a measurement.

**Vary the shell idiom in `build-tdd/SKILL.md` to drive 1.82% lower.** Rejected
as theatre. There is no materially different way to write that `git rev-parse`
pair, functional constructs are not what the licence protects, and changing
working code to move a number is the behaviour §2 warned against.

**Ship the checker as a repository gate.** Rejected under anatomy rule 2. Once
the six files are cited there is nothing left for it to gate, and a gate that
depends on cloning a third-party repository at a pinned commit is a network
dependency in the guardrail suite.

## Provenance

target: licenses/superpowers.LICENSE
target: skills/build-tdd/code-reviewer.md
target: skills/build-tdd/implementer-prompt.md
target: skills/build-tdd/task-reviewer-prompt.md
target: skills/build-tdd/scripts/review-package
target: skills/build-tdd/scripts/sdd-workspace
target: skills/build-tdd/scripts/task-brief

Measured 2026-08-11 against `obra/superpowers` at
`d884ae04edebef577e82ff7c4e143debd0bbec99` (v6.1.1, 2026-07-02), 140 files and
161,753 distinct 8-token shingles. Decided by the rewrite spec
`docs/workflow/specs/2026-08-11-first-party-skill-rewrite-design.md` §2.

The rename sweep of 2026-08-11 moved the six cited files from `skills/build-tdd/`
to `skills/forge/`. The targets above name where they were measured; these name
where they now are.

target: skills/forge/code-reviewer.md
target: skills/forge/implementer-prompt.md
target: skills/forge/task-reviewer-prompt.md
target: skills/forge/scripts/review-package
target: skills/forge/scripts/sdd-workspace
target: skills/forge/scripts/task-brief
