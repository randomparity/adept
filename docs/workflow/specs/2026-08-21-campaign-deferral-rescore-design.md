# Campaign deferrals are rescored against what the batch merged

## Summary

Give `$campaign` a deferral ledger and a rescore pass: every issue the campaign filed but did
not fix — declined at re-enqueue or closed not planned — is re-read against merged `HEAD`
before the campaign may report drained, and any durable priority change is applied only behind
operator confirmation, as a rationale-bearing comment plus label flip, never a body rewrite.
The governing decision is [ADR 0026](../../../docs/adr/0026-campaign-rescores-its-deferrals.md).

## Non-goals

- No change to step 7's enqueue/decline decision itself: a decline still never enqueues,
  quests, or fixes the issue, and still adds no Queue row.
- No rescoring of issues this campaign did not file or decline. The campaign cannot enumerate
  foreign deferrals without an unbounded tracker sweep and has no authority to mutate them.
- No automated re-scoring loop, background watcher, or new script, dependency, or label family.
- No body edits on deferred issues; the original framing stays legible.
- No change to quest, bounty, or merge-phase behavior.

## Requirements traceability

| # | Source | Contract |
|---|---|---|
| 1 | Issue #183 "Any fix must preserve" ¶1 | A step-7 decline leaves the issue outside the campaign queue; the deferral ledger is not a Queue row and never becomes one |
| 2 | Issue #183 "Any fix must preserve" ¶2 | The drained check gains its rescore conjunct as pure manifest state: every Deferrals row shows a recognized rescore outcome |
| 3 | Issue #183 "Any fix must preserve" ¶3 | Repairs are comments; bodies are never rewritten |
| 4 | Issue #183 cost question | Each pending deferral is re-read by source inspection against merged `HEAD`, triage-style — never a title-level pass |
| 5 | Issue #183 authority question | Every GitHub mutation (comment, label flip) sits behind one explicit operator confirmation, mirroring the enqueue gate |
| 6 | Issue #183 second defect | An applied priority change posts its why — prior level, new level, evidence citations, the merge that changed the picture — before the label flips |

## Manifest contract

The schema gains one section:

```markdown
## Deferrals
| Issue | Kind | Priority at filing | Rescored |
|-------|------|--------------------|----------|
```

- `Kind` is `declined` (step 7) or `closed-not-planned` (step 4).
- `Rescored` holds one recognized outcome: `pending`, `not-required`, `not-open`,
  `unchanged`, `moved`, or `declined` — each non-pending value dated, with a short note where
  one applies. Validation mirrors the occurrence table: unique issue numbers, recognized
  values, non-pending rows carry a date. Older manifests backfill an empty table.
- Step 4 appends a row when it closes an issue not planned; step 7 appends one when the
  operator declines an enqueue. Neither path creates a Queue row from the ledger.

## Rescore pass contract

Runs at the end of step 7 — after the enqueue decision resolves, and again on every later
arrival after further merges — immediately before the occurrence search and drained check:

1. If the campaign merged no pull requests this run, set every `pending` cell to
   `not-required`. Nothing this run did can have moved a deferral's world.
2. Otherwise, for each `pending` row: read the issue's current state and labels, then read the
   code it cites at merged `HEAD` the way step 3 triage reads code. Classify: unchanged,
   satisfied by the batch (level moves down), or promoted by the batch (level moves up). A
   closed-or-absent issue records `not-open` and writes nothing.
3. Present one proposal table: issue, filed priority, finding, evidence citations, proposed
   action. One explicit operator confirmation covers all proposed writes.
4. On confirmation, per moved issue: post one `WORK:RESCORE` annotation comment — prior level,
   new level, evidence citations, the batch merge that changed the picture, wrapped in
   `<!-- WORK:RESCORE -->` / `<!-- RESCORE:COMPLETE -->` per the quest-log annotation
   convention. The comment must succeed and read back before the priority label flips; the
   body is never rewritten. Record `moved`.
5. On operator decline, write nothing to GitHub and record `declined`. An unchanged finding
   records `unchanged` with its evidence.

## Drained check contract

Step 8's definition of drained gains one conjunct, computable from the manifest alone:
**no Deferrals row is `pending`**. A rescore that cannot complete (failed read, failed comment
writeback) keeps its row `pending` and blocks completion exactly like an unreconciled
occurrence — it never silently reports drained. Rescore actions appear in the final report.

## Failure handling

- Failed issue read → row stays `pending`; named blocker; completion blocked.
- Comment posted but readback fails → do not flip the label; row stays `pending`; retry on
  resume posts a fresh complete block (latest-complete-wins), never an edit.
- Label flip fails after verified comment → record blocker; resume re-attempts the flip only.
