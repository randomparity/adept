# Probe-budget declared kinds — #496

## Problem

The `SendMessage` hook in `.claude/settings.json` spends a worker's budget on any message, so a
decision, an answer or a branch refresh sent after a probe is blocked. The reference rule is one
**probe** per worker per run. Authority: WORK:SCOPE `q496-370fbade`; light lane, denominator 100 (S).

## Scope

A string `tool_input.message` (the field the harness `SendMessage` schema names) whose first
characters are exactly `DECISION:`, `ANSWER:` or `REFRESH:` is a declared non-probe. The hook
exits 0 for it before reading or writing budget state. Every other message to a non-exempt
recipient keeps today's behaviour: the first passes and records the time, a second within 900
seconds is blocked. The block text names the prefixes instead of telling the operator to clear the
state directory. `references/dispatch-liveness.md` names the three prefixes in the one-probe
paragraph and says a probe must not carry one. Matching is case-sensitive at the message's first
byte; a prefix on a later line or after whitespace does not count. Object-form (protocol)
messages keep today's behaviour.

Declared kind beats advising instead of blocking, which leaves no speed bump against reflexive
re-probing (operator choice via campaign triage). No ADR: the reference paragraph is the
durable contract. Owner, window and exemptions are unchanged; no caller migrates.

### Failure model

- Actors and deployments: the dispatching model in a Claude Code session of this repository; the
  hook runs locally per `SendMessage` call.
- Invariants and assets: the probe budget of one per worker per window; no blocked declared
  non-probe.
- Accepted: a model mislabelling a probe with a prefix bypasses the bump — the hook is a speed
  bump for an honest dispatcher, not a security control, and the reference forbids it.
- Accepted: an unprefixed or object-form non-probe to a spent worker is still blocked, as today.
- Accepted: the hook fails open when `jq` or the state directory fails, as today.
- Covered elsewhere: receipt contract for relayed decisions — #495.

### Threat model

- Boundary and actor: tool input JSON from the session's own model; no untrusted party.
- Control: exact `startswith` match in `jq`; the recipient is still sanitised before forming a path.

## Success

1. A second undeclared message to one non-exempt worker within the window exits 2.
2. A declared message exits 0 whether or not that worker's budget is spent, and writes no state.
3. A prefix not at the first byte does not exempt; an object-form message counts as undeclared.
4. The reference names the three prefixes.
5. `plugin.json` version is `7.12.7`.

## Validation

- Criteria 1–3 — focused-test: `scripts/probe-budget-hook-test.sh` extracts the hook command from
  `.claude/settings.json`, pipes JSON into it under an isolated `TMPDIR`, and asserts exit codes
  and state-file presence. It runs the command under `sh -c` (dash on Linux), so the hook
  stays POSIX sh. Run with `just test probe-budget`.
- Criterion 4 and the block text — task-test-not-applicable: prose; anatomy rule 4.
- Criterion 5 — focused-test: `just version-check`.
