---
name: quest
description: "Implement a GitHub issue end to end through scoping, feature-branch setup, design, TDD, adversarial review, threat scan, simplification, pull-request creation, CI, and merge handoff. Use when asked to work, implement, or resolve a specific GitHub issue with the repository's full workflow."
---
Implement the supplied GitHub issue end-to-end on a feature branch, following
the repo's `AGENTS.md` conventions, and drive it to a CI-green, mergeable PR
ready for the user to merge.

Work the steps in order and keep the guardrails green at every commit. A red guardrail may be fixed
directly only when the current failure artifact or an already-recorded investigation identifies a
specific cause and the correction follows from that evidence. Familiarity, a plausible fix, or
stale evidence from another failure is not enough; without current causal evidence, run
`$detect-curse` before proposing a correction. If the same artifact recurs after the same
evidence-backed correction with no new evidence, stop instead of repeating the diagnose-fix cycle.
Don't advance past a red guardrail, an undispositioned `$gauntlet` finding, a dirty-tree surprise,
or an ambiguous user-facing design decision. A finding a `$trial-loop` run disposed of — as
`deferred-tracked` with an owner, or `rejected-with-evidence` — is dispositioned; the loop
finishes while such findings stand, and treating them as advancement blockers is the
reading the loop's residual blocking figure exists to remove.

> **One continuous task.** Preflight through hand-off -- or through cleanup on
> the authorized merge path -- is a single turn, and the checkpoints inside
> it -- a `$gauntlet` verdict, a green guardrail, green CI -- are not places
> to stop. End your turn at one of three points: step 9's recorded hand-off,
> which completes the run even though the branch and worktree stay in place;
> the finished merge and cleanup, if the operator authorized merging; or a
> blocker you have parked per *On a Blocker* -- naming it in chat is not
> enough, the issue must carry the state. As a background worker, an
> `approve` from the review loop — or any other finished run, whatever its last
> verdict — means proceed now, not wait.

> **Keep the durable facts durable.** Raw phase context -- brainstorm
> transcripts, `$gauntlet` payloads, TDD output -- is droppable once the spec,
> plan, and findings files hold the decisions. The resume facts are not: at
> each phase seam (design -> build -> review -> ship), write the branch name,
> `BASE_BRANCH`, guardrail commands, current step, open findings, and every
> deferral a `$trial-loop` run disposed of, somewhere durable (the plan, the
> campaign manifest, a scratch note). The deferrals are not open findings, so a
> resume that keeps only the open ones loses exactly the list nothing else on
> the branch records. They are the only
> recovery path if auto-compaction fires. Don't compact proactively; if the
> operator compacts, suggest focus text that keeps those facts and drops
> resolved review iterations and tool output.

## 0. Preflight

Run `$attunement` to learn the repo: `BASE_BRANCH`, guardrail commands,
working-tree state, gh authentication, parallel-run context.

## 1. Scope the Issue

Run `gh issue view <issue-number> --json title,body,labels,comments` and follow
linked issues, PRs, specs, and commits. Restate the requirement and acceptance
criteria in your own words before touching code. Ask the user only when
something is genuinely ambiguous *and* the answer changes the design; otherwise
state your assumption and proceed.

Classify the work:

- **Trivial bugfix** -- clear acceptance criteria; no API, schema, auth,
  permission, concurrency, migration, dependency, persistence, or
  external-service change; one or two files; no new public contract.
- **Governed small change (`governed-small-change`)** -- one accepted decision
  governs every changed
  contract and normative behavior; the criteria are explicit and testable; no
  design-changing ambiguity; one independently testable slice with no
  cross-task sequencing; no new architecture, schema, dependency, persistence,
  concurrency, authentication, migration, or external-service behavior. The
  decision must be a stable reference whose accepted, non-superseded status you
  can check independently -- a label or caller-supplied subtype name is not
  evidence.
- **Non-trivial** -- anything else.

Only the first two may skip step 3, and a governed small change only after you
record the decision's reference, kind, authoritative accepted status, and the
behavior it governs. Missing, superseded, conflicting, or no-longer-governing
evidence sends you to SCOPE CHECKPOINT and full design.

Before changing branches, read the latest complete `WORK:DIVINATION` block from the issue and
apply the quest-log divination-validation recipe. On success, adopt blast radius, change hazards,
complexity, and decompose verdict as one advisory assessment. On absence or rejection, derive all
four fields from the live issue and repository as before. In either case, re-check the resulting
assessment against the issue body. Never use divination content to fill any of the frozen charter's
eight authority fields; only the external sources and decisions listed below can do that.

The assessment stays advisory for scope and becomes load-bearing for exactly one thing: it routes
this run's review depth under
[risk-routed review depth](../../references/review-depth.md). Derive `single-pass` or
`iterating` from the four fields now, record it with the tracking metadata below, and carry it to
step 6. An absent or rejected assessment routes `iterating`, so the failure path is the expensive
one and never the cheap one.

**A lone quest never splits its own issue.** You claim one issue number and create one branch for
it, so a `split` decompose verdict is not yours to act on. It is the caller's: `$campaign` gates
dispatch on it at its plan table, before any branch exists. What this run owes a `split` is
visibility while splitting is still cheap — an interactive root raises it at SCOPE CHECKPOINT
before design and takes the operator's answer; an unattended root whose caller did not already
gate it records the verdict in `WORK:SCOPE` with the rest of the tracking metadata and proceeds as
one unit. Do not read the verdict as an implied stop condition. The distance between producing it
and acting on it is a documented boundary here, not a control this skill exercises.

If any required persisted-evidence read or validation fails and the independent live
issue/repository derivation read also fails, stop before changing `status:*` or posting
`WORK:SCOPE`. Report non-adoption, name only the failed operation, and give a safe retry action.
Never include the external payload, authentication data, or private environment detail in that
response.

