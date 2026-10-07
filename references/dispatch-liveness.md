# Dispatch liveness and silent-worker recovery

Apply this contract whenever a dispatcher waits for a worker report. A missing report is not a
malformed report: keep any caller-specific validation or malformed-return retry separate.

## Probe and hold

**Diagnose from evidence when needed.** A blocker, failure, user request or task-appropriate
deadline can trigger one reconciliation of reports, tracker/branch artifacts and harness state.
Healthy waiting needs no discretionary status reads. An unchanged wait timeout is not a
diagnostic trigger; a deadline permits diagnosis, never replacement by itself.

**Nothing derived from a timestamp distinguishes alive from ended.** Commit age, elapsed time,
tracker inactivity, and a missing artifact narrow which waits are worth a second look and do
nothing else. None of them authorizes replacement, and a run that has started treating the commit
stream as its liveness signal has already left this contract.

**One probe per worker per run.** When diagnosing unexpected silence of roughly ten minutes,
a dispatcher may send the worker one direct, non-destructive probe, then wait through the next
normal collection point — no more than roughly ten further minutes — for the reply. A reply of any content proves the worker
alive. No reply proves nothing, and it ends the probe budget: the wait becomes a hold.

**A report proves the worker was alive when it wrote the report, and nothing more.** Its content is
evidence about the moment of composition, not about the present the dispatcher reads it in — a
park report from a resumed worker can be stale rather than current, describing state the worker has
since moved past. On conflict, the verified branch head, tracker label state, and the harness's own
agent run-state outrank the report's content; a plausible, detailed, or even byte-identical report
is not grounds to override them. This governs a reply to the probe above and every other worker
report a dispatcher reads.

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

1. **Record the handoff.** In the owning workflow's existing record, retain the worker, expected
   compact report/artifacts, wait site, task-appropriate deadline and recovery-chain budgets.
2. **Do useful independent work.** Dispatch through the available interface, then drain eligible
   work. Serial ordering means awaiting the required result before advancing dependent work;
   it does not require a blocking-dispatch field.
3. **Await the needed event.** Prefer native completion notification or the exposed bounded wait.
   A supported foreground dispatch also works when its result is needed immediately. Select
   intervals within the actual schema and higher-priority progress requirements. With nothing
   else eligible, say what is pending and wait; do not manufacture status reads.
4. **Continue an unchanged wait.** A timeout with no new event leaves the same worker pending.
   Re-enter the supported wait without extra diagnostics. Required progress messages use known
   evidence. Count such turns separately; notification, timeout and progress costs depend on
   the harness. Neither a waiting indicator nor elapsed time establishes token usage.
5. **Reconcile once, then act.** On the needed event or diagnostic trigger above, validate the
   report and relevant artifacts, update the existing record, and advance or diagnose. Report
   receipt, task success and observed end are separate facts; apply the recovery rules below.

Check the active schema rather than copying a flag from another harness:

- **Codex native agents:** the observed `collaboration.spawn_agent` is asynchronous with no
  blocking field. Keep its identity and use `collaboration.wait_agent(timeout_ms: 60000)` when
  that interval fits the active instructions; consume mailbox updates and final notifications.
  A mailbox wake may be a message rather than an end. Other surfaces may expose different tools.
- **Claude Code native agents:** when `Agent` exposes `run_in_background`, `false` requests
  foreground execution; background agents notify on completion. Some modes omit that field.
  Use the exposed notification/wait path, never an invented `background: false` argument.
- **CLI workers:** `codex exec` or `claude -p` is a subprocess. Await its original process handle
  and collect its exit/report. A completed process exit observes that process's end, not the
  end of independently backgrounded workers. A yielded handle or timeout proves neither.
- **A worker's inner tool wait:** retain the long command's handle and await that invocation.
  A coordinator wait/progress turn does not restart the command or imply the worker can reply.

These examples were checked against the [bounded capability evidence](../docs/benchmarks/positive-monitoring-344.md).
Unsupported notification, wait or usage capabilities must be stated, not assumed.

For a wait on durable state rather than a worker report, use **one** bounded background shell
operation for the whole condition wait, then read its result. Never foreground sleep-and-check
polling. This avoids discretionary model checks, not a promise of zero model turns or tokens.

Use the Bash 3.2 `bounded_call` function from [network bounds](network-bounds.md#the-mechanism)
in that background task; it needs no `timeout` or `gtimeout` command. Define that function first,
then run:

```bash
# One background task for the whole wait. Not one per check.
wait_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$wait_dir"' EXIT
rc=0
bounded_call 3600 "$wait_dir/out" "$wait_dir/err" \
  bash -c 'until <condition>; do sleep 60; done' || rc=$?
cat "$wait_dir/out"
cat "$wait_dir/err" >&2
printf 'wait ended: %s\n' "$rc"
exit "$rc"
```

The `sleep` runs inside the shell operation. Set the outer bound to the longest the wait
could legitimately take, so the read returns a result rather than a reason to open another wait.
The bound covers the whole child shell, including a condition that does not return; checking a
deadline only between condition attempts would not. A nonzero condition status means pending in
this `until` loop; make an unrecoverable condition error explicitly exit the child shell to return
that status. The canonical pattern's timeout-status collision and process-cleanup limitations
still apply. The bound reaps the child shell but may leave external condition subprocesses
running; timeout proves neither their termination nor worker death.

While a wait is open, drain other work in hand. When the outstanding reports are the only work
left, say plainly what is blocked and on what, and then wait — never manufacture polls to look
busy.

## Observed end and reconciliation

For a native agent, only the harness's end-of-run notification, or a dispatcher-requested stop
followed by that notification, proves the worker ended. For a CLI worker, require the completed
process exit described above. Before replacement, enumerate the durable evidence the
dispatcher can reach: reports, tracker state, branch or commit state, and worktree changes. Record
the disposition of each artifact, establish ownership, resolve conflicts or inaccessible required
evidence, and check once more for a late valid report.

For campaign claim recovery, establish ownership by the holder's exact scope token in the
campaign's pre-dispatch row/worker binding. The observed end must belong to that bound worker;
a shared login or campaign-shaped public provenance is not attribution. Unknown or missing
bindings are foreign holds, reported with token, producer, age and matching WORK:SCOPE
provenance. An authorized forced recovery names the observed holder with `--expect-token`;
a changed holder refuses at the next read. This does not make GitHub read/delete atomic.

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
