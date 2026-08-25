# 0035 The merge gate binds to a commit, not to reported state

## Status

Accepted (2026-08-25)

## Context

Three skills approach a merge and none of them names the commit it is merging.
`skills/campaign/SKILL.md` step 6 says "As each issue reaches green + mergeable,
run `$return-to-town`"; `skills/return-to-town/SKILL.md` retains "`$deliver`'s
exit condition: required checks are green and the pull request is mergeable";
`skills/deliver/SKILL.md` step 3 exits when "required checks are green and
`mergeStateStatus` is `CLEAN`/`MERGEABLE`". Every one of those is a property of
what GitHub reports *now*, about a pull request rather than about a commit.

ADR 0009 governs the first of those reads and is untouched here: its decision
that `$return-to-town` interprets `state` before computed mergeability stands.
What narrows, for issue-backed merges only, is the consequence that an `OPEN`
pull request's `mergeable`/`mergeStateStatus` is the last word before merging.

Issue #235 reports three ways that gate passed over work that had not landed,
during a `$campaign` run in `randomparity/hmc-mcp`. That repository is readable
with `gh`, and its pull requests were checked rather than taken on report
(2026-08-25):

- `gh pr view 445 --repo randomparity/hmc-mcp --json headRefOid,state` →
  `af035a39f83e69c334302373cd2a6faea0fa78b3`, `MERGED`; and `gh api
  repos/randomparity/hmc-mcp/pulls/445/commits` returns **exactly one commit**,
  `af035a39`. The pull request merged at the only commit it ever recorded.
- `gh pr view 454 --repo randomparity/hmc-mcp` → `MERGED`, titled "fix: land the
  reviewed #363 fixes that PR #445 merged without". The recovery pull request
  exists and says what it recovered.
- #443, #444 and #455 are likewise `MERGED`, with #447 and #453 the recoveries
  the issue names for the first two.
- `gh api repos/randomparity/hmc-mcp/pulls/454/commits` dates the two recovered
  commits at `2026-08-25T11:14:55Z` and `11:27:19Z`. PR #445 merged at
  `11:03:40Z`.

That last query settles what the incident shows, and it is not what issue #235
attributes it to. **The recovered commits did not exist when the merge fired** —
they were authored eleven and twenty-four minutes afterwards. Nothing was dropped
through a stale head; the merge happened while the author was still working,
which is shape 1 below.

The shapes this record acts on, with the instruments each is stated over
checkable in *this* repository:

1. **A pull request is green and mergeable long before its author is finished.**
   In `$quest` the pull request opens inside step 8 (`skills/quest/SKILL.md:585`,
   `:594`) and the author is not finished until step 9's hand-off (`:721`), after
   the delivered head is verified (`:602`–`:607`) and the review summary is
   published (`:610`–`:662`). The window opens when the pull request opens and
   closes at hand-off; `skills/return-to-town/SKILL.md:202`–`203` names it
   itself, that hand-off "comes some way *after* its pull request first reads
   green + mergeable". Nothing on GitHub distinguishes those two states, so the
   orchestrator's merge trigger fires inside that window. **This is the shape the
   incident above exhibits, and the only one it does.**

2. **The pull-request API's `headRefOid` can lag the branch's real head.**
   Reported, not exhibited by the incident above — and it needs no observation to
   matter, because `gh pr checks` and `statusCheckRollup` resolve their subject
   through that API by construction. A green answer from either can therefore be
   about a commit that is no longer the head: literally true and completely
   misleading. That is a fact about the instrument, and it is what parts 1 and 2
   actually stand on.

3. **Checks green on a branch head are not checks green on the merge result.**
   CI ran against whatever the base was at the time. `mergeStateStatus` does not
   surface a base that moved without conflicting, so the gate reads `CLEAN`
   throughout.

The meta-cause is one thing: the precondition is written as a property of
reported pull-request state, and it needs to be a property of a specific commit
plus an explicit statement from whoever authored that commit.

**What the evidence supports, stated plainly.** Part 4 with decision 5 answers
shape 1, the one the incident exhibits. Parts 1, 2 and 3 would each have *passed*
that merge — the head was current, its checks were green, the base had not
moved — and they are there for shapes 2 and 3, which rest on the general facts
above rather than on the report. Nobody should read the incident as evidence
for them.

