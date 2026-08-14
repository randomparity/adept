# 0014 — Select reviewers at the trial-loop boundary

## Status

Accepted (2026-08-13)

## Context

`$trial-loop` owns bounded review iteration, finding dispositions, deferral records, charter
handling, and convergence rules, but it can invoke only `$gauntlet`. `$detect-evil` deliberately
emits the same artifact and verdict schema, yet a standalone security scan has no route through
that lifecycle. Copying the loop into the scanner would create two owners for safety-sensitive
stop and deferral behavior.

## Decision

Make reviewer selection an explicit `$trial-loop` input. The grammar is
`--reviewer gauntlet|detect-evil`: the flag may appear once anywhere before the line-anchored
`CHARTER` block, consumes the next token, and defaults to `gauntlet` when absent. A missing value,
unknown name, or duplicate selector stops before dispatch. The loop strips and validates the
selector before hashing, target classification, or forwarding challenge arguments. It first splits
the invocation at the charter boundary, so a selector at the end of the pre-charter prefix is
missing its value and cannot consume or discard the charter. The loop then uses the selected
reviewer's name consistently in dispatch, audit, stop, and report language.

The reviewer boundary requires the shared structured artifact contract already implemented by both
reviewers: `approve | needs-attention`, findings and suppressions counts, a path, and a run ID.
Finding reception, four-way disposition, deferral ownership, bounded retries and iterations,
convergence, rescoping, and caller continuation remain owned once by `$trial-loop`.

## Consequences

Standalone security reviews can request the existing lifecycle without changing `$detect-evil`
into a mutating coordinator. Existing `$trial-loop` calls retain their behavior because omitted
selection means `$gauntlet`. Adding another reviewer later requires an explicit contract decision;
arbitrary skill names are rejected rather than treated as compatible by assertion.

Some `$trial-loop` prose must become reviewer-neutral while preserving gauntlet-specific behavior
where it is real, including accepted-ADR handling and target-resolution semantics shared by
delegation. Behavioral review, not prose-matching automation, proves the composed contract.

## Considered & rejected

**Make `$detect-evil` delegate to `$trial-loop`.** Rejected because the loop still needs a distinct
raw scanner to invoke, making ownership and recursion harder to state.

**Copy a minimal loop into `$detect-evil`.** Rejected because disposition, deferral, convergence,
and bounded-stop rules would immediately have two implementations.

**Accept any reviewer that claims the artifact schema.** Rejected because schema compatibility
does not establish target parsing, charter handling, read-only behavior, or verdict semantics.

**Do nothing.** Rejected because standalone security findings remain checkpoints without a defined
owner or settled-state path.
