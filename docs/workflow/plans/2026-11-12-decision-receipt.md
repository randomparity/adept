# Decision receipt for a live worker — plan

Goal: give a decision relayed to a live dispatched worker a receipt both sides can check
(spec: `docs/workflow/specs/2026-11-12-decision-receipt-design.md`).

Architecture: three prose insertions, one per owner — delivery facts in
`references/dispatch-liveness.md`, the worker's wait-record-quote duty in `$quest` SCOPE
CHECKPOINT, the orchestrator's send-and-match duty in `$campaign` step 5. No script, hook or
gate changes.

Tech stack: Markdown instruction files; `just` guardrails.

Expected implementation size: 20–35 changed lines (M) — three new paragraphs of 6–10 wrapped lines
each plus one version line.

## Global Constraints

- Anatomy rule 4: no test or gate asserts on prose.
- Reuse #496's declared kinds by linking `references/dispatch-liveness.md#probe-and-hold`; do not
  restate the prefixes' probe-budget rule.
- Do not change the probe budget, the hook, `.claude/settings.json`, or the claim/token contract.
- Wrap prose at 100 columns; no absolute host paths (public repo).
- `.claude-plugin/plugin.json` version = `7.13.0` exactly (assigned).
- Guardrails: `just test <pattern>` while iterating; `just commit-check` runs per commit via prek.

## File map

| File | Owns now | Change |
|---|---|---|
| `references/dispatch-liveness.md` | probe, hold, wait, replacement rules | add message-landing paragraph after the report-staleness paragraph |
| `skills/quest/SKILL.md` | SCOPE CHECKPOINT question/answer rule | add dispatched-run paragraph before the unattended-root paragraph |
| `skills/campaign/SKILL.md` | step 5 event collection | add receipt paragraph after "Use events to collect evidence." |
| `.claude-plugin/plugin.json` | version | `7.12.7` → `7.13.0` |

No caller migrates and no path is removed; restock, trial-loop, forge and saga gain the
reference facts without edits.

## Task 1 — receipt contract across the three owners

One task: the three paragraphs are one contract and a reviewer could not accept one without
the others.

Interfaces: quest's paragraph defines the readback (`WORK:SCOPE` provenance record plus report
quote); campaign's paragraph consumes it by name ("`$quest`'s SCOPE CHECKPOINT"); both link the
reference's `#probe-and-hold` anchor for the kinds.

Verification:

- Contract: dispatch-liveness delivery facts — Mode: task-test-not-applicable — instruction
  prose with no executable consumer; anatomy rule 4 forbids a prose assertion.
- Contract: quest worker readback — Mode: task-test-not-applicable — same reason.
- Contract: campaign delivered-only-on-readback hold — Mode: task-test-not-applicable — same
  reason.
- Contract: relative links resolve — covered by the existing `check-skill-shape.sh` rule 5 under
  `just verify`; no new test.

Steps:

1. In `references/dispatch-liveness.md`, insert after the paragraph beginning
   "**A report proves the worker was alive**" (ending "every other worker report a dispatcher
   reads."):

   ```markdown
   **A message to a worker lands at its next turn boundary.** A worker inside a long tool call
   reads it when that call returns; an idle worker reads it as the start of its next turn. A
   successful send proves the message was queued, not read, and a report composed before that
   boundary cannot reflect it — a report that crosses a message is the expected lag, not a lost
   send. An idle notification means only that the worker ended a turn: it is neither an end of run,
   which only the observed end below proves, nor a stall, because the next message resumes the
   worker. Where the owning workflow defines a readback for a message, the message counts as
   delivered only on that readback.
   ```

2. In `skills/quest/SKILL.md` SCOPE CHECKPOINT, insert before "An unattended root never answers":

   ```markdown
   **A dispatched run asks through its dispatcher.** When an orchestrator dispatched this run,
   the question goes in the worker's report to that dispatcher, and the run waits by ending its
   turn. The answer arrives as a declared `DECISION:` or `ANSWER:` message
   ([dispatch liveness](../../references/dispatch-liveness.md#probe-and-hold)); an unasked
   `DECISION:` that changes a charter field is handled the same way. Until the run has read the
   answer it takes no step that depends on the question — no design, no build, no write that
   selects one of its options. On reading it, record the decision verbatim in the `provenance`
   of the `WORK:SCOPE` this checkpoint freezes or re-freezes, before any design or build step,
   and quote the same text in the next report. That pair is the readback `$campaign` checks. A
   decision whose text is not public-safe goes into `WORK:SCOPE` as a public-safe summary, and
   only the report carries the exact text.
   ```

3. In `skills/campaign/SKILL.md` step 5, insert after the paragraph beginning
   "**Use events to collect evidence.**":

   ```markdown
   **A decision made after dispatch has a receipt.** Relay an operator's answer to a worker's
   question, or a new decision on a live row's charter, as one declared `DECISION:` or `ANSWER:`
   message carrying the operator's text verbatim;
   [dispatch liveness](../../references/dispatch-liveness.md#probe-and-hold) owns the kinds and
   their probe-budget exemption. Record the row, worker and exact sent text in the manifest's
   existing private notes. The decision is delivered only when the worker's readback matches: a
   newer complete `WORK:SCOPE` recording it and a report quoting the sent text, compared after
   trimming surrounding whitespace, both defined by `$quest`'s SCOPE CHECKPOINT. Until then it is
   pending and the row's PR is not merged; a report composed before the worker's next turn
   boundary, including one that crossed the message, is not a missing readback. A mismatch,
   report, scope or branch evidence that the worker moved past the question without the
   readback, or an observed end without it, is a **hold** on that row: name it, ask the operator,
   and keep draining. Never resend the decision — a resend lands at the same turn boundary and
   duplicates what the worker may already hold.
   ```

4. Read the three insertions back in context; confirm each `#probe-and-hold` link target heading
   `## Probe and hold` exists in `references/dispatch-liveness.md`.
5. Run `just test skill-shape`; expect every suite `ok` and exit 0.
6. Commit: `docs: add a receipt contract for decisions relayed to workers`.

## Task 2 — version bump

Verification:

- Contract: plugin version is `7.13.0` — Mode: focused-test — `just version-check`; red before
  the edit only under CI's `BASE_SHA` (locally it checks format), green after with exit 0.

Steps:

1. Set `"version": "7.13.0"` in `.claude-plugin/plugin.json`.
2. Run `just version-check`; expect exit 0.
3. Commit: `chore: bump plugin version to 7.13.0`.

Rollback: revert the commits; no state outside the repository changes.
