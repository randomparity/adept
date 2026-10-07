# Campaign refill: bounded evidence for #346

Measured 2026-10-07 on macOS arm64, Python 3.9.6; no project target architecture declared.
[Design and cases](../workflow/specs/2026-10-07-campaign-refill-design.md) bound this slice.
Baseline campaign guidance: `e784c01fbba9e79029aa0b37fda2b0c8dfd6d9fe`.
Frozen private protocol SHA-256: `9dfd5bafcf4d0020efcb4ca8fd67739e23a3197c58b553a7060bdf43a51d997a`.
Changed campaign snapshot SHA-256: `28423e12d216bec01f4015d053d846d03551c8f52db8014314eae73dcee052d5`.
Both conditions received full campaign text plus the same shared waiting reference in prompts,
not an installed plugin update. No guidance changed during an arm; no runner ships.

## Protocol and outcomes

Four initial invocations, one per condition/harness, each bounded at 240 seconds, no retry.
Each fresh coordinator receives three approved independent scratch rows A/B/C and two slots.
Each fresh native worker runs one Python command: write its own exclusive start artifact,
sleep A=60 or B/C=2 seconds, write its own end artifact, print its task's DONE result.
The coordinator cannot execute jobs or fabricate artifacts; it reconciles worker reports and
native completion before reuse. The external observer reads evidence after CLI process exit.
No GitHub mutation, repository work or real quest is part of this workload.

