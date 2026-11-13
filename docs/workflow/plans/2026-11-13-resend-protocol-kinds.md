# Probe budget: resend requests and protocol messages — plan

Goal: exempt `RESEND:` messages and allowlisted protocol objects from the `SendMessage` probe
budget (spec: `docs/workflow/specs/2026-11-13-resend-protocol-kinds-design.md`).

Architecture: one jq filter change and one block-message change inside the hook command string
in `.claude/settings.json`, the suite cases that pin it, one reference paragraph, one version.

Tech stack: POSIX sh + jq one-liner in JSON; bash 3.2 test suite; `just` guardrails.

Expected implementation size: 25–40 changed lines (S) — one hook line, ~15 suite lines, ~5
reference lines, one version line.

## Global Constraints

- The hook stays one JSON string runnable by `sh -c` (dash, bash 3.2 POSIX mode); jq ≥ 1.5
  features only (no `IN`).
- Anatomy rule 4: no test asserts on prose.
- Do not edit `skills/campaign/SKILL.md` or the reference's `Observed end` section.
- `.claude-plugin/plugin.json` version = `7.13.3` exactly (assigned).
- Guardrails: `just test probe-budget`; `just commit-check` per commit via prek.

## File map

| File | Owns | Change |
|---|---|---|
| `.claude/settings.json` | SendMessage hook | new jq filter; block message names `RESEND:` and protocol rule |
| `scripts/probe-budget-hook-test.sh` | hook behaviour suite | replace object-form case; add RESEND, allowlist, non-allowlisted cases |
| `references/dispatch-liveness.md` | declared-kinds paragraph | add `RESEND:` and the protocol sentence |
| `.claude-plugin/plugin.json` | version | `7.13.1` → `7.13.3` |

## Task 1 — hook, suite, reference, version

One task: hook, suite and reference are one contract.

Verification:

- Contract: declared-kind and allowlist exemption (spec criteria 1–4). Mode: focused-test.
  Test: `scripts/probe-budget-hook-test.sh`. Red: after step 1 the run fails at the first
  `RESEND:` case with `expected exit 0, got 2`. Green: `just test probe-budget` prints
  `ok   scripts/probe-budget-hook-test.sh` and exits 0.
- Contract: reference and block-message wording (criterion 5). Mode: task-test-not-applicable —
  prose; anatomy rule 4 forbids a gate on it.
- Contract: version (criterion 6). Mode: focused-test. `just version-check` exits 0.

Steps:

1. In `scripts/probe-budget-hook-test.sh`, after the `REFRESH:` case, add
   `send 0 probed '"RESEND: your report stopped mid-sentence"'`. Replace the
   "object-form protocol message counts as undeclared" block with:

   ```bash
   # A RESEND: request to a fresh worker leaves its budget unspent.
   send 0 resend '"RESEND: from step 6"'
   [ ! -e "$state/resend" ] || fail 'RESEND: message spent the probe budget'

   # An allowlisted protocol object passes a spent budget and writes no state.
   send 0 probed '{"type":"shutdown_request"}'
   send 0 probed '{"type":"shutdown_response","request_id":"r1","approve":true}'
   send 0 probed '{"type":"plan_approval_response","request_id":"r1","approve":false}'
   send 0 protocol '{"type":"shutdown_request"}'
   [ ! -e "$state/protocol" ] || fail 'protocol message spent the probe budget'

   # Any other non-string message counts as undeclared.
   send 0 other '{"type":"status_check"}'
   send 2 other '{"type":"status_check"}'
   send 0 notype '{"reason":"no type"}'
   send 2 notype '{"reason":"no type"}'
   send 0 array '["shutdown_request"]'
   send 2 array '["shutdown_request"]'
   send 2 other '{"type":"SHUTDOWN_REQUEST"}'
   ```

2. Run `just test probe-budget`; expect failure `to=probed message="RESEND: …": expected exit
   0, got 2`.
3. In `.claude/settings.json`, replace the jq filter
   `.tool_input.message | strings | startswith(\"DECISION:\") or startswith(\"ANSWER:\") or startswith(\"REFRESH:\")`
   with
   `.tool_input.message | if type == \"string\" then startswith(\"DECISION:\") or startswith(\"ANSWER:\") or startswith(\"REFRESH:\") or startswith(\"RESEND:\") elif type == \"object\" then .type == \"shutdown_request\" or .type == \"shutdown_response\" or .type == \"plan_approval_response\" else false end`
   and the block message's last sentence with: `If this is a genuine non-probe message, start
   its first line with DECISION:, ANSWER:, REFRESH: or RESEND:, or send a shutdown or
   plan-approval protocol message (references/dispatch-liveness.md), and send it again.`
4. Run `jq empty .claude/settings.json` (exit 0) and `just test probe-budget` (green).
5. In `references/dispatch-liveness.md`'s declared-kinds paragraph, add after the `REFRESH:`
   clause: `` `RESEND:` for a request that the worker resend the remainder of a report the
   dispatcher received truncated `` and, before "A declared message…", the sentence: "A harness
   protocol message in object form — a shutdown request or response, or a plan-approval
   response — is not a probe either; any other object-form message counts as one." Rewrap at
   100 columns.
6. Set `.claude-plugin/plugin.json` `version` to `7.13.3`; run `just version-check` (exit 0).
7. Commit `fix: exempt resend requests and protocol messages from probe budget`.

Rollback: revert the commit; no state migrates (budget files are per-run scratch).
