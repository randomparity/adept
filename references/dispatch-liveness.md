# Dispatch liveness and silent-worker recovery

Apply this contract whenever a dispatcher waits for a worker report. A missing report is not a
malformed report: keep any caller-specific validation or malformed-return retry separate.

## Probe and hold

**Ask the cheap question first.** Tracker state, a pushed branch, a file the worker writes — these
answer "has it moved?" for the price of a shell command, not a dispatcher turn. Ask them from a
background task, not from the model.

**Nothing derived from a timestamp distinguishes alive from ended.** Commit age, elapsed time,
tracker inactivity, and a missing artifact narrow which waits are worth a second look and do
nothing else. None of them authorizes replacement, and a run that has started treating the commit
stream as its liveness signal has already left this contract.

**One probe per worker per run.** After roughly ten minutes of silence a dispatcher may send the
worker one direct, non-destructive probe, then wait through the next normal collection point — no
more than roughly ten further minutes — for the reply. A reply of any content proves the worker
alive. No reply proves nothing, and it ends the probe budget: the wait becomes a hold.

**A second probe to the same worker is the failure this budget exists to prevent.** It buys the
same non-answer at the price of a full dispatcher turn, because a worker inside a long tool call
answers at its next turn boundary and not on demand — so the probe is least informative for
exactly the workers a dispatcher worries about. Silence that has already cost its probe is a
recorded hold, not an open question to keep asking.

The dispatcher that created the wait owns a silent chain for the rest of the run. It records the
hold in the workflow's existing run report or ledger and may drain unrelated work. A later valid
report completes the held wait. A later harness end-of-run notification continues that same chain
at reconciliation with the same replacement budget.

## Waiting mechanics

**Never wait by foreground sleep polling.** Every wake of a sleep-and-check loop replays the
dispatcher's full context — skill text, run history and all — through the model, so an hour of
five-minute sleeps costs more than the report it waits for. A wait must cost zero model turns
until it ends.

Two mechanisms cost zero. Prefer the harness's completion notification. Where the workflow waits
on durable state rather than on a report — a tracker row, a pull request, a pushed branch — put
the entire wait in **one** background shell task that blocks until the condition holds or its own
deadline expires, and read it once when it returns:

```bash
# One background task for the whole wait. Not one per check.
timeout 3600 bash -c 'until <condition>; do sleep 60; done'; echo "wait ended: $?"
```

The `sleep` runs in the shell, where it is free. Set the outer `timeout` to the longest the wait
could legitimately take, so the read returns a result rather than a reason to open another wait.

While a wait is open, drain other work in hand. When the outstanding reports are the only work
left, say plainly what is blocked and on what, and then wait — never manufacture polls to look
busy.

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
