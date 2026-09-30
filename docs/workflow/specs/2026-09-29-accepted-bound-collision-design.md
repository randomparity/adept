# Accepted bounded-call status collision

## Problem

Issue #403 permits explicit acceptance of the return-124 collision. The canonical
mechanism returns 124 both for escalation and for a completed command exiting 124.
A Bash 3.2 reproduction at base ac21297 returns 124 with complete stdout.

## Scope and approach

The canonical reference owns the limitation. Document conservative classification
for the current five appliers, including false timeout diagnostics and indeterminate
writes, rather than adding a second result channel. Correct collect-telemetry's
related comment that claims a gh exit cannot be 124. Preserve executable statements,
caller exit classes, bounds, capture allocation and cleanup.

A shell return status cannot provide a value outside wrapped-command exit statuses.
An out-of-band marker would distinguish the cases but introduces another protocol
and coordinated caller edits for a limitation the issue explicitly allows accepting.
No new architecture decision is required: ADR 0068's mechanism stays in force.
No ownership transition, migration or obsolete executable path is introduced.

## Success

The reference states that 124 alone cannot prove a timeout, explicitly accepts that
ambiguity for its current git/gh callers, and explains why. It states that current
callers conservatively refuse stdout on either source of 124; only escalation
structurally empties the file. The telemetry comment describes classification, not
proof that a bound fired. The existing per-caller emitted classes stay unchanged.

## Failure model

1. Deployment: the five shipped git/gh appliers named in network-bounds.md; Bash 3.2.
2. Required failures: completed-command 124 ambiguity must be visible and its existing
   conservative classification documented, including potentially misleading diagnosis.
3. Accepted failures: ambiguity remains; a completed command exiting 124 may have its
   valid stdout refused and be reported as a timeout. Writes may be indeterminate.
4. Outside deployment: new command domains require their owner's review of this
   limitation; this change promises no behavior for new domains.

## Validation

Manual reading checks each success criterion against the reference and telemetry
comment. task-test-not-applicable: these changed promises are prose interpreted by
readers; a sentence-matching test would enforce wording without proving truth.
Compare executable statements to the base to prove no behavior changes. Verify the
mandatory version structure with just version-check, then just commit-check.
The managed pre-push hook owns the full final local suite; CI checks both hosts.
