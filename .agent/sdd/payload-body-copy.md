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