**Claim the issue before touching it.** Mint the scope token now, in the
short form `q<issue-number>-<8 lowercase hex>` (the quest-log claim protocol
constrains the grammar), and resolve the producer login
(`gh api user --jq .login`; a failure is an auth failure — stop with the
`gh` error). Then acquire the claim:

```sh
skills/quest-log/assets/tracker.sh claim-acquire --target <owner/name> \
  <issue-number> --token <scope-token> --producer <login>
```

On exit 6, read the holder payload and the issue's status:

- Holder stale per the liveness rule → recover:
  `claim-recover <issue-number> --token <scope-token> --producer <login>
  --older-than <CLAIM_TTL if the issue carries an in-flight status, else
  CLAIM_GRACE>` and continue as the new owner.
- Holder live, interactive root → stop. Report the holder's token,
  producer, age, and the issue's status; the human decides whether to wait
  or authorize recovery (a re-invocation carrying that decision uses
  `claim-recover --force`). Ask, never assume.
- Holder live, unattended root → stop with no writes to the issue. This is
  the one exception to the park protocol: the issue belongs to a live
  quest, and any label or comment write on it is the interference the
  protocol exists to prevent. Report the blocker in the completion report;
  under `$campaign`, return it to the orchestrator as a hold.

Then verify gate **G1**: `claim-verify` immediately after acquiring or
recovering, before any mutation of the issue. Gate outcomes are exhaustive:
exit 0 → held, proceed; exit 2 or 6 → claim lost: halt immediately, make no
further mutation of the issue (labels, comments, or the claim), and report —
never retry a lost claim into re-acquisition at a gate; exit 4 → the
ordinary retryable transport path. A loser at any gate reports its local
branch path if one exists; the operator disposes of it.

Only then set the issue to `status:in-progress` (ensure-create the
`status:` labels per the quest-log recipe; single-active swap). The swap is
idempotent and not exclusive, and nothing relies on it for exclusivity. If
ensure-create fails, release the claim first (`claim-release` — the quest
owns it and is abandoning the issue), then stop with the ensure-create
message rather than proceeding label-less.

## Frozen scope charter

Freeze the complete external authority before design, as a `WORK:SCOPE`
annotation on the issue. `interaction` is `interactive` when a human invoked
this run in the active turn, `unattended` only when an orchestrator or
background task explicitly says no human is reachable; nesting never changes
the root value.

Record all eight fields:

- `scope identity` -- the issue URL plus a unique annotation token;
- `outcome` -- the requested outcome;
- `completion criteria` -- each criterion and its source;
- `provenance` -- the source of every outcome, criterion, and user decision;
- `exclusions` -- explicit exclusions and their owners, or explicit empty;
- `surface` -- permitted change surface and direct dependencies;
- `ambiguities` -- unresolved design-changing ambiguities, or explicit empty;
- `interaction` -- the root value above.

Also retain the tracking metadata (blast radius, change hazards, complexity,
decompose verdict, routed review depth, classification -- plus the decision
evidence and acceptance criteria for a `governed-small-change`) and read
everything back before proceeding.

Keep every public annotation to the minimum its fields need: public-safe source
labels for provenance, never secrets, auth headers, host paths, hostnames, IPs,
or private detail, and never log an unsafe answer. If a value cannot be
summarized safely, do not post it -- return to SCOPE CHECKPOINT with
`WORK:SCOPE` unposted; an unattended root posts only a generic public-safe
parked notice.

Every normative guarantee traces to this charter, a later explicit user
decision, or an unavoidable consequence of a sourced criterion. The workflow
cannot authorize its own scope; more review authorizes more scrutiny, not more
scope.

### SCOPE CHECKPOINT

Return here whenever an omission or conflict could change a charter field or a
normative guarantee. Interactive run: ask one design-selecting question at a
time, record the answer and its provenance, then freeze. A design-changing
answer after freezing ends the current design cycle -- re-freeze before a new
one. Missing, incomplete, or unresolvable fields never fall back to a spec,
ADR, plan, or other generated artifact.

An unattended root never answers a design-changing question itself: post a
public-safe `WORK:TRAJECTORY`, set `status:needs-human`, and stop before
design. If the checkpoint data is unsafe, the notice names only the parked
phase and the need for human input.

### Posting the annotation

Use the scope token minted for the claim (step 1) as the annotation token —
claim and charter share one identity. Include it in the comment and capture
the returned comment URL as the annotation's location, not its identity. Read
the comment back and verify the token and all eight fields before continuing,
then cross-check the annotation token against the claim token and run verify
gate **G2** (`claim-verify` again). Post
it even for a trivial bugfix that skips design -- `$resurrection` reads it as
the liveness signal.

## 2. Branch

Verify gate **G3**: `claim-verify` before creating the branch; a lost gate
halts per step 1's rule.

Fetch, sync `BASE_BRANCH` to `origin/BASE_BRANCH`, and create
`feat/<short-slug>-<issue-number>` off it. Never work on the default branch. If
a branch for this issue already exists, ask before reusing it unless the issue
or PR explicitly names it or your dispatch prompt carries the operator's reuse
decision.

**Worktree placement.** If repo instructions require an isolated worktree (or
you are a parallel agent that must not share a working tree), create it
*outside* the repo tree -- `../<repo>-worktrees/<branch>` -- and `cd` there
first. Never nest a worktree inside the repo: whole-tree tooling (linters, type
checkers, test discovery) will walk it and fail your commit on another agent's
in-flight code. If the harness's built-in isolation would nest it, run
`git worktree add <external-path>` yourself.

### Governed small change path

Immediately before taking the abbreviated path, re-resolve the governing
decision: confirm its kind, accepted and non-superseded status, governed
behavior, and fit against the live issue criteria, and confirm the work is
still one independently testable slice with no new excluded decision or
ambiguity. A failed check returns to SCOPE CHECKPOINT -- re-freeze the charter
and run step 3, without automatically reselecting the abbreviated path in that
design cycle.

