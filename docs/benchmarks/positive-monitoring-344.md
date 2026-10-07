# Positive waiting: bounded evidence for #344

Measured 2026-10-07 on macOS arm64, Bash 3.2; no target architecture declared.
[Protocol/cases](../workflow/specs/2026-10-07-positive-monitoring-design.md) were frozen before
baseline; protocol git hash `86d188c1d0f6239c7dd7ee6f2b04dffbd82f9ce7`.
Baseline guidance: `6fd166788ac545552681633587c8f26151cbdd64`; changed guidance: this PR's
shared reference and forge serial paragraph. Neither changed during its measured arm.
The supplied guidance was injected into each prompt, not loaded as an installed plugin update.

## Inputs and accounting

One baseline then one changed session per harness, at most two sequential fresh workers, one
occupied worker slot, 300-second process bound. H requests one `sleep 12` then `H-DONE`;
coordinator computes 17+25 while pending. B then reports `BLOCKED: missing authorized input`.
Both prompts require actual exposed schemas, no mutations/status reads, and D/U/L walkthroughs.
This coaching also constrains baseline: this is compatibility evidence, not an unprompted A/B
performance test. Prompt SHA-256 baseline `9dd45703bb923f87cf8a79adb86cc464a1bb92ec5e362e90b492fbe879afcb01`;
changed `995982886bb64da1a61340854a77494c181a6b18d7151a94b62c1fbbb8d1765a`.

Codex 0.160.1 used configured `gpt-6-astra`, reasoning `medium`, read-only sandbox. Claude Code
2.1.292 resolved `claude-opus-5-5`, default effort (unexposed), `dontAsk`, allowed `Agent` and
`Bash(sleep 12)`, strict MCP configuration. Existing user settings/hooks remained active; no
configuration was changed. Each no-tool auth/capability preflight passed (7.24s/9.05s), outside
measured arms. Service/cache state was uncontrolled; no harness-to-harness cost inference.

| Arm | Exit / seconds | Coordinator trace | H/B outcome |
| --- | --- | --- | --- |
| Codex baseline | 0 / 50.907 | 4 text items, 2 native wait items, 1 serialized turn | H-DONE / blocker reported |
| Codex changed | 0 / 65.760 | 4 text items, 2 native wait items, 1 serialized turn | H-DONE / blocker reported |
| Claude baseline | 0 / 57.977 | 5 distinct coordinator message IDs, result num_turns 2+2+1 | 2 completed native workers |
| Claude changed | 0 / 73.648 | 5 distinct coordinator message IDs, result num_turns 2+2+1 | 2 completed native workers |

Codex text causes: handoff/dispatch, useful work/wait, H completion/B handoff, B diagnosis/final.
Claude causes: H dispatch, useful work/yield, H completion/B dispatch, B yield, B diagnosis/final.
No discretionary status/probe/replacement calls appeared. No observed unchanged timeout or
mandatory timed progress wake occurred; U is constructed, not a live timeout result. Codex's
serialized turn count is not its API inference-call count (unavailable). CLI process exit was
observed for every arm. Claude exposes Agent starts/completion notifications and H's successful
single Bash call. Codex JSONL exposes native waits but omits spawn and child-tool events: dispatch,
H/B receipt and no-overlap are coordinator reports, not independently observable child traces.

| Raw usage field set | Baseline | Changed |
| --- | --- | --- |
| Codex turn input / cached input / output / reasoning output | 132413 / 118272 / 972 / 20 | 134791 / 119936 / 1108 / 19 |
| Claude final modelUsage input / cache read / cache creation / output | 16 / 161127 / 52954 / 4166 | 16 / 164851 / 53961 / 3444 |
| Claude H notification tokens / tools / milliseconds | 20500 / 1 / 15425 | 20467 / 1 / 19259 |
| Claude B notification tokens / tools / milliseconds | 17509 / 0 / 1304 | 17489 / 0 / 2746 |

These are distinct harness counters, not normalized totals. Codex worker attribution and a
validated coordinator-only token aggregate are unavailable. Claude raw per-message and per-turn
usage remains in private captures; final modelUsage is session-wide. Unknown is not zero.
No failed measured invocation or retry occurred. No savings or reliability improvement is shown.

## Reader proof and reuse

D: deadline without end retains ownership and one-probe/one-replacement bounds. U: unchanged wait
re-enters pending state without reads. L: verified current state outranks stale report; a valid
late report cancels recovery; after a replacement, reconcile both, never choose a winner silently.
These are constructed instruction walkthroughs, not live recovery, race, claim or merge tests.
Forge's two loaded templates were read through the async-only dispatch path; they preserve serial
ordering without a mandatory flag. Other reference consumers introduced no verified conflict.

Rerun in trusted private scratch with the frozen H/B/D/U/L inputs plus the selected reference and
forge's `Silent party workers` section, capturing stdout/stderr and monotonic process duration:
`codex exec --skip-git-repo-check --ephemeral --json --sandbox read-only -C "$SCRATCH" -` and
`claude -p --no-session-persistence --output-format stream-json --verbose --permission-mode dontAsk --allowedTools Agent 'Bash(sleep 12)' --strict-mcp-config`.
Read results once the original process exits; keep failed captures. The campaign retains private
protocol, exact prompts, command metadata and JSONL for #346/#347; they contain host/session data
and are not public artifacts. No runner ships. #346 owns refill; #347 owns final consolidation.
Current [Claude documentation](https://code.claude.com/docs/en/sub-agents#run-subagents-in-foreground-or-background)
and observed native schemas support the capability examples; session modes can change available fields.
