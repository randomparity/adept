# Publication cleanup reports and continues — design

Issue: [#306](https://github.com/randomparity/adept/issues/306)
Decision record: [ADR 0056](../../adr/0056-publication-cleanup-reports-and-continues.md), which
holds the problem, the decision, and the rejected alternatives. This spec holds the resulting
behaviour, the boundaries it touches, and how it is tested.

## Behaviour

The ADR's Decision states the record contract and is not restated here. Three details it does not
carry:

- **The partition is by what is left on disk**, not by the disposer's exit status. A disposer that
  errors after removing a path leaves nothing to retain, and it lands in the disposed record —
  which is how the previous implementation computed its remaining set too.
- **Owned order** is the required review (in `required` mode), the summary, the generated body,
  then the payload last. Each record lists its own subset in that order, joined by single spaces.
  An all-succeed run's ledger is byte-identical to today's, so `PFR-1`, `PFR-15` and `PFR-16` pin
  the unchanged happy path.
- **Membership is decided by whole-line comparison.** An owned path may contain spaces, so a
  consumer never splits a record on whitespace; it knows the owned paths and their order, so it
  reconstructs the exact record text for the partition under test and compares whole lines.

### The exit trap

`finish_body_lifecycle` fails a zero-status run whose generated body survives, to catch a silent
leak. Two changes:

- A body named in the `review-publication-undisposed:` record is not silent, so `dispose()`
  clears the tracked body path once that record is read back. Without this the trap's `return 1`
  would turn the reported run back into exit 1 — measured on bash 3.2.57: a trap returning 1 sets
  the exit status of an otherwise-successful script to 1.
- The trap opens with `local exit_status` and `exit_status=$?` on separate lines. The bare
  `local` is itself a successful command, so it sets `$?` to 0 before the assignment reads it:
  the trap believes every run succeeded. Measured on the base commit, a failing run printed
  `publish-forge-review: successful publication left its body behind` beside its real error.
  `local exit_status=$?` on one line fixes it, because the expansion runs before `local` does.
  This second change is an **independent** repair of a pre-existing false message, not something
  this design requires; it is carried here only because it lands on the same trap the first change
  edits, and the scope boundary is worth seeing rather than inferring.

### Consumers

- `skills/quest/SKILL.md` step 5 (`publication-verified` resume) and step 8 (post-helper
  verification) assert against the closing **records** — either or both — requiring their union
  to own all and only the former paths in owned order. Step 8 continues on an `undisposed` record
  instead of parking, and does **not** carry the retained paths anywhere new: the private ledger
  and the helper's stderr already name them, the `publication-verified` handoff format admits no
  new field, and the step-9 hand-off is a public annotation that must not carry private workspace
  paths at all.
- `skills/quest/SKILL.md`'s closing sentence of step 8, `Carry that URL into step 9;
  `$return-to-town` needs no forge-scratch cleanup.`, stops being true once an `undisposed` record
  exists — the review, summary, and body are still in the workspace. It gains a clause saying so
  and naming the operator as the one who removes them, since `$return-to-town` is outside this
  change's surface.
- `skills/quest/SKILL.md`'s human-authorized recovery predicates add "no
  `review-publication-undisposed:` line": that record is as much proof of a completed
  publication as the disposed one, and recovering past it would post a second comment.
- `skills/forge/SKILL.md`'s retention-suppression clause accepts either record naming the
  range's exact review path, for the same reason.

## Trust boundaries

No data crosses a new trust level and no entry point is added. Two existing boundaries sit next
to the change:

- **Helper inputs → the public GitHub comment.** Unchanged. Validation, size bounds,
  UTF-8/NUL/CR rejection, outer-marker rejection, and `check-public-safety.sh` all run before
  composition and before any request. Disposal happens strictly after that boundary is crossed.
- **Private scratch content at rest.** Retained paths live in the mode-0700, git-ignored forge
  workspace, which the helper already required to be private before publishing. The old failure
  path retained those same paths; only the exit status differs. What changes is that a human is
  no longer forced to notice, so the stderr warning and the private ledger record are the
  compensating disclosure. Neither reaches a public annotation, which is deliberate: the paths
  are absolute host paths and the step-9 hand-off is a public comment.

Out of scope: concurrent publishers (ADR 0048 already records that the GitHub issue-comment API
offers no atomic create-if-absent), and the disposer's own guarantees about where a trashed file
lands.

## Testing

Three contracts in `tests/fixtures/quest/publish-forge-review-test.sh`; the plan carries the case
text.

- **Partial failure** (`PFR-6`'s third block, which today pins the old nonzero contract for
  `FAIL_TRASH_ON=summary.md` and is therefore changed deliberately, not deleted or weakened):
  the run completes, the disposed record names the review and body **and not the summary**, and
  the undisposed record names the summary. The negative half is load-bearing — without it a
  helper that reports a retained path as disposed passes.
- **Total failure** (a new case): the run completes, no disposed record, one undisposed record
  owning all three paths in owned order, every path on disk, and no false `successful publication
  left its body behind`.
- **Exit-guard status** (`PFR-4`): a pre-publication failure that retains the body does not print
  that message. The guard's positive direction — a zero-status run with an unrecorded surviving
  body — is unreachable without new fault-injection machinery, so it is verified by controlled
  fault during implementation rather than by a permanent fixture mode.

The assertions carrying the new contract are verified to bite by the three inversions the plan's
Task 1 step 9 prescribes — each applied once, red observed, reverted.

## Guardrails

`just verify` on the branch, and `.claude-plugin/plugin.json` bumped `4.1.1` → `4.1.2` (bug fix;
the bump is required by ADR 0022).
