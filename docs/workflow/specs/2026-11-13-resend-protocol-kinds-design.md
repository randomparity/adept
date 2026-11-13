# Probe budget: resend requests and protocol messages — #499

## Problem

The `SendMessage` hook in `.claude/settings.json` exempts only string messages that start with
`DECISION:`, `ANSWER:` or `REFRESH:` (#496). Two non-probes fall outside it: an object-form harness
protocol message such as `{"type":"shutdown_request"}`, and a request that a worker resend the
remainder of a report the dispatcher received truncated. Each spends the worker's one probe, and
after a probe each is blocked, so a dispatcher cannot cleanly shut down a worker it probed.
Authority: WORK:SCOPE `q499-f3a2a9bc`; full lane, denominator 100 (S).

## Design

Operator decisions (2026-11-13) fix both choices; no ADR, because no viable alternative remains
open and the reference paragraph is the durable contract.

1. **`RESEND:`** is a fourth declared kind, matched like the other three: a string message whose
   first bytes are exactly `RESEND:`. It means only "send the remainder of the report I received
   truncated". `ANSWER:` keeps its meaning (a reply to a question the worker asked).
2. **Protocol allowlist.** An object message is a declared non-probe only when its `type` is one of
   the three protocol values the harness `SendMessage` schema defines: `shutdown_request`,
   `shutdown_response`, `plan_approval_response`. Any other object, an object with no `type`, an
   array, or any other non-string stays an undeclared probe.

The hook's jq filter becomes one `if type == "string" … elif type == "object" … else false end`
expression; the `type == "object"` guard keeps `.type` from erroring on an array. The equality
chain avoids `IN`, so jq 1.5 and later evaluate it. The block message names all four prefixes and
the protocol exemption. `references/dispatch-liveness.md` adds `RESEND:` to the declared-kinds
paragraph and one sentence on protocol messages. Owner, 900 s window, recipient exemptions and
state path are unchanged; no caller migrates.

## Failure model

- Actors and deployments: the dispatching model in a Claude Code session of this repository; the
  hook runs locally per `SendMessage` call under `sh` (dash on Linux, bash 3.2 on macOS) with jq.
- Invariants and assets: one probe per worker per 900 s window; no blocked declared non-probe;
  the hook stays one valid JSON string runnable by `sh -c`.
- Accepted: a model labelling a probe `RESEND:` or wrapping it as an allowlisted protocol object
  bypasses the bump — the hook is a speed bump for an honest dispatcher, not a security control,
  and the reference forbids it.
- Accepted: a protocol `type` the harness adds later counts as a probe until the allowlist is
  updated (fails toward today's behaviour).
- Accepted: the hook fails open when `jq` or the state directory fails, as today.
- Covered elsewhere: changing the window or budget (excluded, not planned); other new kinds
  (future issue).

### Threat model

- Boundary: tool-input JSON from the session's own model reaches jq; no untrusted party.
- Control: exact `startswith` and string equality in jq; `message` is never interpolated into
  shell; the recipient is still sanitised before forming the state path.
- Out of scope: a dishonest dispatcher (accepted above).

## Success

1. A string message starting `RESEND:` exits 0 on a spent budget and on a fresh one, writing no
   state.
2. An object message with `type` in {`shutdown_request`, `shutdown_response`,
   `plan_approval_response`} exits 0 on a spent budget and on a fresh one, writing no state.
3. An object with another or no `type`, and a JSON array message, pass a fresh budget and exit 2
   on a spent one.
4. The three existing prefixes, the first-byte/case-exact rule, and the `team-lead`/`main`
   exemptions behave as before.
5. The reference names `RESEND:` with its narrow meaning and the protocol rule; the block message
   names `RESEND:`.
6. `.claude-plugin/plugin.json` version is `7.13.3`.

## Validation

- Criteria 1–4 — focused-test: `scripts/probe-budget-hook-test.sh` runs the extracted hook under
  `sh -c` with a private `TMPDIR`; `just test probe-budget`.
- Criterion 5 — task-test-not-applicable: prose; anatomy rule 4 forbids asserting on it.
- Criterion 6 — focused-test: `just version-check`.
