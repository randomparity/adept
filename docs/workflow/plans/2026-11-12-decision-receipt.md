# Decision receipt for a live worker — plan

Goal: give a decision relayed to a live dispatched worker a receipt both sides can check
(spec: `docs/workflow/specs/2026-11-12-decision-receipt-design.md`).

Architecture: three prose insertions, one per owner — delivery facts in
`references/dispatch-liveness.md`, the worker's wait-record-quote duty in `$quest` SCOPE
CHECKPOINT, the orchestrator's send-and-match duty in `$campaign` step 5. No script, hook or
gate changes.

Tech stack: Markdown instruction files; `just` guardrails.

Expected implementation size: 35–50 changed lines (M) — three new paragraphs of 9–17 wrapped lines
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
- Contract: relative links resolve — Mode: focused-test — `just shape-check` (rule 5 resolves
  link files; the `#probe-and-hold` anchor is checked by step 4's read).

Steps:

1. In `references/dispatch-liveness.md`, insert after the paragraph beginning
   "**A report proves the worker was alive**" (ending "every other worker report a dispatcher
   reads."):

   ```markdown
   **A message to a worker lands at its next turn boundary.** A worker inside a long tool call
   reads it when that call returns; an idle worker reads it as the start of its next turn. A
   successful send proves the message was queued, not read, and a report composed before that
   boundary cannot reflect it — a report that crosses a message is the expected lag, not a lost
   send. The worker side is the same: a worker knows a dispatcher's decision only as of the last
   message it read. An idle notification means the worker ended a turn; it is neither an end of
   run, which only the observed end below proves, nor a stall, because the next message resumes
   the worker. Where the owning workflow defines a readback for a message, the message counts as
   delivered only on that readback.
   ```

2. In `skills/quest/SKILL.md` SCOPE CHECKPOINT, insert before "An unattended root never answers":

   ```markdown
   **A dispatched run asks through its dispatcher.** When this run was dispatched under an
   interactive root, the question goes in the worker's report to its dispatcher, and the run
   waits by ending its turn; an unattended run parks as below. The answer arrives as a declared
   `DECISION:` or `ANSWER:` message
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
   their probe-budget exemption. Record the row, worker, sent text and receipt state — `pending`,
   `delivered`, or `held: <reason>` — in the manifest's existing private notes. It is `delivered`
   when the worker's readback matches, both halves defined by `$quest`'s SCOPE CHECKPOINT: a
   newer complete `WORK:SCOPE` recording the decision, and a report quoting the sent text,
   compared after trimming surrounding whitespace. The first report after the send may have
   crossed it. A later report without the quote, tracker or branch evidence that the worker
   moved past the question without the readback, or a mismatch sets `held`: the in-flight hold
   below, with no label written — name it, ask the operator, and keep draining. It is the one
   such hold that keeps a private record, because the sent text cannot be recomputed from live
   queries. It is also a step 6 merge-hold trigger: step 6 does not merge a row whose decision
   is `pending` or `held`; a resumed orchestrator that finds `pending` with no recorded report
   quote treats it as `held`. Never resend a decision to the same worker: a resend lands at the
   same turn boundary and duplicates what it may already hold. A successor dispatched on the
   operator's answer to the hold carries the decision in its prompt like any pre-dispatch
   approval, and the record moves to the successor.
   ```

4. Read the three insertions back in context; confirm each `#probe-and-hold` link target heading
   `## Probe and hold` exists in `references/dispatch-liveness.md`.
5. Run `just shape-check`; expect exit 0 (rule 5 resolves the new relative link files).
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
