# Boundary capture determination (#405)

## Problem

The reported lead says a completed but unreaped child can select escalation and lose a
complete capture. The unchanged loop actually evaluates `kill -0` before its counter test,
and the following `if` checks liveness again. A determination, rather than a speculative
algorithm change, is the issue's first requirement and permitted negative outcome.

## Scope and decision

Record the boundary measurement in `references/network-bounds.md` beside the mechanism.
Retain the canonical code block and existing appliers. No behavior defect was reproduced,
so no implementation or fixture change is justified. No ownership transition, caller
migration, obsolete path removal, new interface, or architectural decision is required.
No ADR is warranted; assigned reservation 0074 is unused.

## Measurement

At base `c04ff31c4cbb7ba392119758fdf994f48c59c0a9`, extract the canonical Bash
code block unchanged and run `bounded_call 1` with a Bash child that sleeps, writes
`complete-answer` to stdout, then writes a completion sidecar and exits normally.
The private wrapper captures status without masking it. Compare the complete expected
stdout with actual capture; also record timeout emptiness and sidecar presence.
The sidecar proves execution reached the write, not that the process exited before
any particular liveness checkpoint. It is not independent proof of completed-process loss.

Bash 3.2.57, macOS arm64/BSD; ten trials per delay; total elapsed 66.78 seconds:

| Child sleep seconds | Complete capture, status 0 | Empty capture, status 124 |
|---|---:|---:|
| 0.95 | 10 | 0 |
| 1.00 | 10 | 0 |
| 1.03 | 10 | 0 |
| 1.06 | 3 | 7 |
| 1.09 | 5 | 5 |
| 1.12 | 0 | 10 |

No timeout had the completion sidecar; no unexpected result occurred. These 60 observations
support non-reproduction on the measured host, not a guarantee for other schedules or hosts.
GNU Bash 3.2 `jobs.c` has `sigchld_handler` call nonblocking `waitchld`, which reaps
children and saves their status; explicit `wait` is not the only reaping opportunity.
Source: [GNU Bash 3.2 archive](https://ftp.gnu.org/gnu/bash/bash-3.2.tar.gz), `jobs.c`.
This explains why a child is not necessarily an unreaped zombie until the wrapper waits;
it does not make separate liveness and signal operations atomic.

## Success

The reference identifies the repeated liveness checks, the measured boundary determination,
and its finite-observation limits. It does not assert universal race freedom, classify a
sidecar as proof of process exit, or change capture refusal and emitted exit classes.
Plugin metadata advances to 5.14.8. The canonical function stays byte-identical to the base.

## Global Constraints

Bash 3.2 is the floor. Preserve the existing bounds, escalation, capture refusal, and
caller classification contracts. Do not add dependencies or executable surfaces.
Retry/backoff, widening bounds, poll optimization (#406), and return collision (#403)
remain excluded under the operator's approved exclusion/owner set.

## Failure model

- Actors and deployments: maintainers reading the canonical reference; existing Bash 3.2
  appliers; measurement only on the recorded macOS arm64 host.
- Invariants and assets at stake: truthful determination; complete-answer preservation;
  refusal of truncated stdout; no stronger guarantee than the observations support.
- Accepted failure classes: finite trials can miss a rare timing window; accepted because
  #405 permits a measured non-reproduction outcome and the reference states this limitation.
- Covered elsewhere: PID reuse and non-exact bounds — existing reference; return-status
  collision — #403; polling optimization — #406; shipped behavior — existing suites.

## Validation

One documentary task: manually compare the reference statements with the source, trial
counts, and GNU source; compare the canonical code block with the base byte-for-byte.
`task-test-not-applicable`: prose accuracy is a reading contract; sentence-pinning tests
violate repository anatomy rule 4. The measurement is evidence, not a new shipped test.
Run relevant structural/version checks and the managed pre-push full candidate gate;
require independent review plus Ubuntu and macOS CI. Do not duplicate the full local gate.