On the abbreviated path the verified `WORK:SCOPE` goes straight to `$forge`
-- no new spec or plan -- and the first executable action is the focused failing
test from step 5; proof comes before any optional design elaboration. Branch
review, simplification, guardrails, PR creation, CI, and merge handoff all
still happen.

## 3. Design

Pass the frozen charter to `$spellcraft` exactly as follows:

interaction: <unchanged root value>
scope identity: <external scope identity, never reviewed target>
outcome: <frozen external outcome>
completion criteria: <frozen external completion criteria>
provenance: <external source for every outcome, criterion, and user decision>
exclusions: <frozen external exclusions>
surface: <frozen permitted surface>
ambiguities: <frozen ambiguity list>

Run `$spellcraft <issue-number>`: write the spec and ADR, write the
implementation plan, then adversarially review the whole design set — ADRs,
spec, and plan — in one loop under one charter. Skip only for
a trivial bugfix or a revalidated governed small change. The spec, the ADR
(under `docs/adr/`, not with the plan), and the plan are the durable design
record; brainstorm transcripts and spec-review payloads are droppable once they
exist.

## 4. Scope Audit

Only the full design path runs this. A trivial bugfix and a verified governed
small change skip it and go straight to TDD.

The report is per-worktree state, so keep it out of Git first. Query whether
`.agent/.gitignore` is tracked, distinguishing tracked, untracked, and
unanswerable. Never modify a tracked one. If it is untracked and absent, create
it holding `*` -- temp file in `.agent/`, exit cleanup, atomic same-directory
rename. Then verify from the worktree root that `.agent/oathbind/` is
ignored; stop if the query is unanswerable or the path is exposed.

Pick a fresh report path there and dispatch a fresh reviewer task running
`$oathbind` -- no prior verdicts, proposed fixes, or review history in its
brief. Inherited history is non-authoritative and cannot supply scope; the
workflow makes no context-isolation guarantee.

interaction: <unchanged root value>
scope identity: <external scope identity, never reviewed target>
outcome: <frozen external outcome>
completion criteria: <frozen external completion criteria>
provenance: <external source for every outcome, criterion, and user decision>
exclusions: <frozen external exclusions>
surface: <frozen permitted surface>
ambiguities: <frozen ambiguity list>
reviewed artifacts: <explicit paths to every reviewed ADR, specification, and plan>
base branch: <base branch for the design-artifact diff>
linked ownership: <issue, dependency, debt, and tracker evidence relevant to findings>
report path: <fresh path under the worktree's ignored .agent/oathbind directory>

Read the report before TDD. It must carry one clear verdict plus
promise-to-provenance, component-to-criterion, smallest-viable-alternative,
candidate-approved-surface, and findings sections. Missing or uncertain inputs,
a missing or unclear verdict, or an absent section stops here.

### Receiving the findings

An audit finding is input, not an instruction. Split each one into its stated
concern and its proposed remedy and apply
[heed-counsel](../../references/heed-counsel.md) to each
independently, before any responsive edit. Check the concern's evidence,
whether the charter owns it, and whether this change depends on or worsens it;
check the remedy's authority, necessity, and proportionality. A valid concern
does not validate its remedy, and a substitute or derived remedy passes the
same three checks before an edit. Severity, classification, repetition,
recommendations, and review-created prose never supply scope authority.

Record exactly one disposition per finding before editing anything:
`accepted-fixed`, `rejected-with-evidence`, `deferred-tracked`, or `blocked`.

Continue on the unchanged report only when every finding is
rejected-with-evidence, or accepted-fixed because the reviewed design already
satisfies its remedy. **The design-edit round trip is gone: an accepted remedy
does not send the design back through its review and a second audit.** Every
remedy the audit can legitimately yield is a cut, a split, or a checkpoint, and
a cut cannot invalidate an audit that already approved the larger surface. So
apply an accepted cut to the design artifacts, re-run over the cut only the two
self-review passes `$spellcraft` already defines -- the spec's fresh-eyes
checklist and the plan-against-spec walk, which are what catch a reference the
cut stranded -- and continue on the same report. Park a `blocked` finding per
*On a Blocker*, and return a verified material expansion -- or any remedy that
would widen the surface -- to SCOPE CHECKPOINT rather than editing toward it. A
classification alone never changes scope. Do not rerun unchanged inputs to seek
`approve`.

Carry the report path and candidate approved surface forward as the
design-to-build checkpoint. A cut this step applied in response to a finding is
accounted for by the report that asked for it. Two things are not, and each
warrants a fresh audit on `$oathbind`'s own terms: a verified ownership change,
and a reviewed design artifact otherwise known or observed to change before TDD.
On either, invalidate the report and audit again -- the workflow does not claim
to detect arbitrary out-of-band edits.

## 5. Build With TDD

Before calling `$forge`, resolve its workspace with `scripts/sdd-workspace` and
set `FORGE_LEDGER=<workspace>/progress.md`. Read the current issue number and
the frozen `WORK:SCOPE` annotation token that this quest already validated, then
set `FORGE_HANDOFF=<workspace>/quest-forge-handoff-<issue>-<scope-token>.md`.
The workspace must be a regular private mode-0700 directory; the ledger,
handoff, retained review, summary, and helper body must be regular private
mode-0600 files while this workflow owns them. Check those modes before each
retain, parse, or publication transfer; a missing, non-regular, symlinked, or
non-private path parks rather than being repaired or followed.
That pair is the ignored build-to-ship identity; do not derive it or any
`FORGE_*` value from conversation memory. A new issue or scope token gets a new
record without a global cleanup protocol. If this exact handoff already exists,
parse and validate it before doing any build work: `publication-verified`
follows its verified-resume route directly to step 9,
`publication-in-progress` enters step 8's explicitly authorized recovery check and otherwise
parks, and `build-complete` resumes from the parsed handoff without calling `$forge` again. A parsed `required-failed` parks under
its mode rule below. Never replace an existing same-issue, same-scope handoff.

