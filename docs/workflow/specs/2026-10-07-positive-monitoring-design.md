# Positive monitoring for native agents and CLI workers

Issue #344; frozen scope `q344-322d7c14`; parent #343.
Decision: [ADR 0086](../../adr/0086-capability-based-positive-waiting.md).

## Problem and scope

The shared waiting reference assumes zero-turn waits and asks for cheap status reads.
Forge requires a blocking dispatch flag; campaign repeats that requirement and unsupported
cost claims. The current Codex native surface exposes asynchronous spawn and a separate
mailbox wait. Claude Code's available dispatch fields depend on session configuration.

Keep the shared reference as the sole waiting/recovery owner. Replace conflicting forge
and campaign instructions with capability-based serial waiting and event-triggered
reconciliation, including the dispatch wait clauses in forge's implementer and reviewer
templates. Read both loaded templates in the consumer walkthrough. Preserve campaign waves here: #346 owns refill and #347 consolidation.
No new runtime, hook, ledger, reviewer isolation, merge handshake or removed swarm work.

## Procedure and interfaces

1. Record the worker identity, expected compact report/artifacts, wait site, appropriate
   deadline and existing chain/probe/replacement state in the workflow's existing record.
2. Dispatch through the exposed native tool or CLI process interface. Do useful independent
   work, without advancing a dependent unit before its required result.
3. Await the needed report/completion event using the supported mechanism. Prefer native
   notification or a bounded native wait; use a supported foreground dispatch when suitable.
   A CLI subprocess uses its process-completion handle, not the native-agent mailbox.
4. An unchanged wait timeout keeps the same wait pending. Required progress updates use
   known evidence. Neither causes discretionary status reads, probes or replacements.
5. On a completion, blocker, failure, user request or task-appropriate deadline, reconcile
   the needed evidence once and advance eligible work or diagnose under existing budgets.
   Deadline expiry proves no end. A report and process exit prove different facts; validate
   the report and require the appropriate harness-observed end before recovery/cleanup.

The shared reference retains its one-probe, observed-end, late-report, exact-token ownership
and one-replacement clauses. Update only their waiting entry conditions where they contradict
C3. Native tool names are examples tied to an observed surface, not portable API promises.
A worker's own long tool call retains its original handle and is not a reason to restart it.

## Failure model

- Actors and deployments: authorized local coordinators on the observed Codex native surface,
  Codex CLI and Claude Code CLI/native subagents; existing forge/campaign consumers.
- Invariants/assets: worker ownership, dependent ordering, retry budgets, correct completion,
  local artifacts and public-safe tracker state. Silence cannot authorize duplicate work.
- Accepted failure classes: service drift and unavailable telemetry are reported; one run is
  not a reliability estimate. Unavailable required live arms block completion. Other harness
  versions require checking their actual schema; no universal blocking/zero-turn guarantee.
- Rejected classes: discretionary healthy polling, timeout-as-death, stale-report takeover,
  restarting an active tool call, invented capability or savings claims, privacy leakage.

## Success and AI evaluation

AI-SPEC: workflow operators trigger this procedure after authorized dispatch. Inputs are actual
harness schemas, the expected handoff and current workflow authority; outputs are a valid wait,
reconciled result or bounded diagnosis. Sources are these instructions, tool observations and
current official vendor guidance. No inferred termination, new ownership or retry authority.
Fallback is a recorded pending wait/hold with unsupported capabilities named. Each measured
session has a 300-second wall budget, two sequential workers and one occupied worker slot.
Success is observable tool/trace behavior and retained outcomes, not a model's self-score.

Freeze the following set and accounting before baseline measurement; private protocol hash
`86d188c1d0f6239c7dd7ee6f2b04dffbd82f9ce7` precedes guidance edits.

| Case | Setup and observable pass traits | Evidence/gate |
| --- | --- | --- |
| H | One worker waits 12 seconds in one shell call then H-DONE; coordinator computes 17+25 while eligible, then awaits; no discretionary status read/probe | Live both harnesses; block |
| B | Next worker reports missing authorized input; diagnose without replacement or invented permission | Live both harnesses; block |
| D | Deadline expires without end evidence; retain ownership and existing probe budget | Constructed reader walkthrough; block |
| U | Native wait returns unchanged; re-enter pending wait without diagnostics | Live if exposed naturally, otherwise explicit constructed case; block |
| L | Late/stale report conflicts with verified head/tracker/run-state; reconcile and never infer takeover | Constructed reader walkthrough; block |

H covers completion/tool correctness and expensive-loop failure (severity 4). B/D cover
ambiguous input, authority and privacy boundaries (severity 5). U is the repeated-wake regression
(severity 4). L covers stale/conflicting evidence and forbidden recovery (severity 5).
No fixtures contain private identities. Deadline/late races are not claimed as live GitHub proof.

## Validation and rollout

Run one baseline and one changed coordinator session per harness with identical workload,
model/effort configuration and permissions where controllable. Freeze prompts and guidance hashes;
retain failed runs, actual tool schema limitations and service/model drift. At most one diagnosed
configuration/auth alternate per failed arm; no unbounded retries. Preflight may perform one
no-tool authentication/capability call per harness, which is not dispatch proof.

Measure observed coordinator assistant messages and API turns separately where exposed, causes
(dispatch/useful work/wait/progress/timeout/completion/diagnosis), discretionary status reads,
probes, replacements, task outcomes, elapsed monotonic time and raw available usage fields.
Unavailable usage stays unavailable; worker breakdown is reported only if exposed. An independent
reader examines traces and cases; self-reported scores are not the proof. No savings percentage.
Publish compact sanitized evidence and rerun inputs under `docs/benchmarks/` for #346/#347.

Waiting behavior uses `task-test-not-applicable`: these are model instructions without a parser;
a prose assertion cannot prove that a coordinator waited correctly. Live traces and independent
reader cases supply behavioral evidence. Existing skill shape, manifest, record and public-safety
gates cover structure. Run `just commit-check`, focused shape/version suites and base-aware
version/record checks. Managed pre-push owns the final full local gate; CI runs independently.
Bump `.claude-plugin/plugin.json` to assigned 7.9.0. Revert the instruction change to roll back;
no persisted schema or artifact migration is introduced.
