# Bounded orchestration validation — #347

The requested live waiting, blocker and two-slot refill cases are covered in both harnesses,
within the observation limits below. This report reconciles the eight retained baseline/changed
arms from [waiting #344](positive-monitoring-344.md) and [campaign refill #346](campaign-refill-346.md).
No missing planned live case was identified, so #347 ran no additional measurement arm.
This is scratch-workload regression evidence, not a savings estimate or full campaign proof.
The [design](../workflow/specs/2026-10-07-orchestration-validation-design.md) bounds publication;
#117's separate benchmark and #161's review economics are not evaluated here.

## Frozen inputs and provenance

The operator selected both harnesses and approved reuse after the behavior changes landed.
The original protocols, prompts, stdout/stderr, metadata and per-job artifacts were reconciled
privately; the original scenario set and failed/deviating observations were not rewritten.
Measured 2026-10-07 on macOS arm64, Bash 3.2, Python 3.9.6 for refill; no project target declared.

| Evidence | Baseline guidance commit | Changed guidance commit |
| --- | --- | --- |
| Waiting, PR #455 | `6fd166788ac545552681633587c8f26151cbdd64` | `ec04e90c1bbe8f9947de6cea39e0c0ad2ccaacde` |
| Refill, PR #456 | `e784c01fbba9e79029aa0b37fda2b0c8dfd6d9fe` | `23921733273401c88a2a49597ac7bfae96163cc7` |

Guidance was injected into prompts, not installed as an update. Refill snapshots match those
commits exactly. Waiting's measured changed reference differs from the final commit only in
line wrapping of the one-probe paragraph; its serial forge excerpt matches. Its exact reference
SHA-256 is `64b4f0f6e5c3c3396e5165f7614449d000b55398f4d7605bb1c07ce99ee5d2cd`.
Waiting protocol git-blob hash is `86d188c1d0f6239c7dd7ee6f2b04dffbd82f9ce7`;
SHA-256 is `151d3981208594140ef2b0dee9ae41396a5a954998391ceaf74c166ce7e51ac5`.
Refill protocol SHA-256 is `9dfd5bafcf4d0020efcb4ca8fd67739e23a3197c58b553a7060bdf43a51d997a`.
Exact prompt hashes agree with capture metadata; detailed source reports retain further hashes.

Codex CLI 0.160.1 used configured `gpt-6-astra`, medium reasoning, read-only sandbox for waiting
and workspace-write for refill. Its JSONL does not establish the installed Adept revision.
Claude Code 2.1.292 resolved `claude-opus-5-5`, default effort unexposed, `dontAsk`, strict MCP
configuration and allowed `Agent` plus the exact worker command. Init events show installed
Adept **7.5.0** throughout; the supplied changed guidance is a separate input. Existing settings
and hooks remained active. This does not verify plugin installation or a deployed update.

## Live cases and within-harness comparison

Waiting used H: one `sleep 12` then `H-DONE`, useful coordinator arithmetic 17+25, and B: an
immediate `BLOCKED: missing authorized input` report with no work. Two sequential fresh workers,
one occupied worker slot, one baseline and one changed invocation per harness, 300-second bound.
Refill queued independent A/B/C jobs (60/2/2 seconds), each in a fresh native worker, with two
worker slots plus coordinator, exclusive start/end artifacts and a 240-second CLI bound per arm.
Four initial refill invocations were allowed, no automatic retry; Claude also had max-turns 30.
Codex had no exposed coordinator token ceiling. Authentication preflights are outside these arms.

| Harness / workload | Baseline seconds | Changed seconds | Baseline / changed coordinator items |
| --- | --- | --- | --- |
| Codex waiting | 50.907 | 65.760 | 4 / 4 text items; 2 / 2 native waits |
| Claude waiting | 57.977 | 73.648 | 5 / 5 distinct message IDs; 2 / 2 Agent calls |
| Codex refill | 97.685 | 85.093 | 7 / 7 text items; 3 / 3 native waits |
| Claude refill | 79.900 | 83.764 | 6 / 6 distinct message IDs; 3 / 3 Agent calls |

All eight CLI exits were observed at zero, one attempt each; no measured invocation failed or
retried. Waiting returned H's completion and B's blocker in all four arms without replacement.
Claude traces expose H's one Bash call and completed native workers. Codex exposes native waits
and coordinator receipt reports; its spawn and inner-worker traces are unavailable.

| Refill arm | B job ends | C job starts | A job ends | C starts during A |
| --- | --- | --- | --- | --- |
| Codex baseline | 5.789 | 70.430 | 60.008 | No |
| Codex changed | 6.275 | 17.012 | 60.006 | Yes |
| Claude baseline | 4.382 | 14.162 | 60.010 | Yes |
| Claude changed | 5.075 | 22.337 | 60.002 | Yes |

Seconds are relative to A's start, recomputed from common-host `wall_ns` artifacts. Each arm
has exactly one start/end pair per A/B/C and maximum observed job overlap two. Changed arms
start C after B at the next observed completion-handling opportunity, while A's job remains
active. They start A/B/C and finish B/C/A; Codex baseline finishes B/A/C. Claude exposes native
Agent starts, child commands and end notifications. Codex's native lifetime/end reconciliation
is coordinator-reported; job artifacts independently prove job overlap, not native lifetime.

Claude baseline already refilled despite the wave guidance: retain that deviation; it does not
show a throughput improvement. Its A/B prompts also took `TASK-DONE` too literally, although
actual outputs and reports reconciled A-DONE/B-DONE. Changed Claude's A tool exit code remains
unconfirmed; its end artifact and native completion establish completion, not that inner code.

## Accounting and coverage limits

Waiting causes: dispatch/handoff, useful work and yield/wait, H completion and B dispatch,
then blocker diagnosis/final. Claude emits an additional B yield message. Refill causes:
initial dispatch/yield, B completion, next dispatch/wait, next completion/wait and final report;
Codex baseline waits for A before C. Detailed per-harness counts and raw input/cache/output/
reasoning and worker-notification usage are in the two source reports. They were reconciled
against actual streams, including Codex's one serialized turn per arm and Claude result
`num_turns` sequences 2+2+1 (waiting), 3+2+1+1 (refill). These are not API inference-call counts.

No discretionary status-read, liveness-probe or replacement call appears in exposed coordinator
traces. No separate unchanged-timeout or mandatory timed-progress wake appears; dispatch,
yield and completion progress text is already counted above. Hidden Codex child operations and
coordinator-only token attribution remain unavailable. Claude's final `modelUsage` is session-wide;
worker notification counters have different scopes. Do not sum overlapping counters or record
unavailable usage as zero. Service/model/cache state was uncontrolled; exact weights are unknown.
Python 3.9 macOS monotonic timestamps are process-relative and used only for within-job duration;
wall-clock adjustment was not independently monitored. N=1 permits no causal cost/reliability claim.

| Criterion / case | Evidence and boundary |
| --- | --- |
| Versions, inputs, budgets, outcomes and accounting | Reconciled above and in source tables; unexposed installed revision/usage remain unavailable. |
| Healthy idle and blocker handling | #344 live H/B in both conditions/harnesses; bounded native report collection, no exposed discretionary reads. |
| Two slots, three tasks, refill before slow earlier task ends | #346 live A/B/C; both changed job timelines establish refill overlap. Native Codex details remain reported. |
| Deadline, unchanged timeout, late/stale reports | #344 D/U/L constructed walkthroughs; no naturally occurring live timeout, no forced replacement experiment. |
| Dependency/claims/shared scope/reservations/index/resume/merge/cleanup | #346 constructed instruction traces only; no real GitHub claim, merge or recovery proof. |

The frozen live cases have no outstanding failed or unrun arm. Constructed coverage and missing
telemetry remain limits, not silently passed live tests. No experiment measures a full quest,
installation update, general savings percentage or production reliability.

## Rerun and evidence retention

Use trusted private scratch and the frozen H/B/D/U/L or A/B/C inputs above and in the source
reports. Preserve each condition's guidance, worker command, slot cap and deadline; record
current CLI/model/settings/plugin identity separately. Different controllable inputs require a
new protocol and baseline, not an overwrite of these observations. Prompts coach both conditions,
so this is compatibility/regression evidence rather than an unprompted performance comparison.
Use the exact Codex/Claude command forms in the source reports; substitute only private scratch
paths for the Python job and allowed-tool pattern. Keep stdout/stderr separate, retain the
original process handle, enforce its bound and read evidence after its observed exit. Preserve
failed/partial attempts. A missing required planned case must be frozen before measurement.
Private captures include exact prompts, guidance, commands, stream data and job artifacts;
keep host/account/session/process identifiers private. Public readers can audit the published
inputs and aggregate reasoning; raw-trace verification requires authorized private access.
No runner, machine schema or benchmark platform is added by this publication.