Only when `FORGE_HANDOFF` is absent, run `$forge` to implement the plan and run
the guardrail suite, passing the plan path if one exists. For a
`governed-small-change`, pass the classification and revalidated decision
evidence (reference, kind, accepted status, governed behavior, acceptance
criteria) -- and no plan path. Require forge's ledger result to equal the
expected `FORGE_LEDGER`. Create the new handoff with `mktemp` in that directory,
mode 0600, and byte-for-byte read it back before installing it with an atomic
no-replace primitive. If the destination appears at any point, do not overwrite
it: discard the temporary file, parse the existing handoff, and take its phase
route. Its exact line-oriented format is:

```text
format: quest-forge-handoff-v1
phase: build-complete
issue: <exact issue number>
scope-token: <exact frozen WORK:SCOPE token>
repo: <exact owner/repository>
forge-mode: <required|not-required|required-failed>
forge-range: <full-base-sha>..<full-head-sha>|not-required
forge-review-or-reason: <exact path or verified reason>
forge-ledger: <exact path>
forge-result-record: <exact forge ledger line>
branch: <exact branch>
base-branch: <exact BASE_BRANCH>
guardrail: <one exact passed command>
review-summary: <ledger-directory>/quest-review-summary.md
```

Write one `guardrail:` line per command, with the preserved command text. All
values are single-line UTF-8 text without carriage return or NUL; refuse an
unrepresentable value instead of escaping or normalizing it. Before the rename,
read the temporary file back byte-for-byte. On resume, require this exact
format: each displayed scalar field occurs once, `guardrail:` occurs at least
once, no unknown or duplicate scalar field occurs, and every value is
non-empty. `build-complete` has no `pr:` or `review-comment-url:` field;
`publication-in-progress` adds exactly one `pr:`, `delivered-head-sha:`, and
`review-payload:` field; and `publication-verified` adds exactly one `pr:`,
`delivered-head-sha:`, `review-payload:`, and `review-comment-url:` field. `review-payload:` is
the exact absolute private payload path or the literal `none`. A path must be a regular,
non-symlink direct child of the physical directory containing `FORGE_LEDGER`: resolve and compare
its parent before reading content, and reject a different parent, a nested descendant, or lexical
traversal rather than normalizing it into acceptance. Both SHA fields are
full immutable object IDs, never abbreviations. Parse only this record to set
the issue, scope token, `REPO`, `FORGE_MODE`, `FORGE_RANGE`,
`FORGE_REVIEW_OR_REASON`, `FORGE_LEDGER`, `REVIEW_SUMMARY`, branch,
`BASE_BRANCH`, and guardrails; require the issue and scope token to equal the
current frozen charter, and paths, repository, branch, and base to match the
live checkout. The sole format exception is a legacy `publication-in-progress` handoff written
before ADR 0048: it may omit `review-payload:` only for the explicitly authorized recovery route,
which requires the human-supplied payload reconciliation specified below. It remains parked on every
other route. On every resume, require `forge-result-record` to be one whole,
exact line in the named ledger. In
`required` mode it must be the retained record for `forge-range` and name the
exact handoff review and ledger paths. In `not-required` mode it must be
forge's exact verified not-required record and name the exact reason and ledger
path. `required-failed` must likewise match its exact failed record. Re-read
the record and named ledger before step 6. A malformed, stale, unrelated,
missing, changed, or mismatched handoff is a shipping blocker, never a default
or reconstructed value.

Artifact checks are phase-qualified. In `build-complete`, `required` needs its
exact retained review to be regular, private mode-0600, non-empty, and readable;
`not-required` needs its exact verified reason. `publication-in-progress` parks
without a source-artifact assumption unless it takes step 8's recovery route, which revalidates
every retained input. In `publication-verified`, the review,
summary, and body are expected to be disposed: require the exact all-and-only
disposal record, not a readable source artifact.

On a verified-publication resume, require `review-comment-url` to parse as
`https://github.com/<repo>/pull/<pr>#issuecomment-<id>`, with the record's
current `repo`, current `pr:`, and numeric `<id>`. Require it to equal the URL
in the exact `review-publication-verified: <URL>` ledger line after this
handoff's `forge-result-record`, then re-read its exact disposal record. In
`required` mode, it must own only the exact retained review, `REVIEW_SUMMARY`,
and one helper-created body in the ledger directory. In `not-required` mode,
it must own only the exact `REVIEW_SUMMARY` and that one body. When the preserved
`review-payload:` is a path rather than `none`, that exact payload must be the final owned path in
either mode; when it is `none`, no payload path may appear. Only then skip
directly to step 9. Do not rerun `$deliver`, recreate the summary, invoke the
publication helper, or post a second `WORK:REVIEW` comment.
Before step 9, re-resolve that PR and require its repository, number, head
branch, base branch, and full `headRefOid` to equal the record's `repo`, `pr:`,
branch, `BASE_BRANCH`, and `delivered-head-sha:`. A changed or missing PR parks.
`publication-in-progress` remains parked for human reconciliation unless step 8 receives explicit
authority for one recovery attempt and every recovery predicate passes. Only `build-complete`
continues through review and shipping automatically.

There are three forge modes:

- In `build-complete`, `required` requires a regular, non-empty, readable
  retained review and its exact ledger path. A missing, empty, unreadable, or
  non-regular review is a shipping failure, not a reason to rerun or downgrade
  the review.
- `not-required` requires the verified public-safe reason from forge and never
  invents review content.
