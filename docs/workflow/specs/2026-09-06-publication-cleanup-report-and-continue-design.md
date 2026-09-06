# Publication cleanup reports and continues — design

Issue: [#306](https://github.com/randomparity/adept/issues/306)
Decision record: [ADR 0056](../../adr/0056-publication-cleanup-reports-and-continues.md), which
holds the problem, the decision, and the rejected alternatives. This spec holds the resulting
behaviour, the boundaries it touches, and how it is tested.

## Behaviour

Nonzero exit from `skills/quest/scripts/publish-forge-review` means it did not publish. After
`review-publication-verified: <URL>` reaches the ledger, disposal is best-effort: the helper
attempts every owned path, warns on stderr naming the retained ones, records the outcome, prints
the verified comment URL, and exits 0.

`dispose()` partitions the owned paths and writes at most two records:

- `review-publication-disposed: <paths>` — emitted when at least one path was disposed.
- `review-publication-undisposed: <paths>` — emitted when at least one path remains.

Each names exactly its own paths, in the helper's owned order: the required review (in
`required` mode), the summary, the generated body, then the payload last. No path appears in
both, and their union is all and only the owned paths — the completeness property `$quest`
already asserts against the single record. An all-succeed run's ledger is byte-identical to
today's.

Every path is attempted rather than stopping at the first error: a filesystem that refuses one
usually refuses all of them, while one odd path must not strand the rest. A ledger append
failure inside either record stays fatal — the ledger is the only durable statement of what
happened.

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

### Consumers

- `skills/quest/SKILL.md` step 5 (`publication-verified` resume) and step 8 (post-helper
  verification) assert against the closing **records** — either or both — requiring their union
  to own all and only the former paths in owned order. Step 8 carries the retained paths into
  the hand-off instead of parking.
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
  no longer forced to notice, so the stderr warning, the ledger record, and the hand-off are the
  compensating disclosure.

Out of scope: concurrent publishers (ADR 0048 already records that the GitHub issue-comment API
offers no atomic create-if-absent), and the disposer's own guarantees about where a trashed file
lands.

## Testing

In `tests/fixtures/quest/publish-forge-review-test.sh`:

- **PFR-6's third block** currently pins the old contract for `FAIL_TRASH_ON=summary.md` —
  nonzero exit, no disposal record, retained paths. It is rewritten for the same injected fault:
  exit 0, the comment URL on stdout, review and body disposed, summary retained,
  `review-publication-disposed:` naming the review and body, `review-publication-undisposed:`
  naming the summary, and the warning naming it. This test encodes the contract being changed,
  so it is changed deliberately rather than deleted or weakened.
- **A new case** covers total disposer failure: exit 0, no `review-publication-disposed:` line,
  one `review-publication-undisposed:` line owning all three paths in owned order, every path
  still on disk, and no false `successful publication left its body behind`.
- **PFR-4** gains one assertion: a pre-publication failure that retains the body must not print
  `successful publication left its body behind`. The guard's positive direction — a zero-status
  run with an unrecorded surviving body — is unreachable without new fault-injection machinery,
  so it is verified by controlled fault during implementation rather than by a permanent fixture
  mode.
- **PFR-1, PFR-15 and PFR-16** already pin the happy path and must pass untouched, which is what
  proves the change is confined to the failure path.

Each new assertion is verified to bite by inverting the helper's behaviour once, observing red,
and reverting.

## Guardrails

`just verify` on the branch, and `.claude-plugin/plugin.json` bumped `4.1.1` → `4.1.2` (bug fix;
the bump is required by ADR 0022).
