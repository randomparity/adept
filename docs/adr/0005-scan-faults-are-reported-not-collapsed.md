# 0005 Scan faults are reported, never collapsed into a verdict

## Status

Accepted (2026-08-12)

## Context

Nearly every rule in `check-records.sh`, its profiles, and `tracker.sh` is a
scan — a `grep`, an `rg`, or a `git` query whose result decides a verdict. A
scan has three outcomes, not two: it matched, it did not match, or it could not
run. Shell makes the third easy to lose. `if ! grep ...` reads a fault as "no
match"; `cmd || true`, `cmd && return 0`, `cmd || continue`, and `[ -n "$(cmd)" ]`
discard the status outright. In every case a scan that never completed is
reported as one that completed and found nothing — and because these are gates,
"found nothing" is the passing answer. The gate goes green over content it never
read.

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
- Predicates that gain a fault value change from two-valued to three-valued, and
  that constrains how they may be called: never under `if !`, and never in an
  `&&`/`||` chain, both of which collapse `1` and `2` back into one branch and
  reinstate the defect. Every caller `case`s on the status.
- `git cat-file -e` is no longer used as an existence witness in
  `check-records.sh`.
- **Two classes of site remain outside this rule and are recorded, not
  claimed.** `check_not_rewritten` and `evaluate_base_conformance` read a base
  blob with `git cat-file blob` and fail open on any non-zero status, silently
  exempting a record from the append-only rules — owned by issue #64.
  `resolve_tracker`'s repository and `AGENTS.md` probes also fail open, to the
  default tracker; there absence is the ordinary case and no reporting channel
  exists before the tracker is resolved, so they are accepted exceptions rather
  than oversights.
- **Nothing enforces this record.** It shapes fixes; it does not prevent the
  next recurrence, because no gate checks for the idiom.

## Considered & rejected

**Fix #55's sites and leave the rule in that issue's spec.** The cheapest
option, and what happened after #25. A spec is scoped to one issue: #25's could
not have governed #55's idiom, and #55's cannot govern #63's.

**Set `set -o pipefail` globally and rely on it.** It does not address these
idioms: `|| true` discards a status pipefail already computed, and pipefail's
rightmost-nonzero rule still returns grep's `1` when an upstream stage faults
and grep then reads empty input. It would also change the status of every
existing pipeline in three scripts at once — a far larger blast radius than the
defect.

**Convert only the git-object witnesses and accept the rest.** The tempting
half-measure, since Context concedes those are the sites that fault in ordinary
use while the base-ref copies fault only under a stubbed tool. Rejected: a rule
applied to half its sites is not a rule, and the reader of the next `|| true`
has no way to tell which half they are in. The stub-only sites cost one test
each, against seven codes, nine conversions and two mirrors for the whole sweep
— the marginal cost of the unreachable half is the smallest part of the change.

**Add a CI guard that greps for the idiom.** Rejected for now, not on principle.
The objection is to a *central allowlist*: `check-records.sh` discards a status
deliberately in at least two places — one so a profile's failure cannot hide
another profile's findings — and an allowlist that drifts is how a gate starts
passing over the thing it checks. A diff-scoped guard, or an inline pragma at
each deliberate discard, avoids that failure and is worth revisiting once #55,
#63 and #64 have settled what the legitimate exceptions actually are.