`$return-to-town` already holds most of the answer and applies it to one caller.
Its restock PR-only mode compares the observed head against `$EXPECTED_HEAD_SHA`
and merges with `gh pr merge <N> "$MERGE_FLAG" --match-head-commit
"$EXPECTED_HEAD_SHA"`. That is the commit-bound merge this record needs,
reachable today only by `$restock`.

## Decision

**1. One gate, four parts, checked immediately before every issue-backed
`gh pr merge`.** Its subject is a commit — `HEAD_SHA` below — and every part is
a statement about that commit. `$return-to-town`'s restock PR-only mode is
outside it, for the reasons in Consequences: a dependency pull request has no
issue for part 4 and no `$quest` run authored it, and its head binding is the
evaluated `$EXPECTED_HEAD_SHA` rather than a merge-time read.

- **SHA parity.** `HEAD_SHA` comes from `git ls-remote origin
  refs/heads/<branch>`, which reads the ref itself, so **the gate covers
  same-repository heads**: a fork-based pull request's head is not in `origin` at
  all, and `gh pr view <PR> --json isCrossRepository` identifies one ahead of
  part 1 and gives it its own named blocker, rather than letting an empty
  `ls-remote` reach decision 3 and be reported as a deleted branch. `gh pr view
  <PR> --json headRefOid` must agree with `HEAD_SHA`. A mismatch has two causes
  and re-reading tells them apart: an `ls-remote` value that holds still while
  `headRefOid` catches up
  is the API lagging, and an `ls-remote` value that keeps moving is an author
  still pushing. Neither may be merged through, and the re-read is bounded by the
  caller's existing poll budget — the same backing-off snapshot loop and hold
  path `$deliver` step 3 already defines for driving a pull request to green,
  not a new number this record invents. When it expires the row holds rather than
  spinning, which an unattended run would otherwise do indefinitely against a
  live branch. **This part is a diagnosis
  and pre-empt device, not a safety property.** `HEAD_SHA`'s authority is the
  ref, every other part keys on it, and decision 2 binds it at the server — so
  part 1 buys legibility, not safety, at the cost of occasionally parking a
  correct row in an unattended run. Accepted at that price.
- **Checks green for `HEAD_SHA`.** `gh run list --commit "$HEAD_SHA"` addresses
  runs by commit, so a green answer cannot be about a different one. `conclusion`
  is not two-valued, so the partition is over its vocabulary rather than over
  `!= success`, and it has four outcomes:
  - **green** — a non-empty list in which every run is `status: completed` at
    `conclusion: success`, `skipped`, or `neutral`. The last two are ordinary and
    non-blocking: a path-filtered or conditional workflow reports `skipped` on
    every commit that does not touch its paths, and treating that as failure
    would deadlock the gate on the most common configuration there is;
  - **not yet** — no run for `HEAD_SHA`, *or* any run not yet at `status:
    completed`. A commit pushed seconds ago returns exactly this. Wait on the
    same caller budget part 1 uses, then take the hold path under this name;
  - **failed** — `failure` or `timed_out`;
  - **held under its own name** — `cancelled`, `action_required`, `stale`, or
    `startup_failure`. None of these is a verdict about the code, and reporting
    one as a check failure sends the operator to the wrong place.

  **Unverified:** this vocabulary is GitHub's documented set for a run's
  `conclusion`, not something reproduced here — the last 100 runs in this
  repository yield only `success` (86) and `failure` (14), so the other seven
  values have no local witness. It is stated because the partition has to be
  exhaustive to be implementable, and a partition on `!= success` silently
  assigns five ordinary outcomes to failure.

  The set it reads is **all** Actions runs for the commit, not the required set:
  required-ness belongs to a branch rule and is not SHA-addressable at all. So
  this is stronger than the "required checks are green" it replaces *over Actions
  runs* — it will hold on an optional run the old wording ignored — and weaker
  outside them, because it cannot see a non-Actions required context. Where a
  repository has those, `gh api repos/<owner/name>/commits/"$HEAD_SHA"/check-runs`
  is the instrument, SHA-addressed the same way and read alongside.
- **Merge base current.** `git fetch origin`, then `git merge-base --is-ancestor
  origin/<BASE_BRANCH> "$HEAD_SHA"` — the base tip is already contained in the
  head, so the merge result *is* the commit CI ran on. The fetch is part of the
  check, not preparation for it: this is a local test against a
  remote-tracking ref, and against a stale one it passes wrongly, which is the
  failure the part exists to catch. Run both immediately before the merge —
  `--match-head-commit` binds the head and nothing binds the base, so the
  interval between this test and the merge is the exposure.