- `required-failed` is terminal. Park the issue before step 6 or `$deliver`,
  naming the failed review and retained local evidence in the private report;
  it must never reach PR creation or publication.

## 6. Adversarial-Review the Branch

**Route the depth before dispatching anything.** Step 1 derived this run's review depth from
the divination assessment; re-derive it now against the branch diff, because the fourth
condition in [risk-routed review depth](../../references/review-depth.md) is a
security-relevance judgment and no diff existed at step 1. A diff that trips the security
triggers listed below in this step routes `iterating` whatever step 1 recorded, and so does any
other condition that has since stopped holding. Name the routed depth in the transcript, with
what moved it if it changed.

Set the issue to `status:in-review` (single-active swap), then review the branch at that depth
with this focus:

> Focus on auth, permissions, data loss or corruption, rollback, idempotency, races, empty or
> malformed inputs, degraded dependencies, compatibility, migrations, observability, and whether
> the chosen approach is simpler or safer than viable alternatives.

On `iterating`, run `$trial-loop --base <BASE_BRANCH> <that focus>`. On `single-pass`, dispatch
the one reviewer pass the reference specifies, with the same `--base` and the same focus, and
give each finding its single disposition. Address every defensible finding and commit after each
accepted fix, on either route.

**A blocking finding on a single pass escalates rather than being fixed in place.** Record the
escalation and the finding that caused it, then run the `$trial-loop` invocation above against
the same branch at its ordinary budget, starting at iteration 1 — the single pass is not one of
that run's iterations. From that point this step reads exactly as it does for a run routed
`iterating` at step 1. A `single-pass` review that returns `approve` carrying only notes is a
completed review, and step 8's summary records it as `exit: none` with `iterations: 1`.

**Carry the issue's cumulative review-round figure through every run here.** Seed it with
the design phase's total where `$spellcraft` reported one, `0/0` otherwise, pass it to each
`$trial-loop` run on this branch as its `prior_rounds` — the branch review, an escalated run
after a single pass, a re-run after the security round trip, a re-run after `$dispel` — and
count each `single-pass` dispatch as one round. Report the figure the loop returns in the
transcript beside the routed depth. It is what makes the issue's whole review cost visible in
one place; per-run reports are individually accurate and sum to nothing a reader can see.

**Route on finished-versus-blocked, which the loop states outright** — never on the
last verdict. A finished run's last verdict is `approve` when the reviewer cleared the
branch, and `needs-attention` when the only blocking findings left were ones that run
had already dispositioned as owned deferrals or rejected with evidence. Both advance
this workflow. Reading the second as blocked reports a finished branch as stuck.

Carry every deferral from any `$trial-loop` run on this branch — each entry with
its owning record path or tracker issue — into the `WORK:REVIEW` comment and the
PR body, however the run ended, `approve` included. Carry the run's
`rejected-with-evidence` findings and its outstanding notes the same way. The loop
discloses all three however it ended, and a second run after a security round trip
does not erase the first run's records. Those lists are the part a reader cannot
reconstruct, and they are the only thing holding the orchestrator's own disposition
judgment to account.

Step 8 publishes these lists through ADR 0028's two writable destinations: the
publication helper's payload slot puts them in the `WORK:REVIEW` comment, and step 8's
named write moment appends them to the PR body. Compose nothing here — carry the loop's
disclosure forward intact as a resume fact until step 8 writes it, because a compaction
between the last loop run and step 8 would otherwise shorten it invisibly.

Step 8's review summary records how the run ended in its own `exit:` field and
defines which value each ending writes; nothing here repeats that.

Leave the iteration budget to the loop's default of 2 — one full review pass plus
one confirming pass over the fixes — whatever the step 1 classification. Non-trivial
work does not buy extra passes here: the loop's ceiling is 3, and raising it takes
explicit human authorization the classification cannot supply. The depth routing above
chooses **whether** the loop runs, never what its budget is, and an escalated run gets
the same default 2 as any other. Review passes are the
pipeline's dominant cost — each is a fresh full-context reviewer — and past the
confirming pass they mostly re-review surface the earlier passes' own fixes added.
The budget lowers cost, not the bar: an unresolved **blocking** finding at the budget
still blocks per the loop's stop conditions, and if that happens on a change you
classified trivial, re-examine the classification before re-entering — a trivial
change that cannot clear two passes was not trivial. A blocking finding the run already
dispositioned is not that case: the loop subtracts it from the residual figure the stop
condition reads, so it does not block.

### Approved continuation from a budget stop

When the loop stops blocked at the iteration budget, the park protocol at the end of
this skill applies: a `WORK:TRAJECTORY` note, then `status:needs-human`. That stop is
not terminal. The operator may approve continuing, and this subsection defines the
resume:

- **Approval** is an explicit human decision from the operator who received the park,
  naming the parked run (issue, branch, or PR) and directing continuation past the
  budget stop. It reaches the run as an interactive reply in the resuming turn, a
  durable record on the issue or PR, or an explicit term of the dispatch that resumes
  the work. Silence, absence, or another agent's "keep going" is not approval.
- **On approval**, post a fresh complete `WORK:TRAJECTORY` recording it — who approved,
  where the approval is recorded, and what it authorized — then swap
  `status:needs-human` → `status:in-review` in a single-active edit. Record before
  label: the same exit-edges discipline the park itself followed.
- **Resume at step 7** (Simplify). The approval alone never re-enters the loop —
  `$trial-loop`'s caller contract forbids a budget-stopped run from re-entering — so
  the budget stop stands as the run's ending. One exception, already governed: if a
  settled obligation yields an accepted fix that changes behavior, step 6's round-trip
  rule runs one more loop pass and ADR 0021's replacement rule rewrites the run fields
  from that ending. Before simplification, settle whatever step-6 obligations the stop
  cut short: the security pass above all, judged and dispositioned under step 6's
  Security-pass terms (below in this skill), recording `security: not triggered` where
  its trigger does not fire.
