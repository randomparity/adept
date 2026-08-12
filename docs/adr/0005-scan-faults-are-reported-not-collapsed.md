# 0005 Scan faults are reported, never collapsed into a verdict

## Status

Accepted (2026-08-12)

## Context

Nearly every rule in `check-records.sh`, its profiles, and `tracker.sh` is a
scan — a `grep`, an `rg`, or a `git` query whose result decides a verdict. A
scan has three outcomes, not two: it matched, it did not match, or it could not
run. Shell makes the third easy to lose. `if ! grep ...` reads a fault as "no
match"; `cmd || true`, `cmd && return 0` with an unconditional fallthrough, and
`cmd || continue` discard the status outright. In every case a scan that never
completed is reported as one that completed and found nothing — and because
these are gates, "found nothing" is the passing answer. The gate goes green over
content it never read.

This was found in issue #25 and fixed in PR #54 for one idiom, then found again
in issue #55 for another. Issue #63 was split out of #55 for a third — the
pipeline shape, where the lost status belongs to a stage upstream of grep and
recovering it needs `${PIPESTATUS[@]}` and a SIGPIPE policy. Two independent
discoveries and a split are enough to say the rule belongs somewhere neither
issue owns, because each of the three is scoped to its own idiom and none of
them can state the rule for the others.

One empirical fact constrains the rule and is not evident from the manual.
`git cat-file -e <ref>:<path>` exits **128 both when the path is absent from a
valid ref and when the ref itself is bad**, so it cannot report a fault: its
normal absent case already is the fault code. Applied naively, "fault on >= 2"
would fire on every adoption PR — the exact false red the gate's closed witness
set exists to prevent.

## Decision

**1. A scan whose result feeds a verdict captures its own exit status and
branches three ways** — matched, did not match, and could not run — and never
lets the third fall into the second. The fault is reported through whatever
channel that script already fails through, naming the file it was reading and
the exit status it got. In the record-gate scripts that channel is a coded
`::error::` line, so a fault there gets an `E-<RULE>-SCAN` code like any other
finding; in `tracker.sh` it is the usage exit, which carries no codes.

**2. A command whose exit status cannot separate "absent" from "faulted" is not
admissible as a witness.** `git cat-file -e` is such a command. Where existence
at a ref must be witnessed, use `git ls-tree -r --name-only <ref> -- <path>` and
test whether it produced output: it exits `0` with empty output for an absent
path and non-zero only for a real fault, so the two are distinguishable.

**3. A predicate that can fault becomes three-valued, and its caller reports.**
The predicate returns a distinct fault value rather than emitting the
diagnostic, and the caller reports the fault *instead of* its ordinary negative
verdict, never alongside it. A fault that fires both `E-*-SCAN` and the rule's
own error tells the reader the rule failed, which is a claim the gate did not
establish.

**4. A helper that runs inside a process substitution guards its inputs instead
of acquiring a reporting channel.** `err` sets `failed=1`, and inside a subshell
that assignment is discarded while the message still prints — the shape that
once let this gate print an error and exit 0. Such a helper constrains its input
so the fault cannot arise, rather than gaining a way to report one.

## Consequences

- Each new `E-*-SCAN` code names the file and the exit status, because a scan
  fault a reader cannot locate is barely better than a silent one. The codes are
  part of the gate's public interface.
- Predicates that gain a fault value change from two-valued to three-valued.
  Their callers are in the current shell, so the caller-reports rule costs
  nothing.
- `git cat-file -e` is no longer used as an existence witness in
  `check-records.sh`. `git cat-file blob`, which reads content rather than
  witnessing existence, is unaffected.
- Rule 4 constrains where a scan may live, not only how it reports. Moving a
  scan into a process substitution now requires guarding it or moving it back
  out.
- **Nothing enforces this record.** It shapes fixes; it does not prevent the
  next recurrence, because no gate checks for the idiom. An automated guard
  would need an allowlist — `check-records.sh` discards a status deliberately in
  at least two places, where one profile's failure must not hide another's
  findings — so the guard is a design problem of its own and is not attempted
  here.
- The rule is stated once, so #63's sweep argues about `PIPESTATUS` and SIGPIPE,
  its actual open questions, rather than re-deriving why a fault must be
  reported at all.

## Considered & rejected

**Fix #55's sites and leave the rule in that issue's spec.** The cheapest
option, and it is what happened after #25. A spec is scoped to one issue: #25's
could not have governed #55's idiom, and #55's cannot govern #63's. A rule
spanning all three needs a home none of them owns.

**Set `set -o pipefail` globally and rely on it.** It does not address these
idioms: `|| true` discards a status pipefail already computed, and pipefail's
rightmost-nonzero rule still returns grep's `1` when an upstream stage faults
and grep then reads empty input. It would also change the status of every
existing pipeline in three scripts at once — a far larger blast radius than the
defect.

**Parse stderr to tell `git cat-file -e`'s two 128s apart.** Matching `fatal:
path ... does not exist` means depending on an unstable human-readable string
across git versions and locales, to recover what another plumbing command
reports in its exit status for free.

**Let the faulting predicate emit its own diagnostic and stay two-valued.**
Fewer call-site changes, but the caller then cannot suppress its own negative
verdict, so a fault reports twice — once honestly and once as a rule failure
that was never established. Issue #55 named that double-report as a defect to
fix, not a pattern to spread.

**Concentrate the `grep`/`rg` scans in one helper, as rule 2 does for the git
witnesses.** Tempting for symmetry, but the git witnesses share one question
("is this path at this ref?") while the grep scans do not: each has its own
diagnostic wording and its own post-fault control flow — return, skip the loop,
suppress one specific verdict. A shared helper would take a code, a message
fragment and a callback, and would save nothing over three-way branching written
in place.

**Give a process-substitution helper a reporting channel — a sentinel line its
caller translates, or a status file.** Workable, but it adds a private protocol
between two functions to report a fault whose only trigger is an input the
caller can guard against directly. The guard is three lines and needs no
protocol.

**Add a CI guard that greps for the idiom.** Rejected for now, not on principle:
the deliberate discards noted in Consequences mean any such guard needs an
allowlist, and an allowlist that drifts is how a gate starts passing over the
thing it checks. Worth revisiting once the three sweeps have settled what the
legitimate exceptions actually are.