Codex 0.160.1 used configured `gpt-6-astra`, medium reasoning, workspace-write sandbox.
Claude Code 2.1.292 resolved `claude-opus-5-5`, default effort unexposed, `dontAsk`,
allowed `Agent` plus the specific Python job command, strict MCP configuration, max-turns 30.
Existing settings/hooks remained active. Authentication and waiting capability evidence from
[#344](positive-monitoring-344.md) was reused; versions were checked again. Service/cache
state was uncontrolled. Coaching and simulated approvals constrain both conditions.

Times below are seconds relative to A's job start, from same-host wall-clock artifacts.
Python 3.9 macOS monotonic values are process-relative, so only within-job durations use them.
Clock adjustment was not independently monitored; timing is bounded local evidence.

| Arm | CLI exit / seconds | B job end | C job start | A job end | Refill during A |
| --- | --- | --- | --- | --- | --- |
| Codex baseline | 0 / 97.685 | 5.789 | 70.430 | 60.008 | No |
| Codex changed | 0 / 85.093 | 6.275 | 17.012 | 60.006 | Yes |
| Claude baseline | 0 / 79.900 | 4.382 | 14.162 | 60.010 | Yes |
| Claude changed | 0 / 83.764 | 5.075 | 22.337 | 60.002 | Yes |

Each arm produced exactly one start/end pair per job; maximum observed job overlap was two.
Changed arms start C at the next observed completion-handling opportunity after B, before A
ends. They preserve A/B/C dispatch order and finish B/C/A. Codex baseline finished B/A/C.
Claude baseline already refilled despite the old wave wording: it is a retained baseline
deviation, not evidence that this change improved Claude throughput. Its A/B worker prompts
also treated TASK-DONE too literally; the jobs still emitted A-DONE/B-DONE and their reports
preserved those outputs. Changed Claude reported A's tool exit code as unconfirmed; its end
artifact and completed native notification establish job completion without inventing that code.
All four CLI exits were observed, no measured invocation failed and no retry occurred.

## Accounting and limits

| Arm | Available coordinator trace | Explicit waits | Native dispatch trace |
| --- | --- | --- | --- |
| Codex baseline / changed | 7 text items each, 1 serialized turn each | 3 each | Spawn/child events unavailable |
| Claude baseline / changed | 6 distinct message IDs each; result num_turns 3+2+1+1 | Notification yields | 3 Agent calls and 3 child Bash calls each |

Codex message causes are initial dispatch, initial wait, B completion, next dispatch/wait,
next completion/wait, final completion and final report. Claude causes are initial dispatch,
initial yield, B completion/refill, yield, C completion/wait, A completion/final. No separate
unchanged-timeout or mandatory timed-progress wake is visible. Serialized turns/message IDs
are not API inference-call counts. Claude exposes native completion notifications and job
commands; Codex's native end/dispatch sequence remains coordinator-reported. Its actual job
artifacts independently establish overlap, not native agent lifetime or a complete inner trace.
No discretionary status/probe calls appear in exposed coordinator traces; hidden Codex child
calls cannot be counted. Child output and native end remain distinct from CLI process exit.

| Raw usage fields | Baseline | Changed |
| --- | --- | --- |
| Codex input / cached input / output / reasoning output | 862863 / 751232 / 935 / 39 | 867445 / 755200 / 973 / 7 |
| Claude final modelUsage input / cache read / cache creation / output | 24 / 364015 / 99138 / 2682 | 24 / 376103 / 94433 / 2870 |
| Claude A notification tokens / tools / milliseconds | 20862 / 1 / 64418 | 20914 / 1 / 66321 |
| Claude B notification tokens / tools / milliseconds | 20929 / 1 / 6523 | 20962 / 1 / 9071 |
| Claude C notification tokens / tools / milliseconds | 20723 / 1 / 5429 | 20786 / 1 / 10534 |

Counters are raw and differently scoped. Codex worker attribution and validated coordinator-only
usage are unavailable; Claude modelUsage is session-wide and notifications are worker-specific.
Do not sum overlapping counters or substitute zero for unavailable values. There is no general
cost, reliability or savings claim. #344's live idle/blocker evidence and constructed deadline,
unchanged-timeout and late-report cases are reused, not repeated here.

## Constructed campaign walkthroughs

These read the changed campaign instructions; they are not live GitHub merge/recovery proof.

| Case | Outcome of the instruction trace |
| --- | --- |
| Lowest cap / cap one | Minimum of task, campaign five and harness limits; no second dispatch at one. A reduced cap grants no stop/replacement authority. |
| Merge-required dependency | Reviewed/finished A does not release D before verified landing and dependency reconciliation; unrelated eligible C can refill. |
| Shared files | Active A or A's waiting unmerged PR holds overlapping C serial through merge. Only existing reserved mandatory-edit/coupled-index exceptions apply. |
| Ordered versions / blocked row | B finishes first but cannot land ahead of nonblocked A. Explicitly blocked A may be passed; its reservation stays consumed. Stale reassignment belongs only to the orchestrator after the complete scan. |
| Uncertain ownership | A report without observed end retains its slot; unreadable/foreign claims hold. A different verified free slot can admit independent work. |
| Resume / late report | Existing attempts, claim bindings and budgets reconcile before refill. A valid late report cancels recovery; stale reports cannot override verified current artifacts. |
| No ADR index | No row publication. |
| Coupled ADR index | Worker owns its gated row; ordered refresh reconciles adjacent conflicts. |
| Uncoupled ADR index | Fixed w1(A,B) can coexist with refilled w2(C). Close w1 after merges or explicit blocks/skips; publish merged pending rows once. A later-landed blocked A enters a later finite group. Quiet A does not close w1; publication does not bar C. |
| Publication resume | Retain membership, branch/PR and pending rows in existing notes; reconcile ambiguous writes before repeating; clear only verified publication and report unresolved rows. |
| Merge / cleanup | Green without exact-head author handshake stays pending. Cleanup still requires observed owner end, landed-commit containment and a removable clean worktree. |

## Reuse and rerun

Use fresh private scratch and the frozen A/B/C protocol, supply the selected campaign text plus
shared waiting reference, and capture stdout/stderr without live status reads. Run Codex with
`codex exec --skip-git-repo-check --ephemeral --json --sandbox workspace-write -C "$SCRATCH" -`.
Run Claude with `claude -p --no-session-persistence --output-format stream-json --verbose`
plus `--permission-mode dontAsk --allowedTools Agent 'Bash(python3 JOB.py *)'`
and `--strict-mcp-config --max-turns 30`, substituting the actual private job path.
Keep the original process handle, bound each arm, and inspect its exit before reading artifacts.
The campaign retains exact prompts/hashes, script, streams, timing artifacts and metadata privately
for #347. Raw paths, process/session identifiers and account telemetry are not public artifacts.
