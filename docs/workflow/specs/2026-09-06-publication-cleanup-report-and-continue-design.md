# Publication cleanup reports and continues — design

Issue: [#306](https://github.com/randomparity/adept/issues/306)
Decision record: [ADR 0056](../../adr/0056-publication-cleanup-reports-and-continues.md), which
holds the problem, the decision, and the rejected alternatives. This spec holds the resulting
behaviour, the boundaries it touches, and how it is tested.

## Behaviour

The ADR's Decision states the record contract and is not restated here. Three details it does not
carry:

- **The partition is by what is left on disk**, never by the disposer's exit status. One that
  errors after removing a path leaves nothing to retain; one that reports success without removing
  it leaves something that does. The disposer's status is discarded, and only `[ -e ]` decides —
  which is how the previous implementation computed its remaining set too.
- **Owned order** is the required review (in `required` mode), the summary, the generated body,
  then the payload last. Each record lists its own subset in that order, joined by single spaces.
  An all-succeed run's ledger is byte-identical to today's, so `PFR-1`, `PFR-15` and `PFR-16` pin
  the unchanged happy path.
- **Membership is decided by whole-line comparison.** An owned path may contain spaces, so a
  consumer never splits a record on whitespace; it knows the owned paths and their order, so it
  reconstructs the exact record text for the partition under test and compares whole lines. The
  generated body is the one owned path whose name the consumer does not already hold: it is the
  record text left once the known paths and their separators are removed, and it must be the
  ledger directory plus `/.publish-forge-review.` and six characters.

### The exit trap

`finish_body_lifecycle` fails a zero-status run whose generated body survives, to catch a silent
leak. One change, and it is in `dispose()` rather than in the trap: a body named in the
`review-publication-undisposed:` record is not silent, so `dispose()` clears the tracked body path
once that record is read back. Without this the trap's `return 1` would turn the reported run back
into exit 1 — measured on bash 3.2.57, a trap returning 1 sets the exit status of an
otherwise-successful script to 1. The trap itself is untouched.

An adjacent defect in that trap is **deliberately not fixed here**: it opens with `local
exit_status` and `exit_status=$?` on separate lines, and the bare `local` is itself a successful
command, so it sets `$?` to 0 before the assignment reads it. Measured on the base commit, a
failing run therefore printed `publish-forge-review: successful publication left its body behind`
beside its real error. `local exit_status=$?` on one line would fix it, but it is a pre-existing
false message with a different root cause, this design does not need it, and the scope audit held
it out of the approved surface. It is tracked as issue #313 instead.

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

- **The private ledger as republication authority.** Both closing records are read by `$quest`
  and `$forge` as proof a publication already happened, so the ledger now gates republication as
  well as recording it. Its controls are unchanged and stated here because the change raises what
  they carry: `dispose()` is the only writer of either record, it writes only after the verified
  line, and `append_ledger`'s whole-line tail readback is what stops a truncated or malformed
  record from being accepted. The ledger is a mode-0600 regular file the helper validates before
  writing.

Out of scope: concurrent publishers (ADR 0048 already records that the GitHub issue-comment API
offers no atomic create-if-absent), and the disposer's own guarantees about where a trashed file
lands.

## Testing

Three contracts in `tests/fixtures/quest/publish-forge-review-test.sh`; the plan carries the case
text. One rewrites `PFR-6`'s third block and two are new cases; every other case, `PFR-4`
included, is untouched.

- **Partial failure** (`PFR-6`'s third block, which today pins the old nonzero contract for
  `FAIL_TRASH_ON=summary.md` and is therefore changed deliberately, not deleted or weakened):
  the run completes, the disposed record names the review and body **and not the summary**, and
  the undisposed record names the summary. The negative half is load-bearing — without it a
  helper that reports a retained path as disposed passes.
- **Total failure** (a new case): the run completes, no disposed record, one undisposed record
  owning all three paths in owned order, every path on disk, and no false `successful publication
  left its body behind`.
- **Partition basis** (a new case): a disposer that removes a path and then fails puts it in the
  disposed record; one that reports success without removing the generated body puts that body in
  the undisposed record and still reports no silent leak. Without this the filesystem check is
  unpinned — the branch review reproduced a short-circuiting partition that passed every other
  case.

Every assertion carrying the new contract is verified to bite by inverting the helper once and
observing red: the retained-path guard, the disposed record naming a retained path, and both
halves of the partition basis.

## Guardrails

`just verify` on the branch, and `.claude-plugin/plugin.json` bumped `4.1.2` → `4.1.3` (bug fix;
the bump is required by ADR 0022).