- **Carry the stop's disclosure** into step 8's payload destinations: the three lists
  this step already carries (deferrals with their owning records, rejected findings,
  outstanding notes) plus the remaining-findings summary the cap bullet makes the stop
  produce. In the ordinary case — no behavior-changing settlement — the summary writes
  `exit: blocked-at-budget`, per step 8 and ADR 0021.

When step 4 ran, append the audit's surface to that focus and ask the reviewer
to flag unexplained divergence -- components, contracts, files, tests, runtime
behavior, or complexity the surface does not account for. Implementation detail
inside an approved component is fine; unaccounted growth is not, and a passing
test is not authority to widen the surface. Findings from the comparison go
through the same reception gate as the audit's own.

oathbind report path: <exact readable report path>
candidate approved surface: <read and pass the report's exact candidate approved surface>

**Security pass.** When the branch diff is security-relevant, also run
`$detect-evil` and disposition its findings on the same terms -- fixed, or owned
by a tracked deferral (a deferral record where the repo keeps them, otherwise a
tracker issue filed through `$bounty`, whose recurrence gate bounds instance
growth and routes an unreachable-in-practice finding to record-and-close rather
than the open queue). Non-blocking: `needs-attention` is work to do, never a
reason to park.

Dispatch it the way `$trial-loop` dispatches its reviewer -- a subagent running
`$detect-evil --json --out <path> --base <BASE_BRANCH>`, artifact on a
scratchpad path outside the repo tree. Invoked bare it returns full markdown
inline: a findings payload in your context at step 6 of 9, the cost this
dispatch exists to avoid. Two properties make it safe:

- **A path unique to this run** -- embed the issue number and branch name.
  `$campaign` runs up to five `$quest` subagents in parallel, and a fixed
  filename collides silently: one issue's findings dispositioned against
  another's branch. Assert the compact object's `run_id` matches the artifact's
  before acting -- the only detector.
- **Open the artifact when `findings_count > 0` *or* `suppressed_count > 0`.**
  `blocking_count` says whether the loop iterates; `findings_count` is what says
  whether there is anything to read, and an `approve` carrying notes has a non-zero
  `findings_count` with a zero `blocking_count` — those notes still need their one
  disposition, so the trigger stays on `findings_count`.
  A non-zero `suppressed_count` on `approve` means an accepted ADR silenced a
  security finding -- the one case the verdict cannot show. Record any
  suppression in `WORK:REVIEW` and the PR body whatever the verdict; the
  summary's fields are single-line and none of them holds a suppression.

Judge security-relevance by reading the changed files, not the issue's
description of itself. The diff qualifies when it:

- changes what an untrusted actor can reach or cause -- a new or widened entry
  point (route, handler, CLI argument, env var, config key, webhook, queue
  consumer), or a change to who may call an existing one;
- touches authentication, authorization, session, or tenancy logic -- including
  an entry point added beside siblings that carry such a check;
- handles a secret, or edits CI config that does;
- parses or deserializes input it did not produce -- request bodies, uploads,
  archives, formats that construct objects while decoding;
- builds a command, query, path, URL, or template from a non-literal value;
- widens a permission grant -- workflow permissions, CI token scope, a sandbox
  or guardrail exemption;
- changes a dependency, lockfile, or pinned CI action reference;
- alters file modes, network exposure, TLS or certificate handling, or a
  security-relevant default.

When none apply, skip the pass. When you genuinely cannot tell, run it -- one
subagent and a compact object, so the asymmetry favors running. Do not run it
on every diff to be safe: a pass that finds nothing on everything teaches the
operator to skim.

Run the scan **after** the `$trial-loop` fixes, so it sees the code that
ships. If closing a security finding changes behavior, re-run `$trial-loop` on
the result (its review did not cover the fix) and then run `$detect-evil` once
more: at most one `$detect-evil` -> `$trial-loop` -> `$detect-evil` round trip.
If a second round trip would be needed, do not re-enter and do not park --
carry on to step 7 and record the unresolved findings as open in
`WORK:REVIEW` and the PR body, beside the summary. The cap is a reporting
boundary, not a blocker.

Record the verdict in the review summary either way, including
`security: not triggered` when the pass did not run, so `WORK:REVIEW` says
which arms ran. `$detect-evil` is a weaker instrument than the built-in
`/security-review`, which only a human can invoke; `$return-to-town`'s hand-off
is where a human is reliably present to run it.

## 7. Simplify

Run `$dispel` on the branch diff, re-run the guardrails, and commit.
Quality only -- do not reopen settled design decisions. Step 6 reviewed the
pre-simplify code, so if simplification changed behavior (anything beyond a
pure rename or format), re-run `$trial-loop` -- or at minimum `$gauntlet` --
on the simplified diff before shipping; guardrails only catch what the tests
already assert.

## 8. Ship It

Verify gate **G4**: `claim-verify` before running `$deliver`; a lost gate
halts per step 1's rule.

In `build-complete`, re-read the build-to-review handoff before delivery. Only `required` and
`not-required` may proceed; `required-failed` or any unreadable required
artifact parks the quest before `$deliver`.

Run `$deliver <issue-number>` to push the branch, create the PR, and drive it
to green CI and mergeable state. Keep a compact public review summary — the
fields below — as
an ignored private mode-0600 file beside the forge ledger; do not put outer
annotation markers or forge-review payload in it. `REVIEW_SUMMARY` is the exact
`review-summary:` path in the parsed handoff, not an ad-hoc filename. The
verbose per-iteration findings file is droppable.

