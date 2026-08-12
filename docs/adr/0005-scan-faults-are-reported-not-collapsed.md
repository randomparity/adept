# 0005 Scan faults are reported, never collapsed into a verdict

## Status

Accepted (2026-08-12)

## Context

Nearly every rule in `check-records.sh`, its profiles, and `tracker.sh` is a
scan — a `grep`, an `rg`, or a `git` query whose result decides a verdict. A
scan has three outcomes, not two: it matched, it did not match, or it could not
run. Shell makes the third outcome easy to lose. `if ! grep ...` reads a fault
as "no match". `cmd || true` discards the status entirely. `cmd && return 0`
with an unconditional `return 1` fallthrough does the same. In every case a scan
that never completed is reported as a scan that completed and found nothing —
and because these are gates, "found nothing" is the passing answer. The gate
goes green over content it never read.

This has now been found three times: issue #25 (the `if (!) grep` shape, fixed
in PR #54), issue #55 (the `cmd || true` and `cmd && return 0` shapes), and
issue #63 (pipelines, where the upstream stage's status is hidden behind
grep's). Each rediscovery cost a review cycle to re-argue from first principles,
and the fixes drifted in shape because nothing recorded what the shape was.

One empirical fact drove the rest of this decision and is not obvious from the
manual. `git cat-file -e <ref>:<path>` exits **128 both when the path is absent
from a valid ref and when the ref itself is bad**:

```
$ git cat-file -e "$sha:no-such-file.md"; echo $?
fatal: path 'no-such-file.md' does not exist in '<sha>'
128
```

So the "capture the status and fault on >= 2" rule cannot be applied to it. Its
normal absent case *is* the fault code. Applied naively it would fire a scan
fault on every adoption PR — the exact false red the gate's self-protection
comments say the closed witness set exists to prevent.

## Decision

**1. A scan whose result feeds a verdict captures its own exit status and
branches three ways.** `0` matched, `1` did not match, `>= 2` is a fault, which
reports a coded `E-<RULE>-SCAN` diagnostic naming the file it was reading and
the exit status it got. The coded `::error::` lines are the gate's public
interface, so a scan fault gets a code like any other finding.

**2. A command whose exit status cannot separate "absent" from "faulted" is not
admissible as a witness.** `git cat-file -e` is such a command. Where existence
at a ref must be witnessed, use `git ls-tree -r --name-only <ref> -- <path>` and
test whether it produced output: it exits `0` with empty output for an absent
path and non-zero only for a real fault, so the two are distinguishable. This
repository routes all three of its existence witnesses through one
`path_exists_at` helper returning `0` present / `1` absent / `2` fault, so the
rule is enforced in one place rather than restated at each call site.

**3. A predicate that can fault becomes three-valued, and its caller reports.**
The predicate returns `2` rather than emitting the diagnostic itself, and the
caller's `case` reports the fault *instead of* its ordinary negative verdict —
never alongside it. A fault that fires both `E-*-SCAN` and the rule's own error
tells the reader the rule failed, which is a claim the gate did not establish.

**4. A helper that runs inside a process substitution guards its inputs instead
of acquiring a reporting channel.** `err` sets `failed=1`, and inside a
subshell that assignment is discarded while the message still prints — the
shape that once let this gate print an error and exit 0. `gate_paths` is such a
helper and is documented as emitting paths only. Where its inputs could make a
scan fault, it constrains the input (an empty pathspec is checked before the
call, matching the `[ -n "$rel" ]` guard its neighbouring emissions already
use) rather than gaining a way to report.

## Consequences

- Six new `E-*-SCAN` codes join the gate's interface. Each names the file and
  the exit status, because a scan fault a reader cannot locate is barely better
  than a silent one.
- `renumbered_elsewhere` and `gate_existed_at` change from two-valued to
  three-valued. Both are internal to `check-records.sh`, and both callers are in
  the current shell, so the caller-reports rule costs nothing.
- `git cat-file -e` is no longer used as an existence witness anywhere in
  `check-records.sh`. `git cat-file blob`, which reads content rather than
  witnessing existence, is unaffected.
- `path_exists_at` runs `git ls-tree` where a `cat-file -e` ran before. Both are
  single git invocations over the same object store; the gate already runs one
  per record.
- Rule 4 is a constraint on where scans may live, not only on how they report.
  Moving a scan into a process substitution now requires either guarding it or
  moving it back out.
- The rule is stated once here, so #63's sweep argues about `PIPESTATUS` and
  SIGPIPE — its actual open questions — rather than re-deriving why a fault must
  be reported at all.

## Considered & rejected

**Do nothing; fix each site as it is found.** This is the status quo that
produced three issues for one defect class, with three different fix shapes
proposed and the rationale re-argued each time. The cost of the record is one
file; the cost of not having it is measured in review cycles already spent.

**Set `set -o pipefail` globally and rely on it.** It does not address the
idioms at issue: `|| true` discards a status pipefail already computed, and
pipefail's rightmost-nonzero rule still returns grep's `1` when an upstream
`awk` faults and grep then reads empty input. It would also change the status of
every existing pipeline in three scripts at once, which is a far larger blast
radius than the defect.

**Parse stderr to tell `git cat-file -e`'s two 128s apart.** Matching `fatal:
path ... does not exist` is matching an unstable human-readable string across
git versions and locales, to recover information another plumbing command
reports in its exit status for free.

**Let the faulting predicate emit its own diagnostic and keep returning
two values.** Fewer call-site changes, but the caller then cannot suppress its
own negative verdict, so a fault reports twice — once honestly and once as a
rule failure that was never established. Issue #55 named exactly that
double-report in `check_title_number` as a defect to fix, not a pattern to
spread.

**Give `gate_paths` a reporting channel — a sentinel line its caller
translates, or a status file.** Workable, but it adds a private protocol between
two functions to report a fault whose only trigger is an empty pathspec the
caller can simply guard against. The guard is three lines and needs no protocol.
