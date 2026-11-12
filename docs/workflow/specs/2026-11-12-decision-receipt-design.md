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
   successful send proves the message was queued, not read; an idle notification is neither an
   end of run nor a stall; and a report composed before that boundary cannot reflect the message,
   so a crossed report is expected lag, not a lost send. This extends the existing
   composition-time paragraph to the reverse direction.
2. **`skills/quest/SKILL.md` SCOPE CHECKPOINT owns the worker side.** A dispatched run asks its
   checkpoint question in its report to the dispatcher and waits by ending the turn. Until it has
   read the answer it takes no step that depends on the question. On reading a relayed decision
   it records the decision verbatim in the `provenance` of the `WORK:SCOPE` that checkpoint
   freezes or re-freezes, before any design or build step, and quotes the same text in its next
   report. A decision whose text is not public-safe goes into `WORK:SCOPE` as a public-safe
   summary; the report carries the exact text.
3. **`skills/campaign/SKILL.md` step 5 owns the orchestrator side.** It relays a post-dispatch
   decision as one declared `DECISION:` or `ANSWER:` message carrying the operator's text
   verbatim, and records the sent text, row and worker in the manifest's private notes. The
   decision is delivered only when the worker's readback matches the sent text: a newer complete
   `WORK:SCOPE` recording it and the same text quoted in a report. While pending, the row's PR is
   not merged. A mismatch, or evidence that the worker moved past the question without the
   readback, or an observed end without it, is a hold on that row; the orchestrator does not
   resend.

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
   - a dispatched `$quest` worker under that campaign, whose `interaction` follows the root.
2. Invariants and assets:
   - the worker never builds a scope option the operator did not approve;
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
3. `references/dispatch-liveness.md` states the turn-boundary landing, send-is-not-read, and that
   an idle notification is neither an end of run nor a stall.
4. `.claude-plugin/plugin.json` version is `7.13.0`.

## Validation

- Criteria 1–3 — task-test-not-applicable: the changes are instruction prose read by a model; no
  executable consumer parses them and anatomy rule 4 forbids a test asserting on prose. Proven by
  reading, by the design and branch review, and by `just verify` keeping links resolvable.
- Criterion 4 — focused-test: `just version-check`.
