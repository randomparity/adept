# Poll-cost determination (#406)

## Problem

Measure the polling cost before optimizing. The loop checks liveness before its first
`sleep 0.1`: an already-reaped command can skip that tick. The reported “at least
100 ms per successful call” is not a universal guarantee.

## Scope

Add the measured result and acceptability judgment to `references/network-bounds.md`;
bump the plugin to 5.14.9. Retain canonical code, appliers, bounds and eight properties.
The reference remains the owner; no migration, obsolete path or ADR is required.
Bash 3.2 is the floor; no dependency, runtime surface or benchmark infrastructure is added.
Excluded: poll schedule changes (future measured optimization), widening bounds (bounds
contract), Bash compatibility changes (repository owner), status/race semantics (#403/#405).

### Failure model

- Actors and deployments: maintainers reading the reference; existing Bash 3.2 network
  appliers; timing measurement only on macOS arm64/BSD.
- Invariants and assets: truthful performance evidence; unchanged bounding contracts.
- Accepted classes: scheduling/host variation and unmeasured network workloads; accepted
  because #406 permits a measured-acceptable determination, explicitly limited below.
- Covered elsewhere: deadline inexactness and all eight properties — existing reference;
  schedule optimization — future measured work; status/race semantics — #403/#405.

## Success

Record the measured overhead as acceptable for the existing portable bounded CLI network
mechanism, as a judgment about modest absolute cost, not a workload latency guarantee.
At base `2a989ec265643aafc526a3a72842f554ce57df8e`, 30 paired trials on Bash 3.2.57
used the unchanged canonical function with bound 30. Each arm ran the same fast Bash
`printf` child, separate private capture files, and `cat` readback; both parsed the same
function and included parent-shell startup, child launch, capture and readback. Alternate
bounded/unbounded order; exclude file allocation. Every arm returned 0 with the expected
complete stdout and empty stderr. No network requests were measured.

Mean bounded/unbounded times: 132.35/26.19 ms. Paired added mean: 106.16 ms;
median 106.60 ms, range 91.83–128.10 ms. Total experiment: 4.76 seconds.
Six times the paired mean is a synthetic 0.637-second estimate, not a measured telemetry
run. This absolute cost is acceptable for the existing 30/120-second bounded network-call
convention; retaining its uniform portable polling is preferable to unmeasured optimization.
No conclusion about production network latency, other hosts or a per-call minimum follows.

## Validation

One documentary unit. `task-test-not-applicable`: accuracy of prose and the acceptability
judgment require reading; sentence-pinning tests violate repository anatomy rule 4.
Review the recorded arithmetic and scope, compare the canonical block byte-for-byte with
base, and run existing shape/version/commit guards. The managed pre-push full candidate
gate and Ubuntu/macOS CI own final coverage; do not duplicate the full local run.