- **Author handshake.** A `MERGE-READY: #<PR> @ <HEAD_SHA>` line naming that
  exact commit, occurring as a whole line inside the latest complete
  `WORK:TRAJECTORY` block **that carries such a line for `HEAD_SHA`** — not the
  latest complete block simpliciter. The distinction is load-bearing because
  `WORK:TRAJECTORY` is also what the park protocol writes: a hold posted after a
  valid hand-off would otherwise become the latest block, carry no handshake, and
  silently revoke one that was still true. Nothing is weakened by scoping the
  selection this way, because any new push changes `HEAD_SHA` and invalidates the
  old line regardless. The selection rules are `$quest-log`'s —
  its *Recipe: read the latest complete annotation of a type* — and this part
  needs them rather than a fresh `jq` over every comment: a block without its
  `TRAJECTORY:COMPLETE` sentinel is a write that died midway and is treated as
  absent, so a half-written hand-off cannot supply a handshake for the head it
  was about to attest, and `last` is what implements latest-complete-wins.

  One shape change is required and is the reason this record states it rather
  than only citing it: that recipe selects over comment *bodies*
  (`.comments[].body`), which cannot yield an author. Select over comment
  *objects* instead, so the author and the body come off the same one:

  ```sh
  gh issue view <n> --json comments --jq '[.comments[]
    | select(.body | test("(?m)^<!-- WORK:TRAJECTORY -->$")
             and test("(?m)^<!-- TRAJECTORY:COMPLETE -->$"))]
    | last | {author: .author.login, body}'
  ```

  The three skills carry that object form inline under issue #249; reconciling
  `$quest-log`'s own recipe to it belongs to issue #243, which already owns that
  skill. Until one of them lands, the object form here is the authority for
  part 4 and the recipe is cited for its selection rules, not its projection.

  **The expected account is established outside the comment channel**, or the
  check is circular: a stranger who may post a `MERGE-READY:` line may equally
  post a complete-looking `WORK:TRAJECTORY` block, name themselves the hand-off's
  author, and attest for themselves. So `author.login` must equal the pull
  request's own author — `gh pr view <PR> --json author --jq .author.login`,
  which GitHub attests — or an account with write permission (`gh api
  repos/{owner}/{repo}/collaborators/<login>/permission`), *in addition to*
  having posted the latest complete block. SHA-binding is no help against this
  one: `HEAD_SHA` is the public head of a public pull request, so a forged line
  naming it passes parts 1–3 by construction.

  The one other permitted author is the merging run itself, where it created the
  head by refreshing a stale base — its own `gh api user --jq .login`. Those are
  the only two producers of a `HEAD_SHA`. **The second is derivative and never
  original:** a
  merging run may attest only for a head it produced by refreshing a head that
  already carried a valid author handshake. A row reaching part 3 with no author
  handshake for its current head takes the hold path — it does not take the
  refresh path and then attest to its own work, which would let the refresh mint
  the very handshake decision 5 requires and reopen failure mode 1 through the
  gate. Consequences records what the permitted case still costs.

**2. The head is bound at the merge, not only before it.** Every issue-backed
merge path in `$return-to-town` passes `--match-head-commit "$HEAD_SHA"`,
generalizing the binding restock PR-only mode already performs — that mode keeps
binding its own `$EXPECTED_HEAD_SHA`, which is not `HEAD_SHA` and must not be
replaced by it. Parts 1–3 are read-then-act and leave a window between the read
and the merge; the flag closes the head half of it at the server, which is the
only place a head can be bound. **Unverified:** which head GitHub compares the
flag against — the ref, or the same pull-request field part 1 can find stale — is
not reproducible without performing a merge, so it is not asserted here. If it is
the ref, the flag is a complete head guard; if it is the field, it guards against
a push the API has already seen and part 1 is what catches the rest. Part 1 earns
its place either way, which is why nothing above depends on the answer. It does
**not** close part 3: `gh pr merge` at
2.98.0 has one SHA-binding flag and no base-side equivalent, so a sibling
merging in the seconds between the ancestry test and the merge moves the base
under a check that already passed. That residual is accepted and is the last
word on it here; Consequences records the shape it takes in a serial wave.

