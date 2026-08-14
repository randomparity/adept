---
name: quest
description: "Implement a GitHub issue end to end through scoping, feature-branch setup, design, TDD, adversarial review, threat scan, simplification, pull-request creation, CI, and merge handoff. Use when asked to work, implement, or resolve a specific GitHub issue with the repository's full workflow."
---
Implement the supplied GitHub issue end-to-end on a feature branch, following
the repo's `AGENTS.md` conventions, and drive it to a CI-green, mergeable PR
ready for the user to merge.

Work the steps in order and keep the guardrails green at every commit. Don't
advance past a red guardrail, an unresolved `$gauntlet` finding, a dirty-tree
surprise, or an ambiguous user-facing design decision.

> **One continuous task.** Preflight through hand-off -- or through cleanup on
> the authorized merge path -- is a single turn, and the checkpoints inside
> it -- a `$gauntlet` verdict, a green guardrail, green CI -- are not places
> to stop. End your turn at one of three points: step 9's recorded hand-off,
> which completes the run even though the branch and worktree stay in place;
> the finished merge and cleanup, if the operator authorized merging; or a
> blocker you have parked per *On a Blocker* -- naming it in chat is not
> enough, the issue must carry the state. As a background worker, an
> `approve` from the review loop means proceed now, not wait.

> **Keep the durable facts durable.** Raw phase context -- brainstorm
> transcripts, `$gauntlet` payloads, TDD output -- is droppable once the spec,
> plan, and findings files hold the decisions. The resume facts are not: at
> each phase seam (design -> build -> review -> ship), write the branch name,
> `BASE_BRANCH`, guardrail commands, current step, and open findings somewhere
> durable (the plan, the campaign manifest, a scratch note). They are the only
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

Set the issue to `status:in-progress` (ensure-create the `status:` labels per
the quest-log recipe; single-active swap). If ensure-create fails, stop
with its message rather than proceeding label-less.

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
decompose verdict, classification -- plus the decision evidence and acceptance
criteria for a `governed-small-change`) and read everything back before
proceeding.

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

Mint the annotation token once, include it in the comment, and capture the
returned comment URL as the annotation's location, not its identity. Read the
comment back and verify the token and all eight fields before continuing. Post
it even for a trivial bugfix that skips design -- `$resurrection` reads it as
the liveness signal.

## 2. Branch

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

Run `$spellcraft <issue-number>`: write the spec and ADR, adversarial-review the
spec, write the implementation plan, adversarial-review the plan. Skip only for
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
satisfies its remedy. Otherwise send an accepted design edit back through its
applicable review and a new audit, rerun after a verified ownership change,
park a `blocked` finding per *On a Blocker*, and return a verified material
expansion to SCOPE CHECKPOINT. A classification alone never changes scope. Do
not rerun unchanged inputs to seek `approve`.

Carry the report path and candidate approved surface forward as the
design-to-build checkpoint. If a reviewed design artifact is known or observed
to change before TDD, invalidate the report and audit again -- the workflow
does not claim to detect arbitrary out-of-band edits.

## 5. Build With TDD

Run `$forge` to implement the plan and run the guardrail suite, passing the
plan path if one exists. For a `governed-small-change`, pass the classification
and the revalidated decision evidence (reference, kind, accepted status,
governed behavior, acceptance criteria) -- and no plan path.

## 6. Adversarial-Review the Branch

Set the issue to `status:in-review` (single-active swap), then run
`$trial-loop --base <BASE_BRANCH> Focus on auth, permissions, data loss or
corruption, rollback, idempotency, races, empty or malformed inputs, degraded
dependencies, compatibility, migrations, observability, and whether the chosen
approach is simpler or safer than viable alternatives.` Address every
defensible finding and commit after each accepted fix.

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
tracker issue). Non-blocking: `needs-attention` is work to do, never a reason
to park.

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
  A non-zero `suppressed_count` on `approve` means an accepted ADR silenced a
  security finding -- the one case the verdict cannot show. Record any
  suppression in the review summary whatever the verdict.

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
carry on to step 7 and record the unresolved findings as open in the review
summary, so they reach `WORK:REVIEW` and the PR. The cap is a reporting
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

Run `$deliver <issue-number>` to push the branch, create the PR, and drive it
to green CI and mergeable state. Keep a compact review summary (verdict,
findings count, iterations, `$detect-evil` verdict) as a durable artifact; the
verbose per-iteration findings file is droppable. Immediately after `$deliver`
creates the PR, post a `WORK:REVIEW` comment on it from that summary --
`$deliver` does not post it.

## 9. Hand Off, or Merge if Authorized

Run `$return-to-town`. Its default is hand-off: it records the hand-off, tells
the user the PR is ready to merge, and stops there -- short of its "After a
merge" list. A `$campaign`-dispatched run always takes that path, so hand-off
is a terminal stop, not a step to clean up after. On that path, leave the
branch and the worktree in place for whoever merges; the reclaim is theirs.

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
     reject, a design question only the operator can settle.

Do not count on `$resurrection` to catch an unlabeled park: its reset
requires no PR *and* no matching branch, and a parked run almost always left a
branch, so the sweep re-labels the issue to match its PR -- *in flight*, not
parked. The label is the only thing that says *parked*.

If a `$campaign` dispatched you, you still own this write -- the orchestrator
does not duplicate it. Report the blocker in your completion report too, so the
orchestrator records its manifest row and keeps draining the queue.
