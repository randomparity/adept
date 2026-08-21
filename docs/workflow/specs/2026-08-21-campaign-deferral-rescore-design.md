# Campaign deferrals are rescored against what the batch merged

## Summary

Give `$campaign` a deferral ledger and a rescore pass: every issue the campaign filed and the
operator declined at re-enqueue is re-read against merged `HEAD` before the campaign may
report drained, and any durable priority change is applied only behind operator confirmation,
as a rationale-bearing comment plus label flip, never a body rewrite. The governing decision
is [ADR 0026](../../../docs/adr/0026-campaign-rescores-its-deferrals.md).

## Non-goals

- No change to step 7's enqueue/decline decision itself: a decline still never enqueues,
  quests, or fixes the issue, and still adds no Queue row.
- No rescoring of issues this campaign did not file. The campaign cannot enumerate foreign
  deferrals without an unbounded tracker sweep and has no authority to mutate them.
- No ledger rows for issues closed not planned at step 4. Closure plus the annotation's
  reconsideration condition already owns the world-changed case for a closed issue, and a
  rescore could only ever classify it `not-open`.
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
| Issue | Priority at filing | Rescored |
|-------|--------------------|----------|
```

- `Rescored` holds one recognized outcome: `pending`, `not-required`, `not-open`,
  `unchanged`, `moved`, or `declined` — each non-pending value dated, with a short evidence
  note where one applies. Validation mirrors the occurrence table: unique issue numbers,
  recognized values. Older manifests backfill an empty table and normalize the Completion
  condition field to the schema text.
- Step 7 appends a row when the operator declines an enqueue. The row never becomes a Queue
  row; decline semantics are unchanged.

## Rescore pass contract

Runs at the end of step 7 — after the enqueue decision resolves, and again on every later
arrival after further merges — immediately before the occurrence search and drained check:

1. Invalidate stale scores first: any row whose recorded date precedes the newest dated merge
   entry in the Outcomes log resets to `pending`. Merge entries carry dates, so the comparison
   is manifest-computable across resumes.
2. If no merge entry postdates a `pending` row's filing, set it `not-required` — nothing since
   it was filed can have moved its world.
3. For each row still `pending`: read the issue's current state and labels, then read the code
   it cites at merged `HEAD` the way step 3 triage reads code. Classify: unchanged, satisfied
   by the batch (level moves down), or promoted by the batch (level moves up). A read that
   succeeds with authoritative evidence the issue no longer exists records `not-open` and
   writes nothing; a transport, auth, or rate-limit failure keeps the row `pending` as a
   retryable blocker.
4. When any proposed action exists, present one proposal table — issue, filed priority,
   finding, evidence citations, proposed action — and take one explicit operator confirmation
   covering all proposed writes. With no proposed action, no confirmation is asked.
5. On confirmation, per moved issue: post one `WORK:RESCORE` annotation comment — prior level,
   new level, evidence citations, the batch merge that changed the picture, wrapped in
   `<!-- WORK:RESCORE -->` / `<!-- RESCORE:COMPLETE -->` per the quest-log annotation
   convention. The comment must succeed and read back before the priority label flips; the
   body is never rewritten. Record `moved`.
6. On operator decline, write nothing to GitHub and record `declined`. An unchanged finding
   records `unchanged` with a short evidence note.

## Drained check contract

Step 8's definition of drained gains one conjunct, computable from the manifest alone:
**no Deferrals row is `pending`**. A rescore that cannot complete keeps its row `pending` and
blocks completion exactly like an unreconciled occurrence — it never silently reports drained.
Every Deferrals row, whatever its outcome, appears in the final report with its date.

## Failure handling

- Transport, auth, or rate-limit failure on the issue read → row stays `pending`; named
  blocker; completion blocked; retry on resume.
- Authoritative evidence the issue no longer exists → `not-open`; nothing written.
- Comment posted but readback fails → do not flip the label; row stays `pending`; retry on
  resume posts a fresh complete block (latest-complete-wins), never an edit.
- Label flip fails after verified comment → record blocker; resume re-attempts the flip only.
