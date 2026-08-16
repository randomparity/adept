# 0018 — Quest claims via exclusive repo-label creation

## Status

Accepted (2026-08-16)

## Context

Issue #125: two `$quest` agents can observe the same `status:ready` issue,
each swap it to `status:in-progress` (idempotent), each mint and validate its
own `WORK:SCOPE` token, and proceed on duplicate branches and PRs. No
operation in the workflow is exclusive, so nothing can fail for exactly one
of two concurrent claimants. The issue requires a claim protocol built on an
operation with exclusive or compare-and-set-like semantics, and rules out a
label swap or append-only comment as sufficient. ADR 0004 established
`$seek-quest`'s occupancy signals; a claim adds one signal to that set
without replacing any.

## Decision

A claim on issue `<N>` is a **repository label** named `quest-claim/<N>`,
never applied to the issue. Acquisition is `gh label create`, whose
unique-name constraint is the exclusive operation: creating a label that
exists fails with HTTP 422 `already exists`, and a live probe (three rounds
of eight concurrent creates against this repository) produced exactly one
winner per round and 21 deterministic `already exists` failures — no second
success, no anomalous outcome. The label description is
`<token>;<login>;<epoch>`; the token is the `WORK:SCOPE` scope token, binding
claim, charter, and issue. Five operations — acquire, verify, release,
recover, list — live in `quest-log`'s tracker engine so every skill shares
one implementation and exit taxonomy; a new exit class reports a live foreign
claim with a structured holder payload.

Liveness is a rule over claim age and issue status: `CLAIM_GRACE` 600 s
covers the acquire→status-swap window; `CLAIM_TTL` 12 h bounds a dead
in-flight quest's occupancy. Stale claims are recovered by
`claim-recover --older-than`; operator decisions by `claim-recover --force`,
the structural carrier of an authorization a script cannot read out of a
prompt. `$quest` verifies its claim immediately after acquiring (before any
issue mutation), after the scope-charter readback, before branch creation,
and before pushing; a lost gate halts the quest with no further mutation of
the issue.

## Consequences

- GitHub has no conditional delete, so release and recover delete-then-act.
  The interleaving that matters: two recoverers race one stale claim, the
  slower one's delete lands after the faster one's re-create, and the slower
  one then re-creates and owns the issue. The displaced quest's immediate
  post-acquire verify observes a foreign claim — or, inside the narrow
  delete/recreate gap, a transient not-found — and either way it halts
  having mutated no issue or repository state; it may re-acquire once the
  race settles. A quest halted at a later gate may hold a local branch with
  committed work: the halt report names it, and the operator disposes of it —
  the branch may carry salvageable work, so the protocol neither deletes it
  nor pretends it away. An owner
  cannot silently lose a live claim to the staleness path — a live claim
  fails every `--older-than` guard — so the residual case is an operator
  `--force` landing mid-run, which is an operator-visible conflict, not a
  protocol failure. Accepted.
- Nothing here serializes the truly irreversible steps — pushes are
  deletable, PRs closeable, and merges belong to the human or orchestrator,
  outside the quest's gates. The protocol's guarantee is that duplicate
  *work* stops before design, not that deletes are serialized.
- A label whose description does not parse as `<token>;<login>;<epoch>` is
  treated as a foreign claim, never as evidence of ownership. Malformed
  entries surface in `claim-list` with null fields and are cleared by
  `claim-recover --force` or a manual `gh label delete` — their unparseable
  epoch puts them outside `--older-than` recovery.
- Claims persist past hand-off and merge until `$resurrection` — an
  operator-run, between-runs sweep — collects them. A claim on a closed or
  non-in-flight issue is stale by definition, so residue is inert except
  that `$seek-quest` drops claimed candidates without judging liveness: a
  stale claim hides a candidate from recommendation until the next sweep.
  Conservative direction, accepted.
- Claim tokens constrain the `WORK:SCOPE` token grammar to
  `[A-Za-z0-9-]{1,32}`; `$quest` mints `q<N>-<8 hex>`. The issue number
  scopes the namespace, so a collision needs two claims on the *same* issue
  drawing the same 32-bit value (~10^-9 per pair); a colliding claim reads
  as one's own, so the entropy floor stands. Clocks: epochs are
  self-asserted and hosts may skew; the 600 s grace and 12 h TTL absorb any
  plausible skew.
- The label namespace carries one transient `quest-claim/<N>` entry per
  claimed issue, visible in the labels UI, never applied to issues.

## Considered & rejected

**Git-ref compare-and-set** (`git push origin <sha>:refs/quest-claims/<N>`).
Genuinely atomic — the one alternative whose exclusivity was never in doubt,
a property the label constraint now matches with probe evidence. Rejected on
the remaining grounds: metadata lives in plumbing objects (commit-tree,
fetch-by-ref to verify); stale recovery needs delete-then-recreate through
the same non-atomic window, or a force push, which operator policy denies;
refs are invisible in every UI; and it builds a second coordination substrate
beside the tracker engine every skill already shares.

**Claim comment plus detection window.** Rejected by the issue itself:
append-only comments have no exclusive operation, and a re-read delay shrinks
the race without closing it.

**GitHub issue lock API** (`PUT .../issues/<N>/lock`). Rejected: locking is
idempotent (re-locking returns 204, so it is not an exclusive operation);
worse, a locked issue rejects comments, which are the workflow's own
annotation channel — a claiming quest could not post its `WORK:SCOPE`.
Locks also carry no token metadata.

**Assignee-based claims.** Rejected: assignment is not exclusive (two
concurrent assignments both succeed) and binds no token. Assignees stay an
occupancy signal for human-assigned work, per ADR 0004.

**GitHub Projects v2 field as the claim slot.** Rejected: field updates are
GraphQL mutations with no documented conditional-write semantics, and the
primitive would add a second state store and a Projects-board dependency for
no gain over the label constraint.

**Apply the claim label to the issue.** Rejected: applying is idempotent,
not exclusive — timeline noise without the one property the design needs,
which repo-level existence already provides.

**The label description as the CAS slot** (quests `gh label edit` the
description, detecting conflict by read-before-write). Rejected: label edit
is an unconditional PATCH — last writer wins, and read-before-write
comparison is the append-only-comment failure in another costume.

**External coordination store** (a KV service, or the GitHub Actions
cache). Rejected: a second infrastructure dependency for a protocol that
must run from any workstation with `gh` credentials, against the repo's
no-long-lived-processes anatomy rule — and the label constraint's probed
exclusivity makes it unnecessary.

**Do nothing (rely on the duplicate-branch conflict).** Rejected: the
conflict surfaces after both quests have scoped, and later `WORK:SCOPE`
annotations supersede each other under latest-complete-wins without stopping
either quest — the failure the issue reports.

## Provenance

Decided while designing the implementation of issue #125
(`docs/workflow/specs/2026-08-16-quest-claim-exclusion-design.md`); the
exclusive-primitive choice was confirmed by the operator in the design
dialogue over the git-ref alternative. Exclusivity evidence: three rounds of
eight concurrent `gh label create` calls against this repository,
2026-08-16.
