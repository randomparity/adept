# Quest claim exclusion — design

Issue: [#125 — Prevent concurrent quests from claiming the same issue](https://github.com/randomparity/adept/issues/125).
Scope charter: `WORK:SCOPE` token `quest125-20260816-26f4f2a7` on the issue.
ADR: [0018](../adr/0018-quest-claim-via-exclusive-repo-label.md).

## Problem

Two `$quest` agents can begin work on the same ready issue concurrently. The
status-label swap is idempotent, each quest mints and validates only its own
`WORK:SCOPE` token, and the duplicate-branch check fires only after both
quests have scoped. Nothing anywhere answers "does another quest own this
issue right now?" with an operation that can fail for exactly one of two
concurrent askers.

## Goal

Exactly one quest holds implementation authority over an issue at a time.
Authority is a **claim**: a repo label whose creation is an exclusive
operation. A quest that finds a live foreign claim identifies the conflict
and stops, or enters an explicit recovery path, before design, branch
creation, or implementation. A quest never overwrites, supersedes, adopts,
or silently continues beside a foreign scope identity. Claim ownership and
liveness stay attributable across resume and reconciliation, for `$campaign`
dispatch and direct near-simultaneous `$quest` invocations alike.

## Non-goals

- Claims for non-quest workflows, cross-repo claims, GitHub Projects state.
- Protecting against a malicious collaborator (see threat model).
- Changing `$return-to-town` or `$deliver`: no release-on-merge edit. A
  merged issue closes; a claim on a closed issue is stale by definition and
  `$resurrection` garbage-collects it.
- Changing the `feat/<slug>-<N>` branch convention ADR 0004's occupancy
  signals depend on. The claim is an additional signal, not a replacement:
  branches and PRs remain occupancy evidence for work that predates or
  bypasses the claim protocol.

## The claim

A claim is a **repository label** named `quest-claim/<N>` where `<N>` is the
issue number. It is never applied to the issue; its existence on the repo is
the claim.

- **Exclusive acquisition.** `gh label create` enforces a server-side
  unique-name constraint: of two concurrent creates, exactly one succeeds.
  This is the exclusive operation the issue requires; a label swap on the
  issue or an append-only comment cannot provide it.
- **Description grammar** (100-character budget, live-probed
  2026-08-16): `<token>;<login>;<epoch>` — three semicolon-separated fields,
  nothing else. `token` is the quest's scope token, constrained to
  `[A-Za-z0-9-]`, 1–32 characters; going forward `$quest` mints short tokens
  of the form `q<N>-<8 lowercase hex>` (e.g. `q125-26f4f2a7`). `login` is the
  authenticated account that claimed (`gh api user --jq .login`). `epoch` is
  is the claim time as UTC epoch seconds (`date -u +%s`) — chosen over ISO-8601
  because epoch arithmetic is portable where GNU/BSD `date` parsing flags
  diverge, and the field is shorter. Epochs are self-asserted: the protocol
  assumes host clock skew ≤ 300 s (half the grace window); hosts with worse
  skew will misjudge liveness, an environmental invariant rather than a
  protocol flaw.
- **Binding.** The claim token **is** the `WORK:SCOPE` annotation token. The
  label binds the claim to the repo; the annotation binds it to the issue and
  to the charter; the label timeline recipe already binds the status
  transition. Producer identity is the token (an unguessable-per-run value)
  plus the claiming login; the token is the discriminator, because every
  session on one host shares one login.
- **Staleness.** Two constants, defined once in `quest-log`:
  `CLAIM_GRACE` = 600 seconds and `CLAIM_TTL` = 43200 seconds (12 h). A claim
  is *live* when its age < `CLAIM_TTL` **and** (its age < `CLAIM_GRACE` **or**
  the issue carries an in-flight status: `in-progress`, `in-review`,
  `awaiting-merge`). Anything else is *stale*. The grace window covers the
  seconds between acquisition and the status swap; without it a young claim
  on a not-yet-swapped issue would read as inconsistent. The TTL bounds how
  long a dead quest's claim can occupy an issue whose status still reads
  in-flight. A claim on a closed issue is stale regardless of age.

## Tracker operations

The claim protocol lives in the tracker engine
(`skills/quest-log/assets/tracker.sh`) as five new operations, implemented by
the github profile (`profiles/github.sh`). This is the existing home for
tracker writes; every calling skill gets one implementation, one exit
taxonomy, and one fixture pattern. Rule-2 bar: the acquire/recover sequences
are deterministic compare-and-act operations with exact error classification
that a model performs inconsistently inline — the same bar
`create-verified-issue.sh` clears.

New exit class: `EXIT_CONFLICT=6` — a live foreign claim holds the issue.
Conflict payloads are structured JSON on **stderr** (the engine's convention:
stdout carries success payloads only), shaped
`{"error":"conflict","holder":{"token":...,"producer":...,"at":...}}`.

- `claim-acquire --target O/N <issue> --token <t> --producer <login>`
  Validates the id (`github_require_id`) and token grammar. Creates the
  label. On success: stdout `{"claimed":true,...}`, exit 0. On HTTP 422 the
  response is *not* trusted by message alone — validation failures share the
  status. The discriminator is a read-back: the label exists → token match
  means this is a retry of our own lost-response create, so stdout
  `{"claimed":true,"recovered":"self",...}`, exit 0, and token mismatch is
  exit 6 with the holder payload; the label is absent → the create genuinely
  failed (invalid name, over-long description), classified per
  `github_classify` — never as a conflict. The literal `already exists`
  message match survives only as the partial-write discriminator: a non-422
  failure whose text carries it takes the same read-back path, while any
  other failure that may have landed reports `EXIT_PARTIAL` (never retried
  blind — the re-run's read-back is the recovery). GitHub rate limiting
  answers 403/429, so throttling can never read as a conflict.
- `claim-verify --target O/N <issue> --token <t>` — reads the label.
  Token match: stdout `{"held":true,"age_seconds":...}`, exit 0. Token
  mismatch: exit 6 with the holder payload. Absent: `EXIT_NOT_FOUND` (2).
  Malformed description (not exactly three valid fields): treated as a
  foreign claim — exit 6, holder token reported as unparseable.
- `claim-release --target O/N <issue> --token <t>` — reads the label.
  Absent: `{}`, exit 0 (idempotent). Token match: deletes, `{}`, exit 0.
  Mismatch: exit 6 — an owner never deletes a foreign claim.
- `claim-recover --target O/N <issue> --token <t> --producer <login> [--older-than <seconds> | --force]`
  — the stale-claim and operator-authorized recovery path. Reads the label.
  Absent: proceeds straight to create. Present: refuses unless the observed
  claim's age ≥ `--older-than` seconds **or** `--force` was passed. A
  malformed description has no evaluable age, so `--older-than` always
  refuses it — malformed claims are foreign and yield only to `--force` or
  a manual `gh label delete`, matching the ADR.
  (`--force` is the structural carrier of an operator's recovery decision;
  the script cannot take it from a prompt). Then deletes and re-creates with
  the new claim. Delete and re-create are not atomic. The interleaving that
  matters: two recoverers race one stale claim, the slower one's delete
  lands after the faster one's re-create, and the slower one then re-creates
  and owns the issue. The displaced quest's verify gate G1 — which precedes
  any issue mutation — observes a foreign claim, or a transient not-found
  inside the delete/recreate gap, and halts cleanly; it may re-acquire once
  the race settles. A live claim fails every `--older-than` guard, so an
  owner cannot silently lose a live claim to the staleness path; only an
  operator's `--force` can remove one, and that is an operator-visible
  conflict, not a protocol failure — the script carries the authorization,
  it cannot judge it, and no queryable "quest is live right now" signal
  exists for it to check. Partial failure has exactly two reachable modes,
  because the unique-name constraint makes a two-label state impossible and
  create runs only after a successful delete: (a) delete failed → the old
  claim stands untouched, recover reports the delete's error class, and a
  retry matches the same guard; (b) delete succeeded, create failed → the
  store is absent, recover reports `EXIT_PARTIAL` with `{"stage":"create"}`,
  and the caller re-runs `claim-acquire`, which takes the absent path and
  creates the new claim.
- `claim-list --target O/N` — read-only. stdout JSON array
  `[{"issue":...,"token":...,"producer":...,"at":...}]` for every repo label
  whose name matches `quest-claim/<digits>` exactly (anything else under the
  prefix is not a claim and is not listed). Exact schema per entry: `issue`
  is a string of digits from the label *name*, never the description;
  `token`, `producer`, `at` are strings, or **all three** null with
  `"malformed": true` when the description fails any grammar check — no
  partial parsing, so a bad field can never ride beside good ones;
  well-formed entries carry `"malformed": false`. A claimed issue must never
  vanish from the list because its description is odd. Feeds `$seek-quest`'s
  occupancy filter and `$resurrection`'s sweep.

`PROFILE_DECLARES` gains the five operations; a profile that cannot
implement them declares `claim_*:degraded=<reason>` and callers fail closed.
Claim label names are built from a validated integer, so the
`quest-claim%2F<N>` REST path segment carries no untrusted bytes.

## Quest integration

`$quest` step 1 reorders its claim sequence:

1. Mint the scope token (new short form) and read the issue. Resolve the
   producer login (`gh api user --jq .login`); a failure here is an auth
   failure — stop with the `gh` error before claiming, never write a
   description with an empty or malformed producer field.
2. `claim-acquire`. On exit 6: read the holder and the issue's status.
   - Holder stale (per the liveness rule) → `claim-recover --older-than
     <threshold>` and continue as the new owner. The threshold is
     `CLAIM_TTL` when the issue carries an in-flight status, `CLAIM_GRACE`
     otherwise — the two halves of the liveness rule, computed by the
     caller from the issue's current status label.
   - Holder live, **interactive** root → stop. Report the holder's token,
     producer, age, and the issue's status; the human decides whether to
     wait or authorize recovery (a re-invocation carrying that decision uses
     `claim-recover --force`). Ask, never assume.
   - Holder live, **unattended** root (the `$quest` charter definition: an
     orchestrator or background task explicitly declared no human reachable)
     → stop with no writes to the issue.
     This is the one exception to the park protocol (a `WORK:TRAJECTORY` plus
     `status:needs-human`): the issue belongs to a live quest, and any label
     or comment write on it is itself the interference this protocol exists
     to prevent. The blocker is reported in the completion report and, under
     `$campaign`, returned to the orchestrator as a hold.
3. **Verify gate G1**: `claim-verify` immediately after acquiring or
   recovering, *before any mutation of the issue*. A quest that loses its
   claim here has written nothing, which is what makes the
   concurrent-recoverer interleaving safe: the loser halts cleanly and the
   winner's state is untouched.
4. Ensure-create status labels and swap to `status:in-progress` (unchanged).
   The swap is idempotent and **not** exclusive, and nothing relies on it
   for exclusivity: two racing swaps converge to the same value, and the
   verify gates arbitrate ownership. A claim that never reaches an
   in-flight status — its quest crashed or halted between acquire and this
   swap — becomes recoverable once its grace expires, by design: a quest
   that never declared in-progress must not hold the issue.
5. Post `WORK:SCOPE` carrying the same token (unchanged), read it back, and
   cross-check the annotation token against the claim token, then
   **verify gate G2**: `claim-verify` again after the readback.

Two further verify gates bound the non-atomic windows:

- **G3** — before branch creation (step 2).
- **G4** — before the `$deliver` push (step 8).

The unattended-root rule is the same at every gate as at the initial
conflict: halt with no writes to the issue and report the blocker in the
completion report (under `$campaign`, returned to the orchestrator as a
hold). A gate loss means the claim is no longer the halting quest's to
release, so no cleanup write is owed or permitted.

A gate's outcomes are exhaustive: exit 0 → held, proceed; exit 2 (absent —
including an external deletion racing the gate) **or** exit 6 (foreign
holder) → claim lost: halt immediately, make **no** further mutation of the
issue (labels, comments, or the claim), and report — never retry a lost
claim into re-acquisition at a gate; exit 4 (transport) → retryable, the
caller's ordinary transport-error path.
The surviving owner must be able to proceed as if the loser never existed.
A loser at G3 or G4 may hold a local branch with committed work: the halt
report names its path, and the operator disposes of it — the branch may
carry salvageable work, so the protocol neither deletes it nor pretends it
away.

Parked quests keep their claim. A `status:blocked`/`status:needs-human`
issue is outside the in-flight set, so its claim is recoverable (past grace)
by the next `$quest` the human runs — which is the documented exit edge for
those states. Resume by the same run is impossible (a resumed session mints
a new token), so resume *is* recovery: the status-inconsistency rule makes
it immediate for parked issues, and the TTL bounds it for dead in-flight
ones.

## quest-log integration

`quest-log` gains a **Claim protocol** section holding the single definition
of: the label name and description grammar; the token grammar and its
identity with the `WORK:SCOPE` token; `CLAIM_GRACE`/`CLAIM_TTL` and the
liveness rule; the five operations and their exit taxonomy entry; and the
write edges — `$quest` acquires and releases, recovery is `claim-recover`
under the staleness rule or explicit operator authorization, `$resurrection`
garbage-collects. The "one writer per transition edge" rule extends: claim
edges have exactly the writers just named.

## seek-quest integration

Step 6 gains one signal, ahead of the branch/PR scans: one `claim-list`
read; drop any ready candidate carrying a `quest-claim/<N>` label, reported
as `claim quest-claim/<N>` like every other exclusion. No liveness judgment
— dropping a stale-claimed candidate is conservative and correct, because
`$resurrection` repairs stale claims and a dropped candidate is only a
recommendation away. The hard-constraint list gains the read-only
`claim-list` tracker call beside `gh`/`git`/`Read`. This extends ADR 0004's
occupancy set; the claim signal is listed there as an addition by ADR 0018.

## resurrection integration

- Sweep gains claim awareness via one `claim-list` read:
  - Claim on a **closed** issue → plan: delete the claim (release guarded by
    the observed token; the owner is gone).
  - Claim whose issue the existing step-3 staleness gate resets to
    `status:ready` → the same plan row deletes the orphaned claim. The gate's
    four conditions are unchanged: a claim **never** extends or vetoes the
    reset window — its 12 h TTL gates quest-versus-quest recovery, not this
    sweep, so a dead quest's issue is recovered on the same 60-minute
    evidence as before this protocol existed.
- Reconciliation table rows name the claim deletions beside the label
  actions; the single confirmation covers them.

## campaign integration

- Step 3 reconcile: a `quest-claim/<N>` label is in-flight evidence (map the
  row to in-flight and recover artifacts as today).
- Step 5 pre-dispatch and re-dispatch: read the claim.
  - No claim → dispatch; the worker acquires its own.
  - Stale claim → dispatch with recovery authorized in the prompt; the
    worker runs `claim-recover --older-than`.
  - Live claim → **hold**: do not dispatch. When the row's agent has been
    observed ended (the existing re-dispatch bar), the operator's
    re-dispatch answer *is* the recovery authorization; the dispatch prompt
    carries it and the worker runs `claim-recover --force`.
- The worker prompt contract gains one line: the worker mints its own token
  and never recovers a claim without authorization carried in the dispatch
  prompt.

## Threat model

**Boundaries.** (1) Issue number → label name and REST path segment:
validated integer, existing `github_require_id` guard. (2) Token and login →
`gh label create` arguments and, on read-back, parsed data: token whitelisted
to `[A-Za-z0-9-]{1,32}`, login to GitHub's login grammar; a description that
does not parse as exactly three valid fields is treated as a foreign claim,
never as evidence of ownership. (3) The label store itself: any account with
repo write access can create, edit, or delete labels.

**Actors.** The protocol coordinates *trusted automation against itself* —
two well-behaved quests racing, or a dead quest's residue. The untrusted
parties for this repo (a public repository) are issue authors and
commenters; none of them can create repo labels (write access required), so
no untrusted actor can forge a claim. `gh` auth and transport failures map
onto the existing exit classes.

**Placed trust.** A malicious collaborator can delete or forge claims; so can
anyone who can edit labels today vandalize `status:` labels. Claims are a
coordination protocol, not an authorization boundary; accepting this is
consistent with every existing workflow write edge.

**Out of scope.** Claim spam (write-gated), GitHub availability, forgery by
accounts with write access.

## Testing

Behavior suites under `tests/fixtures/quest-log/`, discovered by `just test`:

- **`claim-test.sh`** (new) — stages the tracker asset tree the way
  `tracker-test.sh` does, plus a stateful stub `gh` whose label store is a
  fixture directory: create is `mkdir` (atomic, fails on existence — the
  fixture's stand-in for GitHub's unique constraint), read/delete operate on
  it. Cases:
  - **Simultaneous claims**: two `claim-acquire` processes launched
    concurrently, K rounds; exactly one exit 0 and one exit 6 per round, and
    the store holds the winner's token.
  - **Foreign token verify**: verify with the wrong token → exit 6 with the
    holder payload.
  - **Self-recovery**: acquire, then acquire again with the same token →
    exit 0 `recovered:"self"`.
  - **Stale recovery**: a claim with an old epoch; `claim-recover
    --older-than` succeeds; the store holds the new token; the old token
    never reappears.
  - **Recovery refused**: young claim, `--older-than` not met, no `--force`
    → exit 6, original claim intact. And the `--force` override succeeds.
    A malformed claim refuses `--older-than` at any age and yields to
    `--force`.
  - **Owner release / foreign release refused**: release with the token
    deletes; release with a wrong token exits 6 and the claim survives.
  - **Absent paths**: verify/release/recover against no claim → exit 2 / `{}`
    exit 0 / create.
  - **Malformed description**: a hand-corrupted store entry → verify exits
    6, never reports held; `claim-list` still lists the entry with
    `token`/`producer`/`at` all null and `"malformed": true`; a label under
    the prefix with non-digit suffix is not listed at all.
  - **GitHub failure-mode classification** (stub knobs in the existing
    `GH_FAIL=` pattern): a 422 without `already exists` and an absent store
    → usage/transport, never exit 6; a 429 → transport; a 5xx on create →
    partial or transport per the landing rules, never conflict; an external
    delete between acquire and verify → verify exit 2.
  - **Recover partial modes**: delete-succeed/create-fail → `EXIT_PARTIAL`
    `{"stage":"create"}`, and the follow-up `claim-acquire` lands the new
    claim; delete-fail → old claim untouched, error class reported.
  - **Liveness rule** (the grace/TTL/status matrix) — the rule is arithmetic
    over `age_seconds` and the issue status; the suite exercises the
    boundary ages (below grace, between grace and TTL, past TTL) against
    claim-verify's `age_seconds` output.
- **`tracker-test.sh`** — the declaration-coverage and profile-contract
  cases extended to the five new operations, matching the existing pattern.

AI-surface note: the protocol's decision points are deterministic script
exits, not model judgment — the fixture suites *are* the eval plan, and
repo rule 4 forbids asserting on the prose that stitches them together.

## Guardrails

`just verify` bare. New suite files are picked up by `git ls-files
'*-test.sh'` once committed. Bash 3.2 floor; tab indentation;
`rg --no-config` in scripts; capture scan exit statuses explicitly (ADR
0005).
