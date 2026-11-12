# Decision receipt for a live worker — #495

## Problem

A campaign orchestrator relays an operator decision to a dispatched quest worker after dispatch,
and nothing says how the decision is delivered or how either side knows it arrived. The
orchestrator treats "sent" as "received"; the worker acts on whatever state it last read. Six
campaign sessions saw re-sent grants, a 2.5-hour stall on an approval already sent, and two
workers that built the scope option the operator had not approved.

Authority: WORK:SCOPE `q495-fc5aa4fd`; full lane, denominator 250 (M). The declared message
kinds come from #496 and are reused by reference.

## Design

Three prose edits, one per owner, and no new mechanism.

1. **`references/dispatch-liveness.md` owns delivery facts** shared by every dispatcher (campaign,
   forge, trial-loop, restock, saga): a message to a worker lands at its next turn boundary; a
   successful send proves the message was queued, not read; a report composed before that
   boundary cannot reflect it, so a crossed report is expected lag, not a lost send; a worker
   likewise knows a dispatcher's decision only as of the last message it read; and an idle
   notification is neither an end of run nor a stall, because the next message resumes the
   worker. The observed-end rule is unchanged.
2. **`skills/quest/SKILL.md` SCOPE CHECKPOINT owns the worker side.** A run dispatched under an
   interactive root asks its checkpoint question in its report to the dispatcher and waits by
   ending the turn; an unattended run keeps the existing park. Until it has read the answer it
   takes no step that depends on the question. On reading a relayed decision it records the
   decision verbatim in the `provenance` of the `WORK:SCOPE` that checkpoint freezes or
   re-freezes, before any design or build step, and quotes the same text in its next report. A
   decision whose text is not public-safe goes into `WORK:SCOPE` as a public-safe summary; the
   report carries the exact text.
3. **`skills/campaign/SKILL.md` step 5 owns the orchestrator side.** It relays a post-dispatch
   decision as one declared `DECISION:` or `ANSWER:` message carrying the operator's text
   verbatim, and records the row, worker, sent text and receipt state (`pending`, `delivered`,
   or `held: <reason>`) in the manifest's existing private notes. The decision is `delivered`
   when the worker's readback matches the sent text: a newer complete `WORK:SCOPE` recording it
   and the same text quoted in a report. The first report after the send may have crossed it; a
   later report without the quote, or tracker or branch evidence that the worker moved past the
   question without the readback, is a missing readback. A mismatch or a missing readback sets
   `held` — step 5's in-flight hold, with no label written; it is the one such hold that keeps
   a private record, because the sent text cannot be recomputed from live queries. Step 6 does not merge a row whose notes
   show `pending` or `held`; a resumed orchestrator that finds `pending` without a recorded
   report quote treats it as held. The orchestrator never resends to the same worker; a
   successor dispatched after an operator decision carries the decision in its prompt like any
   prompt-carried approval, and the record moves to the successor.

"Matches" means the quoted text in the report equals the sent decision text after trimming
leading and trailing whitespace, and the `WORK:SCOPE` names the same decision (verbatim or its
public-safe summary).

No ADR: the issue prescribes this approach, and the alternatives below are recorded here.

- **Acknowledgement message from the worker.** judgment: a second message is the same
  composition-time evidence; recording in `WORK:SCOPE` is durable and the checkpoint already
  writes it.
- **Resend on a missing readback.** judgment: a resend crosses the same turn boundary, and the
  live evidence is that resends produced the duplicate grants this issue reports.

## Failure model

1. Actors and deployments:
   - the campaign orchestrator model in an interactive Claude Code or Codex session;
   - a dispatched `$quest` worker under that campaign, whose `interaction` follows the root;
   - unattended campaigns are outside the receipt path: their workers park at the checkpoint.
2. Invariants and assets:
   - a scope option the operator did not approve is not merged; a rule-following worker does not
     build it before reading the answer;
   - the probe budget stays one per worker per run; declared kinds do not spend it (#496).
3. Accepted:
   - a worker that ignores the rule and proceeds: caught by the readback mismatch hold and the
     existing merge-time scope comparison, cost one held row;
   - the hold waits for an operator, so an absent operator stalls that row while others drain;
   - matching is model-judged text comparison, not a parser; anatomy rule 4 forbids a prose gate.
4. Covered elsewhere:
   - messages that are not decisions on a charter question — `REFRESH:` and a budget-stop
     continuation approval (quest step 6 records that in `WORK:TRAJECTORY`) — keep their owners;
   - the probe-budget hook and prefix vocabulary — #496;
   - liveness, probe, hold and replacement — `references/dispatch-liveness.md` unchanged rules.

## Success

1. `$quest` SCOPE CHECKPOINT tells a dispatched worker to wait for, record in `WORK:SCOPE`, and
   quote a relayed decision before any design or build step.
2. `$campaign` step 5 defines delivery as a matching readback and makes a mismatch or missing
   readback a hold without resend, citing the declared-kind paragraph rather than restating it.
3. `references/dispatch-liveness.md` states the turn-boundary landing, send-is-not-read, that a
   worker knows a decision only as of the last message it read, and that an idle notification
   is neither an end of run nor a stall.
4. `.claude-plugin/plugin.json` version is `7.13.0`.

## Validation

- Criteria 1–3 — task-test-not-applicable: the changes are instruction prose read by a model; no
  executable consumer parses them and anatomy rule 4 forbids a test asserting on prose. Proven by
  reading, by the design and branch review, and by `just verify` keeping links resolvable.
- Criterion 4 — focused-test: `just version-check`.
