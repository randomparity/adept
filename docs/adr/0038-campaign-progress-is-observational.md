# 0038 — Campaign progress is observational

## Status

Accepted (2026-08-27)

## Context

Campaigns deliberately keep dispatch, review, CI, and merge checkpoints inside one continuous
task. Long blocking operations can therefore leave the operator without a current account of the
active row even though the campaign is healthy. The campaign already has durable state in its
manifest and tracker; progress communication must not become another state store or a reason to
poll workers.

## Decision

The campaign orchestrator emits concise progress updates after the plan, after each worker
completion or merge, and immediately before a potentially long wait. An update is observational:
it reports only facts read from the manifest, tracker, worker report, or verified GitHub state and
does not mutate campaign state, redispatch work, or end the continuous task.

Each update names the current issue or wave and phase, branch or PR when known, last verified
signal, completed guardrails, and the next awaited event. Unknown fields remain explicitly
unknown or omitted; they are never inferred from elapsed time or silence.

## Consequences

Operators can distinguish a healthy long-running campaign from an unexplained stall without
additional polling. The orchestrator has a small communication obligation at durable boundaries,
but the manifest and tracker remain the only resumable state and existing liveness rules remain
unchanged.

## Considered & rejected

- **Persist progress messages in the campaign manifest.** judgment: this duplicates facts already
  owned by the manifest rows and tracker and turns communication into a new state transition.
- **Emit updates on a timer.** verified: issue #263 requires preserving the campaign's prohibition
  on timer polling and speculative liveness inference.
- **Report only when the operator asks.** judgment: this leaves blocking serial waits silent, which
  is the behavior the decision exists to change.

