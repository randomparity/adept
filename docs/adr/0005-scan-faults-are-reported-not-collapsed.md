# 0005 Scan faults are reported, never collapsed into a verdict

## Status

Accepted (2026-08-12)

> **Superseded by [0024](0024-a-failing-repository-probe-is-not-evidence-of-absence.md)** (2026-08-19)

## Context

Nearly every rule in `check-records.sh`, its profiles, and `tracker.sh` is a
scan — a `grep`, an `rg`, or a `git` query whose result decides a verdict. A
scan has three outcomes, not two: it matched, it did not match, or it could not
run. Shell makes the third easy to lose. `if ! grep ...` reads a fault as "no
match"; `cmd || true`, `cmd && return 0`, `cmd || continue`, and `[ -n "$(cmd)" ]`
discard the status outright. Wherever no later check re-reads the same bytes, a
scan that never completed is then reported as one that completed and found
nothing — and because these are gates, "found nothing" is the passing answer.
The gate goes green over content it never read.

Reachability varies by site. The git-object witnesses can fault against a
damaged object store or a bad ref in ordinary use; the scans over base-ref
copies read files this process creates and removes itself, so their fault is
reachable mainly under a stubbed tool. Both are worth closing, but only the
first is a live operational risk.

This was found in issue #25 and fixed in PR #54 for one idiom, then found again
in issue #55 for another. Issue #63 was split out of #55 for a third — the
pipeline shape, where the lost status belongs to a stage upstream of grep.
Each of the three is scoped to its own idiom and none can state the rule for the
others, so the rule needs a home none of them owns.

One empirical fact constrains it. `git cat-file` exits **128 both when the path
is absent from a valid ref and when the ref itself is bad**, so it cannot report
a fault: its normal absent case already is the fault code. Applied naively,
"fault on >= 2" would fire on every adoption PR — the false red the gate's
closed witness set exists to prevent.

## Decision

**1. A scan that reads external bytes — a file on disk or a git object — and
whose result feeds a verdict captures its own exit status and branches three
ways** — matched, did not match, could not run — and never lets the third fall
into the second. A command reading only in-memory input, such as `printf` over a
shell variable, is outside this rule: its failure modes are not the
scan-could-not-run case. The fault is reported through whatever channel that
script already fails through, naming the file it was reading and the exit status
it got. In the record-gate scripts that channel is a coded `::error::` line, so a
fault gets an `E-<RULE>-SCAN` code — per rule rather than one generic `E-SCAN`,
so a test can assert *which* site faulted and not merely that one did.
`tracker.sh` has no code channel
and reports through its usage exit. Issue #55 asked for a coded diagnostic at
every site, and this is a deliberate deviation from that wording: the rule is
"report through the channel that exists", not "invent one". A scan inside a
process substitution has no channel at all, because `err` sets `failed=1` into a
discarded subshell — such a scan is guarded at its input or moved out, not given
a private protocol.

**2. A command whose exit status cannot separate "absent" from "faulted" is not
admissible as a witness.** `git cat-file` is such a command. Witness existence
with `git ls-tree -r --name-only <ref> -- <path>` instead: **capture its status
first**, and read the output only after. Non-zero is a fault; zero with empty
output is absent; zero with output is present. Testing the output alone —
`[ -n "$(git ls-tree ...)" ]` — discards the status and is the shape this rule
replaces, not an application of it.

**3. A predicate that can fault becomes three-valued, and its caller reports.**
The predicate returns a distinct fault value rather than emitting the
diagnostic, and the caller reports the fault *instead of* its ordinary negative
verdict, never alongside it. A fault that fires both `E-*-SCAN` and the rule's
own error tells the reader the rule failed, which is a claim the gate did not
establish.

## Consequences

- Each new `E-*-SCAN` code names the file and the exit status. The codes are
  stable because the test suite asserts on them by name.
- Reporting goes through `err_full` rather than `err`, so a scan fault cannot be
  downgraded to `W-LEGACY-SHAPE` for a record that was already non-conforming —
  a fault describes the scan, not the record. Both helpers are suppressed in the
  base-ref `collect` pass, which discards findings by design, so a fault
  reachable only while scanning the base-ref blob goes unreported there and the
  record reads as conforming. Accepted rather than fixed: the alternative is a
  fourth emit mode, which costs more than the case is worth.
- Predicates that gain a fault value change from two-valued to three-valued, and
  that constrains how they may be called: never under `if !`, and never in an
  `&&`/`||` chain that *branches* on the predicate, both of which collapse `1`
  and `2` into one branch and reinstate the defect. Every caller captures the
  status and `case`s on it. These scripts run under `set -euo pipefail`, where a
  bare call and a following `; status=$?` both abort, so the capture is written
  `status=0; predicate ... || status=$?` — an `||` that assigns rather than
  branches, and the required form rather than merely a permitted one.
- `git cat-file -e` is no longer used as an existence witness in
  `check-records.sh`.
- **Sites remain outside this rule. They are recorded with owners, and the list
  is not claimed to be exhaustive** — the sweep that found them is one reading of
  three scripts, not a mechanical guarantee. `check_not_rewritten`,
  `evaluate_base_conformance` and `renumbered_elsewhere` read a base blob with
  `git cat-file blob` and mishandle a non-zero status — the first two fail open,
  silently exempting a record from the append-only rules; the third fails closed
  into a misattributed `E-GONE` — all owned by issue #64. `records_in_ref`'s
  extraction can empty the base record list and so disarm `E-COUNT-FLOOR`; that
  is a pipeline site, owned by issue #63. `resolve_tracker`'s repository and
  `AGENTS.md` probes fail open to the default tracker: both test for *absence*
  rather than scanning content, and absence is the ordinary case — accepted
  exceptions, not oversights.
- **Nothing enforces this record.** It shapes fixes; it does not prevent the
  next recurrence, because no gate checks for the idiom. Whether one should, and
  in which shape, is owned by issue #66.

## Considered & rejected

**Fix #55's sites and leave the rule in that issue's spec.** The cheapest
option, and what happened after #25. A spec is scoped to one issue: #25's could
not have governed #55's idiom, and #55's cannot govern #63's.

**Rely on `set -o pipefail`.** All three scripts already set it, which is what
settles this: `|| true` discards a status pipefail has already computed, and
pipefail's rightmost-nonzero rule still returns grep's `1` when an upstream
stage faults and grep then reads empty input. The option is necessary and not
sufficient.

**Convert only the git-object witnesses and accept the rest.** The tempting
half-measure, since Context concedes those are the sites that fault in ordinary
use while the base-ref copies fault only under a stubbed tool. Rejected because
the reader of the next `|| true` has no way to tell which half they are in, and
because the stub-only sites cost one test each against seven codes, nine
conversions and two mirrors for the whole sweep — the marginal cost of the
unreachable half is the smallest part of the change.

**Add a CI guard that greps for the idiom.** Rejected for now, not on principle.
The objection is to a *central allowlist*: `check-records.sh` discards a status
deliberately in at least two places — one so a profile's failure cannot hide
another profile's findings — and an allowlist that drifts is how a gate starts
passing over the thing it checks. A diff-scoped guard, or an inline pragma at
each deliberate discard, avoids that failure and is worth revisiting once #55,
#63 and #64 have settled what the legitimate exceptions actually are.