**3. An empty answer is not a passing answer, and a failed command is neither.**
`git ls-remote` on a ref that does not exist prints nothing and exits 0; `gh run
list --commit` on a commit with no runs returns `[]` and exits 0. Both commands
ran and answered, so neither is a fault — but they answer different questions and
need different rules. Zero runs for `HEAD_SHA` is a check outcome: CI has not
reported, never that nothing failed. It is also two conditions, and `gh run list`
cannot tell them apart: a commit whose runs have not started, which resolves, and
a repository with no workflows at all, which never will. Establish the second by
a **conjunctive** test — `gh api repos/<owner/name>/actions/workflows` empty
**and** `check-runs` for `HEAD_SHA` empty — and record part 2 as *not applicable*
rather than not-yet, which is a terminating outcome, determined per run and never
persisted. Both halves are required: a repository whose checks are live but not
Actions has no workflows and real check runs, and either half alone would skip
part 2 over them. Without it the
gate deadlocks permanently in any repository with no automated checks, and these
skills ship to arbitrary ones — the same generalization argument the merge-queue
and `BEHIND` rejections below both turn on. That test does not cover every
never-runs configuration and is not meant to; part 2's bound is what covers the
rest. An empty `ls-remote` is a missing *subject* —
`HEAD_SHA` is what all four parts are statements about, so there is nothing left
to be about, and the ordinary cause is a head branch already deleted or renamed.
That takes the blocker path immediately under that name, rather than entering
part 1's re-read, where an empty value would otherwise be re-read as a lagging
API until the budget ran out and the operator got the wrong diagnosis.
The fault case is separate and also has to be checked:
a non-zero exit from either command is a scan that could not run, which ADR 0005
decision 1 governs — carried forward unchanged by ADR 0024 decision 1, itself
superseded by ADR 0025, so the chain resolves in 0005's favour and the citation
is to that chain rather than to 0005 alone.

**4. The handshake lives on the tracker, and the completion report quotes it.**
`$return-to-town`'s hand-off already posts a `WORK:TRAJECTORY` comment on the
issue at exactly the moment the author is finished. The `MERGE-READY:` line goes
in that comment, which makes it durable, re-readable by any later session, and
costs the orchestrator a `gh` query rather than a turn. Issue #235 reports
intra-agent reports being lost twice; a handshake that only ever travelled in
one is a handshake with the same failure mode as the thing it replaces. It is
distinct from the `delivered-head-sha:` this repository already produces, which
is taken at delivery rather than at hand-off — see the rejection below.

**5. A green pull request with no handshake is *pending*, not *ready*.**
`$campaign` may learn a branch name from `gh pr view <PR> --json headRefName`,
as it does today, and may not treat the existence of a green pull request as a
merge trigger. "PR is green" is not a terminal `$quest` state.

**6. The gate is stated in full in `$campaign`, `$quest`, and
`$return-to-town`, in identical words.** Each skill executes it inline at the
moment it matters; the surrounding sentence differs by role — `$campaign` is
forbidden to merge without a handshake, and `$return-to-town` both writes one and
performs the guarded merge. **`$return-to-town` computes the `HEAD_SHA` the
handshake names**, from `git ls-remote` at the moment it posts the hand-off
comment. Not `$quest`, and not `delivered-head-sha:`: the branch can move between
delivery and hand-off, and a handshake naming a commit that is no longer the head
is one part 1 will reject anyway. `$quest` states the gate because its terminal
report quotes that line and it must not report green as terminal.

## Consequences

- Three copies of one gate is the drift surface this repository removed
  elsewhere, and issue #235 names the two-copy version of the same shape as an
  aggravating factor in the incident: two documents stating an incomplete gate
  corroborated each other. Nothing here detects divergence between the three —
  anatomy rule 4 forbids a gate that greps prose for a sentence, so no
  mechanical guard is available. The residual is real and is owned by issue #242,
  which proposes one `references/merge-gate.md` consulted by all three.
- `skills/deliver/SKILL.md` and `skills/quest-log/SKILL.md` still carry
  "green + mergeable" language and are outside this change's surface.
  `$deliver`'s exit condition is *correct for `$deliver`* — it drives a pull
  request to green and hands back, and it never merges — but `$return-to-town`
  cites it by name as its own entry condition, so the two now say different
  things about the same moment. Owned by issue #243 rather than edited here.