After `$deliver` reports the PR, resolve it once and verify its repository,
number, head branch, base branch, and `headRefOid`. They must equal `REPO`, the
returned `PR`, the handoff branch, `BASE_BRANCH`, and `git rev-parse HEAD`
respectively. A missing, changed, or mismatched value parks before summary
creation and before the helper; never publish a review for an unverified PR
head. Persist that full `git rev-parse HEAD` value as `delivered-head-sha:`
when writing the `publication-in-progress` handoff.

After `$deliver` creates the PR, create that summary once with `mktemp` beside
the ledger and atomically rename it only after writing these exact, non-empty
single-line fields in order:

```text
verdict: <trial-loop reviewer verdict>
exit: <trial-loop run outcome, or none>
findings: <count>
iterations: <count>
security: <$detect-evil verdict or not triggered>
delivered-head-sha: <full exact delivered PR head SHA>
```

`verdict:` and `exit:` are two facts about the same run — the last `$trial-loop`
run on the branch, the one `findings:` and `iterations:` already count.
`verdict:` is the verdict the selected reviewer actually returned on the last
pass, never derived from the exit. `exit:` is one of two values, by how that run
ended:

- `none` — the run finished. Its last verdict is `approve` where the reviewer
  cleared the branch and `needs-attention` where the only blocking findings left
  were ones the run had already dispositioned; `exit:` does not distinguish those,
  because neither is blocked and `verdict:` already carries the difference.
- `blocked-at-budget` — a run stopped as blocked at the iteration budget, then
  continued through step 6's approved-continuation resume path. `verdict:`,
  `findings:`, and `iterations:` describe that stopped run; the approval is its
  aftermath, not a second ending.

Every other stop parks the quest before `$deliver` and publishes no summary at
all, a cycle ended for rescoping without new authority included, so there is no
run that reaches this field with nothing to write.

ADR 0053 is the authority for this field's values, amending ADR 0021, which
remains the authority for the field set. A run's payload — the lists step 6 carries:
deferrals with their owning paths or tracker issues, rejected findings, outstanding
notes, and a budget stop's remaining-findings summary — stays out of
the summary and out of every field: ADR 0028 sends it through the helper's payload
slot into `WORK:REVIEW` and through this step's named write moment into the PR body,
which is where `$trial-loop`'s own report obligation sends it.

If step 6 carried any of the lists it specifies — a deferral list, rejected findings,
outstanding notes, or a budget stop's remaining-findings summary — compose
the run's payload file once, immediately after the summary: write only the lists step 6
specifies into a `mktemp` file beside the ledger — no headings; each destination adds
its own — atomically rename it only after the write, reject carriage return, NUL, and
outer annotation markers, and keep the temporary and installed payload in mode 0600.
A run with nothing to carry creates no payload file and skips every payload step below.
Before any PR-body write, invoke the helper in validation-only mode with the exact publication
arguments:

```sh
skills/quest/scripts/publish-forge-review --preflight \
  "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
  "$FORGE_LEDGER" "$REVIEW_SUMMARY" "$REVIEW_PAYLOAD"
```

Require its sole stdout line to be `preflight-ok`. This mode validates and composes only: it must
not call GitHub, append the ledger, dispose a source, or retain its temporary body. On nonzero or
any other output, park with the `build-complete` handoff and retained evidence; do not write the PR
body or `publication-in-progress`. That is a local pre-write failure, not a consumed publication
attempt.

Then make the one named PR-body write, ADR 0028's second destination: read the
delivered PR body, append a blank line, the `## Review exit payloads` heading, and the
payload file's contents, write the result back with `gh pr edit --body-file`, and
require the readback to match the composed body byte-for-byte apart from at most one
trailing newline, which GitHub's PR-body storage adds. This is the only moment the PR body gains the section — before the
`publication-in-progress` handoff rewrite, so the write never happens in the terminal
parked phase and never happens twice — and a failed or unverifiable write parks the
quest before the helper with the evidence retained.

Reject carriage return, NUL, outer markers, or any failed byte-for-byte
readback before rename; the temporary and installed summary both stay mode 0600.
If the summary already exists, do not overwrite or recreate it: park for human reconciliation
with the retained evidence. A handoff already in `publication-in-progress` follows the recovery
rule below and otherwise parks. After successful preflight and any required PR-body write,
atomically rewrite and byte-verify
the private mode-0600 handoff with phase
`publication-in-progress` plus one `pr: <number>` and one
`delivered-head-sha: <full SHA>` field and one `review-payload: <absolute path|none>` field. On every resume, that phase is parked by default because a
prior comment write may be ambiguous.

Immediately before the helper, re-resolve that exact PR. Require its repository,
number, head branch, base branch, and full `headRefOid` to equal `REPO`, `PR`,
the handoff branch, `BASE_BRANCH`, and `delivered-head-sha:`. A mismatch parks
before posting. Transfer the summary file's lifecycle to the publication helper
and invoke it exactly once:

```sh
skills/quest/scripts/publish-forge-review \
  "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
  "$FORGE_LEDGER" "$REVIEW_SUMMARY" "$REVIEW_PAYLOAD"
```

`REVIEW_PAYLOAD` is the payload file's path, empty when this run carries nothing;
the helper treats an empty seventh argument exactly as absent.

