# 0056 — Publication cleanup reports and continues

## Status

Accepted (2026-09-06)

## Context

`publish-forge-review` disposes its scratch inputs after it has posted the `WORK:REVIEW`
comment, read it back, and appended `review-publication-verified:` to the private ledger.
`dispose()` treats a disposer error as fatal, so a cleanup failure exits 1 once the run's
product is already durable.

`$quest` step 8 parks on any nonzero helper exit without retrying, and the
`publication-verified` transition also requires the disposal record a failed disposal never
writes. The publication-recovery predicates then refuse recovery whenever a
`review-publication-verified:` line exists, so the park cannot self-clear. `gio trash` refusing
a system-internal mount — a routine condition, not a broken host — is enough to strand a
published, verified run. Nonzero currently means both "did not publish" and "published, could
not tidy up", and the caller cannot separate them.

## Decision

Nonzero exit means the helper did not publish. After the verified ledger line, disposal is
best-effort and reported rather than fatal: every owned path is attempted, the failure is warned
on stderr naming the retained paths, and the helper prints the verified comment URL and exits 0.

The ledger keeps a complete statement of the outcome in up to two records —
`review-publication-disposed:` naming exactly the paths disposed, and
`review-publication-undisposed:` naming exactly the paths retained. Each lists its own paths in
the helper's owned order, and their union is all and only the owned paths. An all-succeed run
writes the disposed record alone, unchanged from before.

A ledger append failure stays fatal. `$quest` and `$forge` read either record as proof the
publication happened, so both bar an automatic or human-authorized republication.

The single platform disposer stays. A missing recoverable-delete command still fails in
`preflight()`, before any GitHub request.

## Consequences

- A cleanup failure after publication no longer parks a green run in a state the recovery
  predicates forbid recovering.
- The ledger distinguishes "helper never ran" from "helper ran, cleanup incomplete"; silence
  could not.
- Private scratch content can survive a run without a human being forced to notice. The stderr
  warning, the ledger record, and the hand-off are the compensating disclosure; the content
  stays in the mode-0700, git-ignored workspace where the old failure path already left it.
- Ledger readers must match both record kinds. One matching only
  `review-publication-disposed:` sees an incomplete cleanup as no cleanup.
- The exit guard that fails a zero-status run with a surviving body no longer applies to a body
  the undisposed record names; it still guards every unrecorded leak.

## Considered & rejected

- **Exit 2 for "published, cleanup incomplete", as ADR 0045 does for gates.** judgment: a gate's
  caller reads an exit taxonomy, while this helper's caller has one rule — nonzero parks without
  retrying. A status only an updated caller interprets correctly reintroduces the park for
  anything not yet updated, and the ledger already carries the distinction durably.
- **A fallback disposer chain.** verified: at base commit
  `c939eea39cd279725f0e5156d7ddfea01e17df49` on macOS 15.6 (Darwin 25.6.0), running the helper
  with `trash` removed from `PATH` and a `gh` stub that reports every invocation printed
  `publish-forge-review: recoverable-delete command is unavailable`, exited 1, left the ledger
  and all three inputs untouched, and never reached the stub. "No recoverable-delete command
  exists" is therefore already separated from "a present disposer refused this filesystem",
  which is the only condition a chain would address. Judgment: a chain's members are binaries no
  gate can prove exist, and the one universally present fallback, `rm`, is not recoverable —
  the property the disposer exists to provide.
- **Omit the record when disposal fails and warn only.** judgment: this is the reported defect.
  A missing record is indistinguishable from a helper that never ran, which is what makes the
  current park unrecoverable.
- **Dispose before appending the verified line.** judgment: it would claim disposal not yet
  performed, and a crash between the two would leave a verified publication with no record.
- **Stop at the first disposer failure, as today.** judgment: a filesystem that refuses one path
  usually refuses all of them, so stopping early buys nothing while one odd path strands every
  path after it.
