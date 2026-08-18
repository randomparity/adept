# Dispatch liveness and silent-worker recovery

Apply this contract whenever a dispatcher waits for a worker report. A missing report is not a
malformed report: keep any caller-specific validation or malformed-return retry separate.

## Probe and hold

Allow roughly ten minutes of silence before sending the worker a direct, non-destructive probe.
Wait through the next normal collection point, no more than roughly ten further minutes, for the
reply. A reply of any content proves the worker is alive. No reply does not prove it ended, and
elapsed time, commit age, tracker inactivity, or a missing artifact never authorizes replacement.

The dispatcher that created the wait owns a silent chain for the rest of the run. It records the
hold in the workflow's existing run report or ledger and may drain unrelated work. A later valid
report completes the held wait. A later harness end-of-run notification continues that same chain
at reconciliation with the same replacement budget.

## Waiting mechanics

Wait through the harness: a completion notification, or a single background task read when it
returns. Never wait by foreground sleep polling — every wake of a sleep-and-check loop replays the
dispatcher's full context through the model, so an hour of five-minute sleeps costs more than the
report it waits for. While a wait is open, drain other work in hand; when the outstanding reports
are the only work left, say plainly what is blocked and on what, and wait through the harness
rather than manufacturing polls to look busy.

## Observed end and reconciliation

Only the harness's end-of-run notification, or a dispatcher-requested stop followed by that
notification, proves the worker ended. Before replacement, enumerate the durable evidence the
dispatcher can reach: reports, tracker state, branch or commit state, and worktree changes. Record
the disposition of each artifact, establish ownership, resolve conflicts or inaccessible required
evidence, and check once more for a late valid report.

A late valid report cancels recovery. An unresolved conflict, inaccessible required artifact, or
uncertain ownership stops the work unit with the unresolved state recorded; it authorizes no
replacement and no worktree reclamation.

## One replacement

Give the original worker and its possible replacement one recovery-chain identifier. In the
existing run report or ledger, record whether that chain's replacement authorization is `unused`
or `consumed`; the current dispatcher reads it immediately before dispatch. A successfully
reconciled, harness-observed end may consume the authorization once. A silent replacement does not
receive another replacement.

If a valid report arrives after replacement dispatch, record the race. Stop the replacement before
its next mutation when the harness permits, then reconcile both result sets. If the stop is
unsupported or late, disposition both result sets under the same fail-closed rule. Authorize no
further dispatch. Escalate an irreconcilable conflict through the owning workflow's existing run
report or parked state; never choose a winner implicitly.

## Required record

Record the worker identity, wait site, probe and observation results, hold or recovery outcome,
artifact dispositions, recovery-chain identifier, and replacement-budget state. Use the owning
workflow's existing report or ledger. Do not add a tracker or persistence write where that
workflow has none.
