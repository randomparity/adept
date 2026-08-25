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

Issue #235 reports three ways that gate passed over work that had not landed,
during a `$campaign` run in `randomparity/hmc-mcp`. That repository is not
reachable from here, so its four pull requests (#443, #444, #445, #455) are
**reported, not verified** — the shapes below are what this record acts on, and
each is checkable against this repository's own tooling:

1. **A pull request is green and mergeable long before its author is finished.**
   In `$quest` the pull request opens inside step 8 (`skills/quest/SKILL.md:585`,
   `:594`) and the author is not finished until step 9's hand-off (`:721`), after
   the delivered head is verified (`:602`–`:607`) and the review summary is
   published (`:610`–`:662`). The adversarial review loop is step 6 and has
   already ended by then, so the window is narrower than issue #235 describes —
   but it is real, and `skills/return-to-town/SKILL.md:202`–`203` names it
   itself: hand-off "comes some way *after* its pull request first reads green +
   mergeable". Nothing on GitHub distinguishes those two states, so the
   orchestrator's merge trigger fires inside that window.

2. **The pull-request API's `headRefOid` can lag the branch's real head.** The
   reporter watched it lag `git ls-remote` "through several polls". Checks were
   green *for the stale commit*, so `gh pr checks` returned an answer that was
   literally true and completely misleading.

3. **Checks green on a branch head are not checks green on the merge result.**
   CI ran against whatever the base was at the time. `mergeStateStatus` does not
   surface a base that moved without conflicting, so the gate reads `CLEAN`
   throughout.

The meta-cause is one thing: the precondition is written as a property of
reported pull-request state, and it needs to be a property of a specific commit
plus an explicit statement from whoever authored that commit.

`$return-to-town` already holds most of the answer and applies it to one caller.
Its restock PR-only mode compares the observed head against `$EXPECTED_HEAD_SHA`
and merges with `gh pr merge <N> "$MERGE_FLAG" --match-head-commit
"$EXPECTED_HEAD_SHA"`. That is the commit-bound merge this record needs,
reachable today only by `$restock`.

## Decision

**1. One gate, four parts, checked immediately before every `gh pr merge`.** Its
subject is a commit — `HEAD_SHA` below — and every part is a statement about
that commit:

- **SHA parity.** `HEAD_SHA` comes from `git ls-remote origin
  refs/heads/<branch>`, which reads the ref itself. `gh pr view <PR> --json
  headRefOid` must agree with it. A mismatch has two causes and re-reading tells
  them apart: an `ls-remote` value that holds still while `headRefOid` catches up
  is the API lagging, and an `ls-remote` value that keeps moving is an author
  still pushing. Neither may be merged through, and the re-read is bounded —
  after a few attempts that do not converge the row takes the caller's existing
  hold or blocker path rather than spinning, which an unattended run would
  otherwise do indefinitely against a live branch.
- **Checks green for `HEAD_SHA`.** `gh run list --commit "$HEAD_SHA"` addresses
  runs by commit, so a green answer cannot be about a different one.
- **Merge base current.** `git merge-base --is-ancestor origin/<BASE_BRANCH>
  "$HEAD_SHA"` — the base tip is already contained in the head, so the merge
  result *is* the commit CI ran on.
- **Author handshake.** A `MERGE-READY: #<PR> @ <HEAD_SHA>` line from the run
  that authored the branch, naming that exact commit. "From that run" is read as
  an author check on the comment: `gh issue view <n> --json comments --jq
  '.comments[] | {author: .author.login, body}'`, and only a comment whose
  `author.login` is the expected account counts.

**2. The head is bound at the merge, not only before it.** Every merge path in
`$return-to-town` passes `--match-head-commit "$HEAD_SHA"`, generalizing what
restock PR-only mode already does. Parts 1–3 are read-then-act and leave a
window between the read and the merge; the flag closes the part-1 and part-2
half of it at the server, which is the only place a head can be bound. It does
**not** close part 3: `gh pr merge` at 2.98.0 has one SHA-binding flag and no
base-side equivalent, so a sibling merging in the seconds between the ancestry
test and the merge moves the base under a check that already passed. Parts 1–3
stay, because they are what produce a diagnosis rather than a bare refusal.

**3. An empty answer is not a passing answer, and a failed command is neither.**
`git ls-remote` on a ref that does not exist prints nothing and exits 0; `gh run
list --commit` on a commit with no runs returns `[]` and exits 0. Both commands
ran and answered, so neither is a fault — they are "did not match", and the rule
they need is simply that zero runs for `HEAD_SHA` means CI has not reported,
never that nothing failed. The fault case is separate and also has to be checked:
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
moment it matters; the surrounding sentence differs by role — `$quest` computes
`HEAD_SHA` to name it in the handshake, `$campaign` is forbidden to merge
without one, `$return-to-town` performs the guarded merge.

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
- **Part 3 keeps an irreducible window.** `--match-head-commit` binds the head
  and nothing binds the base, so during a serial merge wave — where every merge
  moves `origin/<BASE_BRANCH>` by design — a sibling can land between the
  ancestry test and the merge, and the merge result then contains a commit CI
  never ran against this head. That is failure mode 3 reached *through* the gate.
  Running part 3 immediately before the merge narrows the window to the round
  trip; nothing available closes it. Accepted, and named here rather than left
  for a reader to find.
- **The handshake is an unauthenticated line in a public tracker comment.** This
  repository is public, so any account can post the string, and part 4's author
  check is the only thing between a stranger's comment and a merge trigger. The
  same reasoning appears at `skills/campaign/SKILL.md:312`, which declines to
  persist a hold-release decision precisely because "a release token durable
  enough to survive a resume is one any commenter on a public repo could post".
  What is accepted here that is not accepted there: the handshake is
  SHA-bound, so a forged or stale line still has to name a commit that passes
  parts 1–3, and a handshake left over from an earlier hand-off names a
  superseded commit. That is also why part 4 is re-obtained after every refresh
  rather than carried forward.
- `gh run list` reports GitHub Actions runs only. A repository whose required
  checks include a non-Actions context needs `gh api
  repos/{owner}/{repo}/commits/<SHA>/check-runs`, which is SHA-addressed the
  same way. The gate names both so the Actions-only reading is a choice rather
  than an oversight.
- The merge-base part is a local ancestry test rather than a `mergeStateStatus`
  reading, so it needs a current `origin/<BASE_BRANCH>` — a `git fetch origin`
  belongs immediately before the gate, and a stale fetch makes part 3 pass
  wrongly.
- Part 3 failing is ordinary during a serial merge wave: every merge moves the
  base and puts the next sibling behind it. The existing refresh — merge
  `BASE_BRANCH` in, regenerate artifacts, rerun guardrails — is what clears it,
  and it produces a new `HEAD_SHA`, so the gate is re-run from part 1 rather
  than resumed at part 4. The handshake is re-obtained too: the author's
  `MERGE-READY:` named the old commit.
- `--match-head-commit` turns the lag case from a silent wrong merge into a
  refused merge. That is a new failure the orchestrator sees, which is the
  intent; it is also a reason not to retry it blindly, since the refusal means
  the branch moved and the whole gate is stale.
- The gate is prose in three skill files. Nothing enforces it, exactly as
  ADR 0019 records of its own contract; enforcement is reading.
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
  returned `[]`. The claim that `headRefOid` *did* lag in a real incident is
  reported by issue #235 and **not verified from this repository**, which has
  no access to `randomparity/hmc-mcp`; the rejection does not rest on it, since
  a field that can only be as fresh as the API serving it is the weaker
  instrument either way.
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
  compares the delivered pull request's `headRefOid` against `git rev-parse HEAD`
  and parks on a mismatch, `:371` requires a full immutable object ID, `:620`
  persists it in the phase handoff, and `:662` puts the summary carrying it in
  the pull-request body. The two are not interchangeable: `delivered-head-sha:`
  is taken at delivery, *before* step 6's remaining obligations and step 9's
  hand-off, so it cannot carry an assertion that the author is finished — which
  is the whole content of part 4. Kept separate deliberately, and named here
  because a later reader will otherwise find two full head SHAs on one pull
  request with nothing saying how they differ.
- **Have the orchestrator ask the worker for the handshake by message**, which
  is issue #235's own proposal B. verified: `skills/campaign/SKILL.md` step 5 at
  `e604daa4d9b19d1d3f33e2a9c691a80013399af0` budgets the direct probe at one per
  agent per run, and `references/dispatch-liveness.md` owns that budget, so
  spending it on a handshake competes with the liveness question it exists for —
  and a probe reaches only an agent still mid-run, which by definition the
  author of a finished branch is not. Decision 4 reads the same fact off the
  tracker for the cost of a `gh` query.
- **Put the gate in one `references/merge-gate.md` and link it from all three
  skills.** verified: the frozen scope charter for this change (`WORK:SCOPE`
  token `q235-ee19d60c` on issue #235) permits `skills/campaign/SKILL.md`,
  `skills/quest/SKILL.md`, `skills/return-to-town/SKILL.md`, `docs/adr/0035-*`,
  and `.claude-plugin/plugin.json`, and does not permit `references/`. judgment:
  a reference is something consulted while doing something else, and this gate
  is executed inline at the one moment it matters — the indirection is worst
  exactly there. Both grounds are contestable and the consolidation is filed as
  a follow-up rather than closed.
- **Do nothing and rely on the reviewer.** judgment: two of the three reported
  failures are cases where the orchestrator queried exactly what the skill told
  it to query and got a green answer about the wrong commit. Better judgment
  does not reach a wrong premise.
