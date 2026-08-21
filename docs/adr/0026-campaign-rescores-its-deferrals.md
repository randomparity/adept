# 0026 — Campaign rescores its deferrals against what the batch merged

## Status

Accepted (2026-08-21)

## Context

Campaign files issues it declines to fix, then merges a queue that changes the tree those
issues were scored against, and never re-reads them. A deferral keeps the priority it was
given at filing time, assigned against a pre-merge world. A batch merge can satisfy a
deferred P0 — leaving it standing open at a level the next reader will learn to discount — or
promote a deferred P3 whose corner case the batch made the default condition. The drift is
invisible from title and body; only re-reading the issue's cited code against merged `HEAD`
reveals it. Separately, when any re-score does happen, nothing requires recording why, so a
bare label flip becomes an unexplained durable record.

Three questions had to be answered together:

1. **Scope.** Step 7's "traceable to this batch" test is too narrow — an issue can be
   satisfied by a merge without having been filed by the run that merged it.
2. **Cost.** Re-scoring is a per-issue source read against merged `HEAD`, not a label query;
   a title-level pass cannot see either failure mode.
3. **Authority.** Rewriting a priority mutates issues the campaign chose not to own.

## Decision

Campaign keeps a **deferral ledger**: one manifest section listing every issue it filed and
the operator declined at step 7, with its priority at filing and rescore outcome. The ledger
is not a Queue section: a declined issue is never enqueued, quested, or fixed, and decline
semantics are unchanged. Issues closed not planned at step 4 stay out of it — closure plus
the annotation's reconsideration condition already owns the world-changed case for a closed
issue, and a rescore could only ever classify it `not-open`.

After the enqueue decision resolves — and again after any later merges — campaign runs a
**rescore pass** over ledger rows still pending. It reads each deferred issue's current labels
and the code it cites at merged `HEAD`, triage-style, then classifies the finding: unchanged,
satisfied by the batch, or promoted by the batch. Scores go stale: any row whose recorded date
precedes the newest dated merge entry in the Outcomes log resets to `pending`, so every later
merge re-opens the pass. When no merge entry postdates a row's filing, it is marked
`not-required` without further work.

**Scope** is the campaign's own deferrals. An issue satisfied by the batch but filed outside
the campaign stays out of scope: the campaign cannot enumerate foreign deferrals without an
unbounded tracker sweep, and it has no authority to mutate issues it did not file. The
campaign-owned set covers both observed failure modes, because both were campaign filings.

**Authority** sits behind the operator. The pass itself is read-only; flipping a priority
label or posting a comment requires one explicit operator confirmation, the same gate step 7
already requires before enqueueing.

**Repairs are comments, not body rewrites.** An applied change posts one rationale-bearing
annotation comment — prior level, new level, evidence citations, the merge that changed the
picture — and the comment must be verified before the label flips. A priority move without
its recorded why is a defect, on the tracker exactly as it would be on a pull request.

**Drained stays manifest-computable.** The drained definition gains one conjunct — no ledger
row left `pending` — and a rescore that cannot complete blocks completion like any other
unreconciled state, never silently reporting drained past it.

## Consequences

- A satisfied P0 does not survive the campaign as an open alarm, and a batch-promoted corner
  case is re-levelled before the campaign claims done. Priority levels keep their meaning for
  the next reader.
- Every applied re-score carries its reasoning in the issue's comment history; months later
  the label flip is auditable.
- Deferred issues gain one orchestrator turn per rescore pass. This is bounded by the ledger:
  only campaign-declined filings, only rows a merge has left stale or unscored.
- The manifest grows one small table with a recognized outcome vocabulary, validated like the
  occurrence table it mirrors.
- Foreign deferrals — issues another run or reporter filed that this batch happened to satisfy
  — remain unrescored by design. Surfacing those is future work for a tracker-wide sweep, not
  a campaign contract.

## Considered & rejected

**Rescore only issues traceable to this batch, step 7's existing test.** verified: the
observed run's satisfied P0 was satisfied by a wave other than the one that filed it, so the
filing run's own traceability test would have skipped it. Scope is every issue this campaign
filed and had declined.

**Ledger closed-not-planned closures too.** rejected: a verified closure means the rescore can
only ever classify the row `not-open`, so the rows would be write-only state; the
`WORK:CLOSE-NOT-PLANNED` annotation's reconsideration condition is the durable record that
covers a batch changing a closed issue's cost/benefit picture.

**Rescore every not-planned issue in the tracker, not just this campaign's filings.** rejected:
enumerating foreign deferrals needs an unbounded all-state sweep per campaign, and mutating
issues the campaign did not file exceeds the authority its operator confirmation covers.
Surfacing those belongs to a tracker-wide sweep, not a campaign contract.

**Rescore automatically and skip the operator gate.** rejected: flipping a priority label
mutates durable records on issues the campaign chose not to own — the same reason step 7
already gates enqueueing behind explicit confirmation.

**Apply the repair as a body edit so the issue reads correctly at a glance.** rejected: the
body is the original framing and must stay legible; comments preserve it and the annotation
convention already makes a rationale comment durable and queryable.

**Record the rescore why only in the manifest.** rejected: the manifest is private campaign
state and stays out of git; the label on the public issue would remain an unexplained durable
record to every reader who is not the campaign.
