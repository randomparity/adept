# 0043 — Report outranked scan faults from the caller

## Status

Accepted (2026-08-27)

## Context

`renumbered_elsewhere` and `gate_existed_at` search several independent witnesses. A fault
from one candidate must not outrank a later positive result: a real renumber destination or
evidence that the gate existed remains valid. Both predicates therefore remember faults and
return success as soon as a positive result appears. That preserves the verdict but discards
the fact that part of the search did not run.

[ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) requires a predicate to return a
distinct fault value and its caller to report it. Although ADR 0005 is formally superseded,
[ADR 0024](0024-a-failing-repository-probe-is-not-evidence-of-absence.md) withdraws one
consequence while carrying its three decisions forward unchanged. Those decisions do not define
an outcome that combines a positive answer with a reportable, outranked fault, and the existing
error channel would incorrectly turn an incomplete but decisive search into failure.

## Decision

An outranked scan fault is reportable. A multi-witness predicate that finds a positive result
after an earlier fault returns a distinct `positive-with-fault` status while preserving its
ordinary positive-result globals. Its caller emits one full-severity warning naming the failed
read and its exit status, then performs the same positive-result action it would have performed
for ordinary success.

When several reads fault before the positive result, the predicate retains and reports the last
fault encountered. The warning is a trace that the search was incomplete, not an inventory of
every failed read; earlier faults are not reported individually.

The two sites use rule-specific warning codes: `W-RENUMBER-SCAN` and
`W-GATE-WITNESS-SCAN`. A search with no positive result keeps ADR 0005's existing fault return
and error diagnostic. A search with no fault keeps its existing success or negative return.

## Consequences

The gate's exit status remains unchanged when a positive witness outranks a fault. Operators and
CI logs gain a stable trace showing that the answer was reached incompletely, with deterministic
selection when several reads fault. Callers acquire a fourth predicate outcome and must keep its
warning and positive action adjacent so later edits do not accidentally turn the warning into a
failing verdict or omit the positive action.

The warning is emitted with `warn_full`: an outranked external-read fault is independent of a
record's grandfathered shape and is not downgraded. The two mirrored gate scripts and their test
suites remain byte-identical.

## Considered & rejected

**Keep outranked faults silent.** judgment: observability; a correct verdict does not make an
external read that never ran irrelevant, and silence prevents an operator from distinguishing a
complete search from an incomplete one.

**Return the existing fault status and fail the gate.** verified: issue #87 identifies fixtures
where a later candidate or witness supplies a genuine positive result; treating the unrelated
fault as decisive would reverse the established verdict rather than report how it was reached.

**Emit the warning inside each predicate before returning success.** judgment: fit; it would
violate the caller-reporting boundary carried forward by ADR 0024 and make the predicate
responsible for both search and presentation.

**Add a side-channel global while continuing to return ordinary success.** judgment:
maintainability; every caller would have to remember to inspect optional state after an
indistinguishable success, recreating the silent omission this decision is meant to prevent.
