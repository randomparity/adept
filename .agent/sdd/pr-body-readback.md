## What this does

`$trial-loop`'s exit payloads — the deferral list with owning record paths, the outstanding notes, the confirmed claim list — had no writable path into either destination ADR 0021 names. The `WORK:REVIEW` publication helper composed exactly three parts (marker, summary, forge review) with no fourth slot, and nothing edited the PR body after `$deliver` created it. A run following `$quest` step 6 either dropped the lists silently or appended them to the capped summary file after the handoff had gone terminal.

Both destinations are now writable:

**`skills/quest/scripts/publish-forge-review`** takes an optional seventh `PAYLOAD` argument. It is validated on the same code path as the summary — private mode 0600, `MAX_SOURCE_BYTES`, UTF-8, NUL, carriage return, whole-line outer markers — via a shared `require_publishable_source`, composed verbatim under a `## Review exit payloads` heading between the forge review and the outer sentinel with the review's final-newline guard, disposed with the other inputs in both modes, and named in the ledger's disposal record. Omitted or empty keeps every existing publication byte-identical; validation still precedes composition, so an invalid or oversized payload fails before any comment write and before the terminal handoff phase.

**`skills/quest/SKILL.md`** step 8 gains the named PR-body write moment: after `$deliver` reports the verified PR, the run composes the payload file once beside the ledger and appends its contents under the same heading with one byte-verified `gh pr edit --body-file` — before the `publication-in-progress` handoff rewrite, so the write never happens in the terminal parked phase. Step 6 hands the loop's disclosure to these two destinations instead of the keep-with-resume-facts workaround from #141/#160.

ADR 0028 records the decision, amends ADR 0021's payload-destination ruling, and supersedes the not-to-be-edited freeze that plan 2026-08-18-review-summary-named-exit (anatomy rule 2) placed on the helper and its fixture. `skills/quest-log/SKILL.md`'s annotation-shape paragraph names the new optional section for whole-line-anchored consumers. Version bump per ADR 0022.

Closes #159


## Review exit payloads

Outstanding notes (from the branch review, none blocking):

- note: one transient suite failure of tests/fixtures/quest-log/tracker-test.sh
  under `just verify` (profile_claim_acquire guard scan); it passed on rerun,
  in isolation in the worktree, and on clean main, and passed inside the
  pre-push verify-push run. Observed once, not reproduced; no repo change
  claims to fix it. Recorded here so the observation has an owner on the
  record.

Confirmed claim list:

- confirmed: an omitted or empty seventh argument keeps every existing
  publication byte-identical (PFR-1, PFR-15 compare full comment bodies).
- confirmed: a carried payload is validated on the summary's code path before
  any comment write, and validation failure retains every input and creates
  no body (PFR-16).
- confirmed: the payload is composed verbatim between the forge review and the
  outer sentinel, and the sentinel stays whole-line outer without a trailing
  newline (PFR-14, PFR-17).
- confirmed: disposal owns the payload last in both modes and names it in the
  ledger record (PFR-14).
- confirmed: no deferral records were taken on this branch; every review
  finding was fixed in 5de1313.