The helper is the sole `WORK:REVIEW` writer. It validates the required review,
the verified not-required reason, and any carried payload, posts one complete
annotation, reads it back,
records verification, and recoverably disposes its owned scratch files. On
nonzero, do not retry, do not post another `WORK:REVIEW`, and park the quest
with the helper's retained evidence and failure output; leave the handoff in
`publication-in-progress`. On success, capture its sole verified comment URL,
require it to parse for this exact `REPO` and `PR`, and require the exact
`review-publication-verified: <URL>` line to occur after this handoff's
`forge-result-record`. Then require the subsequent disposal record to own all
and only its former paths: in `required` mode the exact review,
`REVIEW_SUMMARY`, and one helper-created `.publish-forge-review.*` body beside
the ledger; in `not-required` mode the exact `REVIEW_SUMMARY` and that one
body; and, when this run carried a payload, the exact `REVIEW_PAYLOAD` in both
modes, named last in the record. The body entry must be in the ledger directory
and be the helper's
single generated body identity, not an inferred or older path. Only then
re-resolve the PR and require its repository, number, head branch, base branch,
and full `headRefOid` to still equal the handoff and summary values. If the head
changed after the one comment, park without a retry or a second comment; record
the verified URL and the old full SHA, which the public summary visibly scopes.
Only an unchanged PR permits the private mode-0600 handoff to be atomically
rewritten and byte-verified as `publication-verified` with the PR number, the
preserved `delivered-head-sha:`, preserved `review-payload:`, and
`review-comment-url: <verified URL>`. Carry
that URL into step 9; `$return-to-town` needs no forge-scratch cleanup.

### Human-authorized publication recovery

Never enter this route from `build-complete`, and never infer its authority from a request to
finish, resume, ship, merge, or run a campaign. A parsed `publication-in-progress` handoff may
make one recovery attempt only when the human explicitly authorizes recovery of that exact PR's
forge-review publication.

Revalidate the handoff and forge-result record under step 5, then require all of the following:

- the live repository, PR number, head branch, base branch, and full `headRefOid` equal the
  handoff, including `delivered-head-sha:`;
- the exact retained review or not-required reason, ledger, summary, and optional payload are the
  original private inputs and pass the same phase-appropriate checks as `build-complete`; for a
  new-format handoff, parse the payload only from its exact `review-payload:` path or `none` value;
- a legacy `publication-in-progress` handoff without `review-payload:` is admissible only when the
  human explicitly supplies the exact payload path or `none` for this PR in addition to authorizing
  recovery; require a supplied path to satisfy the handoff's direct-child confinement and validate
  it as an original private input before reading its content, then append and read back
  `review-publication-payload-reconciled: <path|none>` before preflight; a current PR-body or
  filesystem absence never supplies this value, and an existing reconciliation record must match
  exactly or recovery parks;
- after the handoff's exact `forge-result-record`, the ledger contains no
  `review-publication-verified:` line, no `review-publication-disposed:` line, and no
  `review-publication-recovery-authorized:` line;
- the PR contains no complete comment whose first whole line is `<!-- WORK:REVIEW -->`, whose body
  contains this exact summary, and whose last whole line is `<!-- REVIEW:COMPLETE -->`; treat an
  unreadable or inconclusive comment list as a match and park; and
- the validation-only helper invocation above succeeds with the exact retained inputs.

Apart from the legacy reconciliation record explicitly required above, any mismatch parks without
changing the ledger or invoking the publication helper in normal mode.
Immediately before the attempt, re-resolve the PR and repeat the identity and complete-comment
checks. Then append and read back this exact private ledger line, substituting the handoff values:

```text
review-publication-recovery-authorized: pr <number> head <full-sha>
```

That append consumes the authorization before the external write. Invoke the normal helper
exactly once with the same inputs. A nonzero exit leaves the recovery line in place and parks
permanently; neither this run nor a resume may attempt again. On success, apply every existing
comment-identity, readback, disposal, unchanged-HEAD, and `publication-verified` check above. The
absence checks narrow a human-authorized exceptional recovery; they never become permission for
an automatic retry.

## 9. Hand Off, or Merge if Authorized

Run `$return-to-town`. Its default is hand-off: it records the hand-off, tells
the user the PR is ready to merge, and stops there -- short of its "After a
merge" list. A `$campaign`-dispatched run always takes that path, so hand-off
is a terminal stop, not a step to clean up after. On that path, leave the
branch and the worktree in place for whoever merges; the reclaim is theirs.

When this path is authorized to merge, apply
[the commit-bound merge gate](../../references/merge-gate.md). The reference is the complete
normative gate; the default hand-off path still stops without merging.

**Your terminal state is `MERGE-READY: #<PR> @ <HEAD_SHA>`, not "the PR is green".** You
do not merge, so parts 1–3 are what you observe and part 4 is what you write:
`$return-to-town` puts that line in the hand-off `WORK:TRAJECTORY` comment, and your
completion report quotes it. Emit it only after the review loop has terminated by approval,
a named non-blocking exit, or an approved continuation from a budget stop. A green pull
request while step 6 is still running is not ready. A parked run writes no handshake.

Cleaning up branches and worktrees belongs to the operator-authorized merge
path, where `$return-to-town` merged and its "After a merge" list applies.

## On a Blocker -- Park the Issue

Reachable from any step. A named blocker is not a clean exit until the issue
records it, in this order:

1. **Post the `WORK:TRAJECTORY` note first** -- the parked phase (which step),
   the live branch and PR if either exists, guardrail status, and exactly what
   a human must decide or supply. The exit-edges rule (quest-log skill)
   requires the note before the label, so an issue never parks without a record
   of where.
2. **Then set the label** (ensure-create it first; single-active swap):
   - **`status:blocked`** -- an external dependency: an unmerged upstream PR, an
     absent credential or service, a decision owned by someone not in this
     turn.
   - **`status:needs-human`** -- the pipeline itself cannot proceed: a guardrail
     that cannot be made green, a `$trial-loop` finding you cannot resolve or
     reject, a design question only the operator can settle. A `$trial-loop`
     budget stop parks here too, and it is the one park with a defined resume:
     step 6's approved-continuation path.

Do not count on `$resurrection` to catch an unlabeled park: its reset
requires no PR *and* no matching branch, and a parked run almost always left a
branch, so the sweep re-labels the issue to match its PR -- *in flight*, not
parked. The label is the only thing that says *parked*.

If a `$campaign` dispatched you, you still own this write -- the orchestrator
does not duplicate it. Report the blocker in your completion report too, so the
orchestrator records its manifest row and keeps draining the queue.
