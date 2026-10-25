# Unchanged waits and empty process collections — #466

The bounded run observed unchanged native timeouts and empty process results, but failed parts
of its progress and collection-budget protocol. It supports **no guidance change or savings
claim**. Three of four approved workloads ran; the fourth was stopped before initiation.
The within-harness process-strategy comparison is incomplete. Failed attempts remain evidence.

## Frozen workload and authority

Measured 2026-10-25; [design](../workflow/specs/2026-10-25-unchanged-waits-design.md) committed as
`2694f06` before execution. Frozen spec SHA-256:
`e72325ff55ce310281237ce8f65241249d9ae1295357d065460f3019c2a8edc9`.
[Operator-approved scope](https://github.com/randomparity/adept/issues/466#issuecomment-6398075582)
selected four serial N=1 arms: fresh native workers N10/N50, then subprocesses P10/P50.
Each runs exactly `sleep 75; printf 'WAIT466-DONE\n'`, quiet until its fixed marker.
N10/P10 request 10-second collection waits; N50/P50 permit up to 50 seconds, shortened to
preserve progress before 60 seconds. Two experiment dispatches, one experiment worker slot,
four workloads maximum; at most 12 collections and 180 observation seconds per arm, 720 total,
no retries. This finite invocation budget is **not a hard dollar cap**.

The protocol counts wrapper collections as work too. N50 exceeded the conservative total when
its worker repeatedly collected an outer execution cell as well as the inner process. The
coordinator recognized that overrun **before starting P10** at 13:22:16.594 UTC. Starting P10
violated the original stop-at-any-limit rule, independently of the later hold. The operator's
coordinator explicitly stopped further initiation without a budget extension; that hold was
recorded at 13:22:59.820 UTC. Only P10's original handle was then reconciled, with exit collected
at 13:23:35.073 UTC. P50 remains unrun. No replacement, probe, status read or workload retry occurred.

## Actual surface and constraints

Current exposed Codex harness only, macOS arm64, Bash 3.2.57; no target architecture declared.
Installed CLI reports `codex-cli 0.164.0`; this does not establish the desktop client's version
(unavailable) or imply that CLI execution was measured. Active installed Adept manifest is
**7.11.0**, distinct from target base **7.11.3** and this report's release **7.11.4**.
Shared-reference git blob `e7aca6a1d5637a8a5d583454ca75acd3c816ef12` was unchanged.
The operation packet requested `gpt-6.1-sol`, low/default. Both fresh native experiment dispatches
accepted explicit `gpt-6.1-sol` / `low`; actual backend model and coordinator-native settings
were not independently exposed. No configuration was changed for measurement.

Exposed `collaboration.wait_agent` accepts 10,000–3,600,000 ms and returns a timeout or mailbox
summary; `spawn_agent` is asynchronous. Higher-priority instructions require progress before
60 seconds and forbid blocking waits longer than 60 seconds. Accordingly N50's actual coordinator
intervals were 40/40/10 seconds, not a 50-second promise. `exec_command` exposes initial
`yield_time_ms` 250–30,000 ms and returns an original session handle when running;
`write_stdin` accepts empty input and explicit collection waits (default empty-poll range
5,000–300,000 ms). The outer `functions.exec` can yield a separate cell, collected by
`functions.wait`; these are additional observable tool results, not free background execution.

## Observed results

| Arm | Coordinator wait/collection results | Process observations | Progress / outcome |
| --- | --- | --- | --- |
| N10 | 7 native waits, 7 unchanged timeouts; final notification arrived separately | 1 initial result + 2 original-handle collections; 2 empty outputs; marker, exit 0; 75.061 s worker observation | Coordinator 1 update, timing uncertified; worker 1 update at about 64 s, **missed** 60 s |
| N50 | 3 native waits, 2 unchanged timeouts, 1 mailbox wake with final notification | 1 initial result + 2 original-handle collections; 2 empty outputs; marker, exit 0; 75.070 s worker observation | Coordinator 1 update, timing uncertified; worker 1 update between 36.813–46.144 s; collection cap exceeded |
| P10 | 4 original-handle collections: 3 empty, then marker/exit 0 | Initial result also empty; terminal result collected 78.479 s after invocation | 1 coordinator update at 78.467 s, **missed** 60 s; reconciled after hold |
| P50 | Unrun | No process initiated | Stopped by collection-budget hold; no extension |

Native worker final reports retain two outer-cell collection calls for N10 and nine for N50.
Thus collections across coordinator native waits, inner process collections and outer-cell waits
were **11 for N10** (7+2+2) and **14 for N50** (3+2+9), against 12 per arm. Initial launches are
listed separately, not subtracted from that overrun. N50's outer layer produced three running
execution-cell yields and nine wait results; the inner process still had only two collections.
N10's first long collection yielded an outer cell and needed two collections of that cell.
Do not add inner and outer result counts and call the sum an inference count.

Conservative bookkeeping windows from pre-dispatch/pre-invocation to retained-result capture
were 129.293 s N10, 140.704 s N50 and 78.479 s P10 (348.476 s total, below 720). Native windows
include dispatch/model/report and post-completion capture overhead; exact notification latency
is unavailable. These are not subprocess runtime estimates. P10's hold arrived 43.226 s after
invocation. Its requested 10-second waits did not establish a 10-second collection cadence:
model/inter-tool gaps also consumed time. No arm was retried to repair a failed observation.

The three coordinator updates and two worker updates were instruction-required progress messages,
not host-generated heartbeat wakes. Actual returns were native wait timeouts, a mailbox completion
wake, outer execution-cell yields/collections and process results. No passive host progress wake
was observed. A timer expiring does not create evidence of life or end. Two native final
notifications observed those runs' ends; the three process exits observed only those processes'
ends. Original identities were retained privately; no outstanding measured handle remains.

## Comparison, unavailable counters and limits

N10 returned seven unchanged native timeouts; N50 returned two. That is an observable wait-result
comparison under different requested intervals, N=1 scheduling and the disclosed failures.
It does not establish equal worker overhead, inference calls, tokens, cost, or reliability.
P10 proves empty intermediate process collections; P50 is unrun, so no process-strategy comparison
or longer-poll benefit is established. Progress timing failed in N10's worker and P10; coordinator
native timing was not independently captured. Required progress costs therefore cannot be
completely attributed from these observations.

API/inference counts, root/coordinator-only input/cache/output tokens, billing and cache attribution
are **unavailable, not zero**. Tool-return counts are not inference counts. No usage or savings
extrapolation follows from waiting indicators, elapsed time, fewer collections or silence.
The missing provider capability is a documented passive completion/required-progress mechanism
that avoids model re-entry while satisfying operator updates, together with attributable usage
counters if cost is to be measured. This run establishes neither its availability nor its cost.

[Waiting #344](positive-monitoring-344.md) and [consolidation #347](orchestration-validation-347.md)
remain compatible completed dispatch/refill evidence and were reused without reruns. Claude,
credentialed CLI/native arms, passive heartbeat and blocking beyond 60 seconds remain unrun under
the explicit capability/budget boundary. Routing #354, timing #161, benchmark #117 and new
telemetry/daemon/scheduler/hook infrastructure remain excluded. No consumer conflict was proven,
so shared guidance and its ownership, claim/recovery budgets, serial dependencies and end/report
semantics remain unchanged. Normal design/review, guardrail and CI work is outside experiment time.

Private protocol, raw tool responses, original handles, timestamps and failed final reports are
retained with the owning run. Public evidence omits host/session/account identifiers. No runner
ships. A future complete comparison requires fresh explicit authority; this failed bounded run
must not silently reset the exhausted per-arm collection budget.
