## What this does

`$trial-loop`'s exit payloads — the deferral list with owning record paths, the outstanding notes, the confirmed claim list — had no writable path into either destination ADR 0021 names. The `WORK:REVIEW` publication helper composed exactly three parts (marker, summary, forge review) with no fourth slot, and nothing edited the PR body after `$deliver` created it. A run following `$quest` step 6 either dropped the lists silently or appended them to the capped summary file after the handoff had gone terminal.

Both destinations are now writable:

**`skills/quest/scripts/publish-forge-review`** takes an optional seventh `PAYLOAD` argument. It is validated on the same code path as the summary — private mode 0600, `MAX_SOURCE_BYTES`, UTF-8, NUL, carriage return, whole-line outer markers — via a shared `require_publishable_source`, composed verbatim under a `## Review exit payloads` heading between the forge review and the outer sentinel with the review's final-newline guard, disposed with the other inputs in both modes, and named in the ledger's disposal record. Omitted or empty keeps every existing publication byte-identical; validation still precedes composition, so an invalid or oversized payload fails before any comment write and before the terminal handoff phase.

**`skills/quest/SKILL.md`** step 8 gains the named PR-body write moment: after `$deliver` reports the verified PR, the run composes the payload file once beside the ledger and appends its contents under the same heading with one byte-verified `gh pr edit --body-file` — before the `publication-in-progress` handoff rewrite, so the write never happens in the terminal parked phase. Step 6 hands the loop's disclosure to these two destinations instead of the keep-with-resume-facts workaround from #141/#160.

ADR 0028 records the decision, amends ADR 0021's payload-destination ruling, and supersedes the not-to-be-edited freeze that plan 2026-08-18-review-summary-named-exit (anatomy rule 2) placed on the helper and its fixture. `skills/quest-log/SKILL.md`'s annotation-shape paragraph names the new optional section for whole-line-anchored consumers. Version bump per ADR 0022.

Closes #159