- **Part 3 is ordinary to fail.** During a serial merge wave every merge moves
  `origin/<BASE_BRANCH>` by design, so the next sibling routinely fails it. The
  existing refresh — merge `BASE_BRANCH` in, regenerate artifacts, rerun
  guardrails — clears it and produces a new `HEAD_SHA`, so the gate re-runs from
  part 1 rather than resuming at part 4, and the handshake is re-obtained because
  the old one named the old commit. Decision 2 states the window that survives
  even so.
- **`$restock` keeps merging through `$return-to-town` and stays outside this
  gate** (ADR 0012; `skills/restock/SKILL.md:758`–`762`, `tracking mode:
  pr-only`, "Restock never invokes `gh pr merge`"). Decision 1's scoping is what
  makes that true, and part 4 is why it has to be.
- **After an orchestrator refresh, part 4 is self-attestation**, bounded by
  decision 1 to a head derived from one that already carried an author handshake.
  Within that bound, parts 1–3 plus `--match-head-commit` are the whole of the
  gate for such a head — the author check cannot separate an orchestrator's
  comment from a worker's under `$campaign`, where every agent writes through one
  token. It defends against a third party, not against the merging run itself.
- **The handshake is a line in a public comment**, and part 4's author check is
  what stands between a stranger and a merge trigger — SHA-binding is not, since
  `HEAD_SHA` is public. The same hazard is why `skills/campaign/SKILL.md:312`
  declines to persist a hold-release decision at all: "a release token durable
  enough to survive a resume is one any commenter on a public repo could post."
  What is accepted here and not there is that a merge is gated on three further
  commit-bound facts, and that the account is pinned to the pull request's own
  author rather than to whoever last commented.
- `--match-head-commit` turns the lag case from a silent wrong merge into a
  refused merge. That is a new failure the orchestrator sees, which is the
  intent; it is also a reason not to retry it blindly, since the refusal means
  the branch moved and the whole gate is stale.
- **This record lands ahead of its implementation.** `skills/campaign/SKILL.md`,
  `skills/quest/SKILL.md`, and `skills/return-to-town/SKILL.md` are unchanged as
  of this record: they still state the "green + mergeable" precondition its
  Context quotes. The gate described here is therefore a decision in force and a
  behaviour not yet present, and the two must not be confused — nothing in the
  shipped skills does any of this yet. Issue #249 carries the implementation and
  cites this record as its governing decision. Until it merges, a reader
  comparing this record against the skills will find them disagreeing, and the
  skills are what any harness actually executes.
- Once implemented, the gate is prose in skill files. Nothing enforces it,
  exactly as ADR 0019 records of its own contract; enforcement is reading.
- This record is numbered 0035, assigned by the dispatching campaign. 0023 and
  0027 stay unallocated per `docs/adr/README.md`.

## Considered & rejected

- **Keep `gh pr checks` / `statusCheckRollup` as the check source.** verified:
  both read the pull-request API and report the same `headRefOid` that failure
  mode 2 is about, so a gate built on them inherits whatever staleness that
  field has with no signal that it has. `gh run list --commit <SHA>` is
  SHA-addressed by construction: run against `randomparity/adept` at
  `e604daa4d9b19d1d3f33e2a9c691a80013399af0` with gh 2.98.0 it returned exactly
  the two runs whose `headSha` is that commit, and against an all-zero SHA it
  returned `[]`. **Unverified:** that `headRefOid` *did* lag during the incident
  is the reporter's observation of a transient condition, and no post-hoc query
  preserves it — Context verifies the incident's outcome but not this. The
  rejection does not rest on it: a field that can only be as fresh as the API
  serving it is the weaker instrument whether or not it has ever been observed
  stale.
- **Read part 2 through `gh api repos/{owner}/{repo}/commits/<SHA>/check-runs`
  instead of `gh run list --commit`.** Both are SHA-addressed, so this one is not
  rejected on the staleness ground above; it is the chosen instrument's closest
  competitor. verified: run against `randomparity/adept` at
  `e604daa4d9b19d1d3f33e2a9c691a80013399af0` with gh 2.98.0 it returned five
  check runs — `verify`, `Deploy to GitHub Pages`, `Build site`, and two
  `suite (…)` matrix legs — against the two workflow runs `gh run list` reported
  for the same commit. judgment: `gh run list` is the better default because its
  granularity matches how these workflows are configured and how a reader reasons
  about them (one entry per workflow run, not one per job), and because it is a
  first-class `gh` command rather than a raw API path. The cost is the coverage
  gap named in part 2 — Actions runs only — which is why `check-runs` is kept as
  the named supplement rather than dropped.
