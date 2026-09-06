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

The ledger, not the exit status, says whether publication happened: nonzero means the helper did
not publish **unless** `review-publication-verified:` already reached the ledger. After that line,
disposal is best-effort and reported rather than fatal: every owned path is attempted, the failure
is warned on stderr naming the retained paths, and the helper prints the verified comment URL and
exits 0.

The ledger keeps a complete statement of the outcome in up to two records —
`review-publication-disposed:` naming exactly the paths disposed, and
`review-publication-undisposed:` naming exactly the paths retained. Each lists its own paths in
the helper's owned order, and their union is all and only the owned paths. An all-succeed run
writes the disposed record alone, unchanged from before.

A ledger append failure stays fatal. `$quest` and `$forge` read either record as proof the
publication happened, so both bar an automatic or human-authorized republication. Because an
owned path may contain spaces, a consumer never decides membership by splitting a record on
whitespace; it knows the owned paths and their order, so it reconstructs the exact record text for
the partition under test and compares whole lines.

The single platform disposer stays. verified: at base commit
`c939eea39cd279725f0e5156d7ddfea01e17df49` on macOS 26.6 (Darwin 25.6.0), running the helper with
`trash` removed from `PATH` and a `gh` stub that reports every invocation printed
`publish-forge-review: recoverable-delete command is unavailable`, exited 1, left the ledger and
all three inputs untouched, and never reached the stub — a missing recoverable-delete command
still fails in `preflight()`, before any GitHub request.

## Consequences

- A **disposer** failure after publication no longer parks a green run in a state the recovery
  predicates forbid recovering.
- A **ledger** append or readback failure after the verified line still exits nonzero, and
  `skills/quest/SKILL.md`'s recovery predicates still refuse recovery once that line exists, so
  that path remains stranded. It is a different fault — the ledger is the record this design
  relies on, so a helper that cannot write it has nothing truthful to continue with — and closing
  it is out of scope here. Tracked as issue #312.
- The ledger distinguishes "helper never ran" from "helper ran, cleanup incomplete"; silence
  could not.
- Private scratch content can survive a run without a human being forced to notice. The stderr
  warning and the ledger record are the compensating disclosure — both private, so no retained
  path reaches a public annotation. The content stays in the mode-0700, git-ignored workspace
  where the old failure path already left it, and it survives only as long as that checkout does —
  a worktree teardown takes it along with the ledger. Removing it sooner is the operator's.
- Ledger readers must match both record kinds. One matching only
  `review-publication-disposed:` sees an incomplete cleanup as no cleanup.
- The exit guard that fails a zero-status run with a surviving body no longer applies to a body
  the undisposed record names; it still guards every unrecorded leak.
- The helper now appends the ledger up to twice after the verified line rather than once, so the
  strand named above has marginally more opportunity to occur. The failure mode is unchanged.

## Considered & rejected

- **Exit 2 for "published, cleanup incomplete", as ADR 0045 does for gates.** verified:
  `skills/quest/SKILL.md` step 8 reads "On nonzero, do not retry, do not post another
  `WORK:REVIEW`, and park the quest with the helper's retained evidence and failure output" — one
  rule over the whole nonzero range, not an exit taxonomy. Judgment: a status only an updated
  caller interprets correctly reintroduces the park for anything not yet updated, and the ledger
  already carries the distinction durably.
- **A fallback disposer chain — on Linux, `gio trash` then trash-cli's `trash-put`.** judgment: a
  second disposer is a new host prerequisite, and this change does not take one on. The issue
  offers a chain as a consideration rather than a requirement, and the condition a chain would
  address — a present disposer refusing one filesystem — is exactly the condition
  report-and-continue now handles. verified: at base commit
  `c939eea39cd279725f0e5156d7ddfea01e17df49`, `rg -n 'trash|gio' scripts/setup.sh --no-config`
  matched nothing, so the repository provisions no disposer at all; a chain would add a second
  unprovisioned prerequisite on top of the one that already exists.
- **Omit the record when disposal fails and warn only.** judgment: this is the reported defect.
  A missing record is indistinguishable from a helper that never ran, which is what makes the
  current park unrecoverable.
- **Dispose before appending the verified line.** judgment: it would claim disposal not yet
  performed, and a crash between the two would leave a verified publication with no record.
- **Stop at the first disposer failure, as today.** judgment: attempting every path costs one
  extra disposer call per remaining path and nothing else, while stopping early strands every path
  after the first odd one for no gain.
