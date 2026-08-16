# 0018 — Quest claims via exclusive repo-label creation

## Status

Accepted (2026-08-16)

## Context

Issue #125: two `$quest` agents can observe the same `status:ready` issue,
each swap it to `status:in-progress` (idempotent), each mint and validate its
own `WORK:SCOPE` token, and proceed on duplicate branches and PRs. No
operation in the workflow is exclusive, so nothing can fail for exactly one
of two concurrent claimants. The issue requires a claim protocol built on an
operation with exclusive or compare-and-set-like semantics, and explicitly
rules out a label swap or append-only comment as sufficient. ADR 0004
established `$seek-quest`'s occupancy signals; a claim adds one more signal
to that set without replacing any.

## Decision

A claim on issue `<N>` is a **repository label** named `quest-claim/<N>`,
never applied to the issue. Acquisition is `gh label create`, whose
server-side unique-name constraint is the exclusive operation: of two
concurrent creators exactly one succeeds. The label description (100-character
budget, live-probed) is `<token>;<login>;<epoch>`; the token is the
`WORK:SCOPE` scope token, which binds claim, charter, and issue. The five
operations — acquire, verify, release, recover, list — are tracker-engine
operations in `quest-log`'s `tracker.sh`, so every skill shares one
implementation and exit taxonomy. A new exit class `EXIT_CONFLICT=6` reports
a live foreign claim with a structured holder payload on stderr.

Liveness is a rule over claim age and issue status, with two constants:
`CLAIM_GRACE` 600 s (covers the acquire→status-swap window) and `CLAIM_TTL`
12 h (bounds a dead in-flight quest's occupancy). Stale claims are recovered
by `claim-recover --older-than`; operator decisions are recovered by
`claim-recover --force`, the structural carrier of an authorization the
script cannot read out of a prompt. `$quest` verifies its claim after
scoping, before branch creation, and before pushing; a lost gate halts the
quest with no further mutation of the issue.

## Consequences

- Release and recover delete-then-act; GitHub has no conditional delete.
  The residual race (two recoverers, or a recoverer racing a fresh claim) is
  bounded by the verify gates: a quest whose claim was deleted under it
  detects the loss before any irreversible step. Documented, accepted.
- Claims persist past hand-off and merge until `$resurrection` collects
  them; a claim on a closed or non-in-flight issue is stale by definition,
  so the residue is inert and self-healing.
- Claim tokens constrain the `WORK:SCOPE` token grammar to
  `[A-Za-z0-9-]{1,32}`; `$quest` mints `q<N>-<8 hex>`. Tokens minted before
  this protocol are unaffected — they were never claims.
- `$seek-quest` drops any ready candidate carrying a claim without judging
  liveness; a stale claim hides a candidate from recommendation until
  `$resurrection` sweeps it. Conservative direction, accepted.
- Epoch seconds in the description rather than ISO-8601: portable arithmetic
  across GNU/BSD `date`, shorter field, at the cost of human readability in
  the label UI.
- The label namespace carries one transient `quest-claim/<N>` entry per
  claimed issue. `gh label list` output and the labels UI show them; they
  are never applied to issues, so issue timelines are untouched.

## Considered & rejected

**Git-ref compare-and-set** (`git push origin <sha>:refs/quest-claims/<N>`).
Genuinely atomic, and invisible to ordinary fetches. Rejected: claim metadata
lives in plumbing objects (commit-tree, fetch-by-ref to verify); stale
recovery needs delete-then-recreate against the same non-CAS window, or a
force push, which operator policy denies; refs are invisible in every UI; and
it builds a second, git-side coordination substrate beside the tracker engine
every skill already shares instead of extending the one that exists.

**Claim comment plus detection window** (post a claim comment, re-read after
a delay, resolve collisions latest-wins). Rejected by the issue itself:
append-only comments have no exclusive operation, so two claimants can both
pass a re-read that either could have raced; the window makes every quest
pay a delay to shrink, not close, the race.

**Assignee-based claims.** Rejected: assignment is not exclusive or
compare-and-set — two concurrent assignments both succeed — and it carries no
token binding, so a foreign `WORK:SCOPE` still cannot be attributed.
`$seek-quest` already treats assignees as an occupancy signal for
human-assigned work; that stays.

**GitHub Projects v2 field as the claim slot.** Rejected: field updates are
not conditional (no If-Match write), so the operation is not exclusive; it
also adds a second state store and a heavier API surface for no gain over
the label constraint.

**Apply the claim label to the issue.** Rejected: applying is idempotent,
not exclusive, so it adds timeline noise without adding the only property
the design needs, which repo-level existence already provides.

**Do nothing (rely on the duplicate-branch conflict).** Rejected: the
conflict surfaces after both quests have scoped and chartered, so duplicate
work is already spent, and later `WORK:SCOPE` annotations supersede each
other under latest-complete-wins without stopping either quest — the failure
the issue reports.

## Provenance

Decided while designing the implementation of issue #125
(`docs/workflow/specs/2026-08-16-quest-claim-exclusion-design.md`); the
exclusive-primitive choice was confirmed by the operator in the design
dialogue over the git-ref alternative.