- **Compare `headRefOid` against `git ls-remote`, then merge — no
  `--match-head-commit`.** verified: `gh pr merge --help` on gh 2.98.0 documents
  `--match-head-commit SHA  Commit SHA that the pull request head must match to
  allow merge`, so a server-side binding is available; a compare-then-merge
  leaves a window between the two calls in which the branch can move, and the
  flag is what removes it rather than narrows it.
- **Read `mergeStateStatus == BEHIND` as the merge-base check.** verified: `git
  merge-base --is-ancestor` answers the question locally and identically in every
  repository, which is the ground that generalizes — these skills ship to
  arbitrary repositories and cannot assume any particular configuration. The
  local half is secondary and scoped to here: `gh api
  repos/randomparity/adept/branches/main/protection` returns HTTP 404 `Branch not
  protected`, and because that endpoint is silent about rulesets (ADR 0024), `gh
  api repos/randomparity/adept/rulesets` and `gh api
  repos/randomparity/adept/rules/branches/main` were run too, both `[]` at exit 0
  (all three 2026-08-25) — so `main` here carries no up-to-date requirement by
  either mechanism and the field cannot report the condition in this repository.
  **Unverified:** that GitHub computes `BEHIND` *from* such a rule is stated in
  issue #235 and is not reproducible here, since no branch in this repository is
  protected by either mechanism; nothing above depends on it.
- **Rely on the existing "Never merge an unmergeable PR on the strength of
  previously-green checks" sentence.** verified: `git grep -n previously-green
  e604daa4d9b19d1d3f33e2a9c691a80013399af0 -- skills/` returns exactly one hit,
  `skills/return-to-town/SKILL.md:118` — the sentence is in one skill, not two,
  and `skills/campaign/SKILL.md:314` states the refresh in its own words instead,
  which is itself an instance of the drift residual above. Both formulations
  condition on `mergeStateStatus` having gone `BEHIND`/`DIRTY`, so neither
  reaches a pull request that stayed `CLEAN` while its base moved, nor a head the
  pull-request API has not caught up to.
- **Let GitHub's merge queue solve failure mode 3, with `--auto` alongside it.**
  This is the platform feature aimed at exactly that failure: it builds the
  prospective merge result and runs required checks against *that* rather than
  against the head. verified: `gh pr merge --help` at gh 2.98.0 documents the
  interaction — "When targeting a branch that requires a merge queue, no merge
  strategy is required. If required checks have not yet passed, auto-merge will
  be enabled. If required checks have passed, the pull request will be added to
  the merge queue." judgment: it is base-branch configuration, and these skills
  ship to arbitrary repositories that may not have it enabled or may be on a plan
  without it, so a gate written in skill prose cannot assume it; it also leaves
  failure modes 1 and 2 untouched, which are two of the three. Where a base
  *does* require a queue, `gh pr merge` enqueues rather than merges and
  `--match-head-commit` binds the head at enqueue time — the gate's parts still
  hold at that moment, and what the queue does afterwards is outside it.
- **Reuse the `delivered-head-sha:` `$quest` already produces**, instead of a
  second head-SHA artifact. verified: `skills/quest/SKILL.md:602`–`607` already
  compares the delivered pull request's `headRefOid` against `git rev-parse HEAD`,
  parks on a mismatch, and persists that value in the `publication-in-progress`
  handoff (also `:676`–`677`); `:371` requires a full immutable object ID; and
  `:620` carries it as a field of the review summary, which
  `skills/quest/scripts/publish-forge-review:230` posts as a pull-request
  *comment* (`gh pr comment`). The two are not interchangeable:
  `delivered-head-sha:` is taken at delivery, *before* step 6's remaining
  obligations and step 9's hand-off, so it cannot carry an assertion that the
  author is finished — which is the whole content of part 4. Kept separate
  deliberately, and named here because the two full head SHAs end up on
  different objects — one in a pull-request comment, one on the issue — where
  nothing otherwise says how they differ.
- **Carry the handshake on the pull request instead of the issue.** verified: it
  would be cheaper on three axes — part 1 already calls `gh pr view <PR> --json
  headRefOid`, so `comments` folds into that field list instead of a separate
  `gh issue view`; it would sit beside the `delivered-head-sha:` summary that
  `skills/quest/scripts/publish-forge-review:230` already posts there; and
  `skills/return-to-town/SKILL.md:24` shows PR-carried `WORK:TRAJECTORY` blocks
  already work in PR-only mode. judgment: rejected because
  `skills/return-to-town/SKILL.md:73`–`74` already posts the hand-off
  `WORK:TRAJECTORY` **on the issue** at precisely the moment the handshake is
  true, so the issue placement rides an existing write and a pull-request comment
  would be a new one; and `$campaign` drives from issues, reads them anyway, and
  the issue outlives the pull request. Reconsider it with issue #242, which
  reopens where the gate lives.
- **Use GitHub's draft state as the author-finished signal**: `$deliver` opens
  the pull request with `--draft`, hand-off runs `gh pr ready`, and the gate reads
  `isDraft`. This is the platform's own answer to failure mode 1, and it is
  better than a handshake on three of the grounds this record argues elsewhere —
  it is a first-class field rather than a string any account can post, it is as
  durable as a comment, and GitHub refuses to merge a draft server-side, which
  would make failure mode 1 a refusal rather than a prose obligation. verified:
  `gh pr create --draft`, `gh pr ready`, and the `isDraft` field are present at
  gh 2.98.0, and `rg -n -i 'draft|isDraft' skills/{deliver,quest,return-to-town,campaign}/SKILL.md`
  returns nothing — no part of this pipeline uses draft state today.
  **Unverified:** that GitHub refuses a draft merge server-side is not
  reproducible here, since confirming it would mean creating and merging a draft
  pull request. Rejected on two grounds that do not depend on it. verified:
  draft state names no commit, so `ready` cannot say *which* head the author
  finished at — a push after `gh pr ready` leaves the pull request ready at a
  commit nobody attested, which is failure mode 2 wearing a different label, and
  SHA binding is the whole content of this record. verified: opening the pull
  request as a draft is a `$deliver` change, and `skills/deliver/SKILL.md` is
  outside this change's surface — issue #243 owns it. judgment: a repository whose
  `pull_request` workflows filter drafts would leave part 2 with no runs until
  `gh pr ready`, which interacts badly with decision 3's not-yet rule. Worth
  reopening with #243, where the `$deliver` half is in scope; the two are
  complementary if it is, since draft state and a SHA-bound handshake answer
  different halves of "finished".
- **Use `$campaign`'s existing observed-end-of-run rule as the author-finished
  signal**, instead of a handshake. verified: `skills/campaign/SKILL.md:316`
  already establishes the same proposition — "Refresh a `BEHIND` sibling only
  once you have observed that agent's end of run — or once `git worktree list`
  shows the branch checked out nowhere" — from harness state plus a local
  command, with no tracker write and no author-identity question. judgment:
  rejected on durability, which is the ground decision 4 rests on: an end-of-run
  notification is harness state that does not survive a resumed campaign and
  never reaches a host that did not dispatch the worker, while a comment is
  re-readable by any later session. The two are complementary rather than
  alternatives — that rule keeps governing when a worktree may be touched, and
  this one governs when a commit may be merged.
- **Have the orchestrator ask the worker for the handshake by message**, which
  is issue #235's own proposal B. verified: `skills/campaign/SKILL.md` step 5 at
  `e604daa4d9b19d1d3f33e2a9c691a80013399af0` budgets the direct probe at one per
  agent per run, and `references/dispatch-liveness.md` owns that budget, so
  spending it on a handshake competes with the liveness question it exists for —
  and a probe reaches only an agent still mid-run, which by definition the
  author of a finished branch is not. Decision 4 reads the same fact off the
  tracker for the cost of a `gh` query.
- **Put the gate in one `references/merge-gate.md` and link it from all three
  skills.** judgment: a reference is something consulted while doing something
  else, and this gate is executed inline at the one moment it matters — the
  indirection is worst exactly there. Contestable, and deliberately left open:
  issue #242 owns the consolidation and reopens this question with the
  implementation rather than treating it as closed here.
- **Do nothing and rely on the reviewer.** verified: in the one incident this
  record can check, PR #445 merged at `af035a39` — its only commit — eleven
  minutes before its author wrote the first of the two commits PR #454 later
  recovered, and that campaign run needed three recovery pull requests across
  nine issues. Reviewer judgment cannot reach work that does not exist yet at the
  moment the merge fires; only a precondition about who has finished can.
