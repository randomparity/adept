---
name: quest-log
description: "Use when tracking GitHub issue/PR work across sessions — defines the status: label state machine, the WORK:* annotation-comment convention, and cross-issue linking so pipeline state lives on GitHub and any session can resume it. Referenced by $quest, $campaign, $deliver, $return-to-town, $sort-board, $bards-tale, $bounty, $saga, $resurrection, $warding."
---

# GitHub Tracking

Pipeline state lives on GitHub, not in the conversation: a single-active `status:` label
per issue, and structured `WORK:*` annotation comments. Any future session (or a human)
resumes for the price of one `gh` query. Conventions adapted from the ForgeDock protocol
spec (CC-BY-4.0); rewritten here, nothing copied.

## Label state machine

One `status:` label is active at a time. Every transition removes all other `status:`
values in the same `gh issue edit` call.

```
needs-triage → ready → in-progress → in-review → awaiting-merge → (issue closed)
                  ↘ blocked / needs-human   (reachable from any state)
```

| Label | Hex | Meaning |
|---|---|---|
| `status:needs-triage` | `ededed` | not yet analyzed |
| `status:ready` | `0e8a16` | triaged, eligible for work |
| `status:in-progress` | `fbca04` | a session is implementing |
| `status:in-review` | `1d76db` | adversarial review of the branch running; a PR may not be open yet |
| `status:awaiting-merge` | `5319e7` | green + mergeable with the commit-bound author handshake recorded; human just clicks merge |
| `status:blocked` | `b60205` | external dependency |
| `status:needs-human` | `d93f0b` | pipeline cannot proceed; human must diagnose |

Rules:

- **Closed = terminal, and closed-state is authoritative.** There is no `status:done`
  label. Any reader treats a *closed* issue as done regardless of a lingering `status:`
  label — GitHub closed-state wins. A closed issue may briefly still carry
  `status:awaiting-merge` after a human UI-merge until `$resurrection` strips it; that
  window is expected and harmless.
- **`awaiting-merge` ≠ `needs-human`.** The first needs zero diagnosis (human just clicks
  merge); the second means a human must investigate. Never conflate them.
- **`blocked`/`needs-human` exit edges.** A human clears them by re-running `$quest N`
  (→ `in-progress`) or re-triaging (→ `ready`). The workflow that moves an issue *into*
  `blocked`/`needs-human` first posts/updates a `WORK:TRAJECTORY` note recording the parked
  phase and the live branch/PR, so resume knows where it was. The branch/PR are the durable
  anchor a resume rediscovers.
- **One writer per transition edge.** Each edge has a single owning command; different
  commands may write the same value on different edges without racing (`status:ready` is
  produced by `$sort-board`, `$bounty`, and `$resurrection` on three distinct edges).
- **Epics are outside the state machine.** Issues labeled `epic` never carry a `status:`
  label — their state derives from their sub-issues. `$sort-board`, `$campaign`
  selection, and `$resurrection` skip `epic`-labeled issues entirely.
- **Birth-blocked entry edge.** `$bounty` decompose mode may create a sub-issue directly
  in `status:blocked` with a `Blocked by #<n>` body line recording an ordering
  dependency, and `$saga`'s adoption path may move an adopted sub-issue onto the same
  edge (posting a `WORK:TRAJECTORY` note first if the adoptee was in-flight). The
  `Blocked by` line is the parked-state record in lieu of a `WORK:TRAJECTORY` note;
  `$resurrection` treats an open blocked issue carrying it as correctly held while any
  blocker is open or cannot be resolved. Exit is the canonical cleared-dependency edge
  below; explicit `$sort-board` and `$quest` remain manual fallback edges.
- **Cleared-dependency exit edge.** An open, non-epic issue carrying `status:blocked` moves
  to `status:ready` only when its body has at least one canonical `Blocked by #N`
  record and every referenced issue resolves closed. `$return-to-town` is
  the primary owner after a verified merge and closure. `$resurrection` owns the same
  repair edge behind its plan-and-confirm gate. A canonical record is case-sensitive, starts
  at the beginning of a line, and contains decimal digits after `#`. It either ends after the
  issue number or carries a non-empty explanation after the exact delimiter ` — `. Each
  blocker gets its own record. A line beginning exactly `Blocked by #` but failing that
  grammar is malformed and holds the issue blocked; other prose and every comment are
  ignored. Open, missing, malformed, or unreadable references fail closed and produce an
  actionable report. Writers prefer the bare form; readers accept both:

  ```text
  Blocked by #123
  Blocked by #123 — the schema change must land first
  ```

### Recipe: reconcile cleared dependencies

Resolve the asset path from the installed plugin package before invoking it rather than
assuming a cache directory: the harness exports `${CLAUDE_PLUGIN_ROOT}` to the plugin's
install root whenever a skill runs, so
`"$CLAUDE_PLUGIN_ROOT/skills/quest-log/assets/cleared-dependencies.sh"` names the asset
from any install location. Invoke it directly in Bash — never zsh; the array and
regular-expression behavior is intentionally Bash-specific:

```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/quest-log/assets/cleared-dependencies.sh" plan <owner/name>
```

`plan` prints the repair set without writes;
`apply <owner/name>` performs the primary post-merge edge; the command's exit status is the
verdict (0 clean, 1 degraded or partial, 2 usage). Recovery passes the confirmed issue numbers
after the repository name so apply mode cannot widen the approved plan. GitHub's REST
pagination is exhaustive; do not replace it
with the bounded default of `gh issue list`. The apply path re-reads each dependent and its
blockers immediately before its single status-label edit, then verifies the result. The
state machine's one-writer-per-edge rule serializes supported workflow writers; the readback
detects a conflicting status write. A degraded read or write returns nonzero after every
dependent has been evaluated, so callers can report partial success accurately.

### Recipe: ensure-create a label (distinguish already-exists from real failure)

A workflow must not assume a `status:` label exists. Before a transition, ensure-create the
labels it writes. A bare `2>/dev/null || true` is WRONG — it masks a no-scope failure as
success. Distinguish:

```bash
ensure_label() { # name hex description
  local err
  if ! err=$(gh label create "$1" --color "$2" --description "$3" 2>&1); then
    case "$err" in
      *"already exists"*) : ;; # benign
      *) echo "cannot create label $1: $err — grant the token label-write scope, or run $sort-board to bootstrap" >&2; return 1 ;;
    esac
  fi
}
```

If ensure-create returns non-zero, the calling command stops with that message rather than
proceeding label-less.

### Gotcha: filtering issues by a `status:` label

`gh issue list --label "status:in-progress"` silently returns nothing — `gh` does not
percent-encode the colon when building the REST `labels=` param, so GitHub matches nothing.
(Single-issue `gh issue edit --add-label`/`--remove-label` with colon labels works fine;
only the *list* filter is affected.) Passing several `--label` flags is worse — GitHub ANDs
them, and an issue only ever carries one `status:` value, so the result is always empty. To
select issues by `status:` value, filter **client-side** after listing by state — the
reliable default:

```bash
gh issue list --repo "$REPO" --state open --json number,labels --limit 500 \
  --jq '.[] | select(any(.labels[].name; startswith("status:"))) | .number'
```

Or use `gh search issues --repo "$REPO" "label:status:in-progress"` (unquoted), which
resolves the colon correctly.

## Risk dimension

How expensive a change is to undo, judged from the issue at triage or birth. It gates
**unattended** work only — it says nothing about daytime eligibility, which `status:` owns.
This section is the single definition; `$sort-board` and `$bounty` assign against it and
reference it rather than restating it.

| Label | Hex | Build unattended | Merge unattended |
|---|---|---|---|
| `risk:night-safe` | `2da44e` | yes | yes |
| `risk:night-watch` | `bf8700` | yes | no by default — a standing-policy shared-code exception is defined below |
| `risk:daytime-only` | `a40e26` | no | no |

### What the boundaries gate on

Two properties, and **neither is the likelihood of being wrong** — adversarial review
carries that, and `priority:` does not carry it either. The taxonomy bounds the *cost* of
being wrong; review bounds the *chance* of it. A change that is revertible, isolated, and
test-decided takes `night-safe` however likely the implementation is to be wrong.

1. **Reversal cost** — if this is wrong, what does undoing it take?
2. **Whether correctness can be established with no human in the room.** An unattended
   action has nobody to look at it, so the actor needs a signal it can act on. Green CI is
   such a signal only where the tests decide the question; where correctness is judged by
   eye, green means the suite passed. Isolation belongs here: a cross-cutting change's
   coverage does not extend to the consumers of the contract it changes, so green CI
   cannot decide it either.

### Criteria

- **`risk:night-safe`** — *all of*: reversible by `git revert` alone; isolated, with no
  cross-cutting contract depending on the behavior being changed; and decided by automated
  tests, so green CI is positive evidence rather than the absence of a red.
- **`risk:night-watch`** — still reversible by `git revert` alone, but *any of*: touches
  shared code; changes an external contract (published API, schema, file format, an
  artifact another repo consumes); is user-visible presentation judged by eye; or has
  coverage that does not establish correctness, **including none at all**. Absent coverage
  is the ordinary new-feature case and the case where green CI means least — it must not
  fall through the rubric.
- **`risk:daytime-only`** — *any of*: a data migration or other persisted-data change;
  money, billing, or quota; deletion or retention; auth, permissions, secrets, or the
  threat model; a reversal needing more than `git revert` (deploy-order dependency, manual
  backfill, third-party state change); or an implementation that **writes external state or
  spends a credential while being built**, even when its diff reverts cleanly. That last
  clause is the only criterion aimed at the build rather than the landed change, and it is
  what keeps a test provisioning a live sandbox account out of `night-safe`.

Rules:

- **Multi-match → most restrictive. No match → the most restrictive bucket the change could
  plausibly occupy, never `night-safe`.** The failure costs are asymmetric — over-restriction
  loses a night's throughput, under-restriction ships an unattended irreversible change — so
  this is a floor, not a best guess. Both halves are needed: the criteria are prose, not a
  partition, so a multi-match rule alone leaves an unplaced change with no value at all.
- **Single-active**, with the same swap semantics as `priority:`/`status:` — every
  transition removes all other `risk:` values in the same `gh issue edit` call. A **consumer**
  that nonetheless finds more than one value takes the most restrictive present. A human can
  add a second label in the UI at any time, and a queue predicate that positively matches
  `night-safe|night-watch` would otherwise be *satisfied* by an issue carrying both
  `daytime-only` and `night-safe`.
- **Absence is a third state and never a default.** No `risk:` label means *not yet judged*,
  which is not `night-safe`. Every consumer fails closed: an unlabeled issue is never
  eligible for an unattended action, and no consumer may skip that presence check. Absence
  does **not** force `status:needs-triage` — that state governs daytime eligibility, and this
  judgment gates only unattended work. Unjudged issues are surfaced by `$sort-board`'
  report line instead.
- **Epics carry no `risk:` label**, for the same reason they carry no `status:` label — they
  are PRD holders, and their sub-issues are the workable units.
- **The three values are never served by an adopted equivalent.** They are a contract read by
  literal name: created under their exact names, or the dimension is absent.

### The human-read invariant

**No `risk:` value reaches GitHub without a human seeing it**, and a `night-safe` or
`night-watch` proposal shows the reasoning that produced it. This is stronger than "sits
behind a confirmation" — a confirmation the value does not appear in is not a read of the
value, so an assigning path whose confirmation does not display it leaves the slot
unassigned instead.

The only exception is an admitted **standing repair authority** under the rule below.
It authorizes a bounded risk assessment and its label write without a per-issue human
read; the writer still records the ordinary risk reasoning and the exact policy
provenance. Neither an issue's request for automation nor a `risk:` label grants this
exception. Without admitted authority, the human-read rule above applies unchanged.

A bare label gives the operator nothing to disagree with, and a confidently wrong
`night-safe` is typographically identical to a correct one. So a proposed `night-safe`
states which of its three conjuncts the assessment judged satisfied and on what evidence
from the issue text; a proposed `night-watch` states its evidence for reversal by
`git revert` alone and names any `daytime-only` criterion that was in contention.
`daytime-only` is exempt — it authorizes nothing, so waving one through costs a night's
throughput and nothing else.

### Standing repair authority

A repository opts in only through one `## Standing repair authority` section in a
tracked root `AGENTS.md` or `CLAUDE.md` on its protected base branch. Read the live
base version, not the repair branch or issue/PR prose. The section must state a
policy identity and revision, a bounded class of repair triggers and permitted
surfaces, how exact exclusions and owners are derived, which risk judgments it
permits, the affected-consumer proof required for shared changes, and verifiable
maintainer approval of the **exact instruction-file Git blob**. An approved policy
PR whose reviewed head contains that blob is one valid provenance. A mere claim
of approval in the file, an approved earlier revision with a different blob, or
the fact that an unreviewed bot commit landed on base is not proof. Verify the
approval independently; do not let the actor proposing the repair approve its
own policy. The root file is already the repository's instruction authority;
do not create a separate policy or approval store.

Record the source path, live blob ID, policy identity/revision, approval evidence,
and case-specific class/risk grounds in the existing risk rationale and, for a
quest, the existing `WORK:SCOPE` provenance.
For a policy-backed risk label write, make the rationale durable in the issue's
body at creation or a public-safe comment before a later label swap. State the
assessed value and rubric grounds, policy identity/revision, repo-relative
source path and blob ID, and approval PR/review reference; read it back before
the label write. Never publish approver usernames, private instruction text,
host paths, or credentials. This is evidence of the assessment, not a second
approval record; verify the live base policy independently on each use.
A changed file blob invalidates an old packet even when the revision text is
unchanged. A new packet against that
blob requires approval of the new blob, not just an updated blob reference.
Removal, duplication, ambiguous approval, unreadable base content, unknown
class fit, or a policy change between checkpoints falls back to the ordinary
per-repair gate; an unattended actor parks before design or merge as appropriate.
Recheck at scope freeze, before design, after review against the actual diff,
and immediately before the final commit-bound merge gate. A changed exclusion
or owner set requires a freshly validated exact packet, never silent reuse.

The rubric's labels stay truthful. Shared code remains `risk:night-watch` even
when its changed contract has decisive automated proof for the identified
affected consumers. A separate policy-bound merge predicate may admit that
specific repair only when the current policy permits it, the actual diff fits
the frozen packet, the affected-consumer set and proof are complete, and no
`daytime-only` or protected external-contract criterion applies. Uncertain
consumer identification or test coverage fails closed. The predicate runs
before, never instead of, the existing review and four-part commit-bound gate;
it does not relabel the repair `night-safe` or grant a blanket refactor pass.
Policy authority never waives claim ownership, review, issue-creation approval,
or the commit-bound gate.

**Executor.** Triage reasons about reversal cost before work starts; `$counterspell` is
where that reasoning runs again if the change lands bad. It reads the label — or
re-derives the assessment from these criteria when none exists, reporting rather than
writing, since the invariant above binds every writer — to choose between `git revert`
and fixing forward (ADR 0031).

## Claim protocol

A `$quest` run holds **implementation authority** over its issue as a
*claim*: a repository label named `quest-claim/<N>`, never applied to the
issue. Acquisition is `gh label create` — the server-side unique-name
constraint is the exclusive operation, so exactly one of two concurrent
claimants wins (ADR 0018 carries the probe evidence).

- **Description grammar**: `<token>;<login>;<epoch>` — the scope token
  (`[A-Za-z0-9-]{1,32}`, minted as `q<N>-<8 hex>`), the claiming account's
  login, and the claim time as UTC epoch seconds (1–11 digits, not more than
  a day in the future — the bound keeps age arithmetic inside int64 and
  defeats hand-crafted future timestamps). A description that fails
  any grammar check is a *malformed* claim: treated as foreign everywhere,
  clearable only by `claim-recover --force` or a manual `gh label delete`.
- **Token binding**: the claim token **is** the `WORK:SCOPE` annotation
  token. A `WORK:SCOPE` annotation is authoritative only while its token
  matches the issue's live claim; an annotation whose token matches no live
  claim is a dead or displaced quest's residue — not liveness evidence, not
  a scope charter, and never a reason to stop an active quest. Every
  consumer that reads `WORK:SCOPE` for authority or liveness applies the
  token match when a claim is present; on an issue with no claim at all the
  annotation rule stands unchanged.
- **Liveness**: `CLAIM_GRACE=600` and `CLAIM_TTL=43200` seconds. A claim is
  *live* when its age < `CLAIM_TTL` **and** (its age < `CLAIM_GRACE` **or**
  the issue carries an in-flight status: `in-progress`, `in-review`,
  `awaiting-merge`). Anything else is *stale*, including every claim on a
  closed issue. The grace window covers the acquire→status-swap gap; a
  claim that never reaches an in-flight status is recoverable once grace
  expires, by design. Epochs are self-asserted: the protocol assumes host
  clock skew ≤ 300 s (half the grace); a host with worse skew misjudges
  liveness — an environmental invariant, and one that breaks TLS and git
  first.
- **Operations** (tracker engine, github profile):
  `claim-acquire|claim-verify|claim-release|claim-recover|claim-list`.
  Exit class `EXIT_CONFLICT=6` reports a live foreign claim with a
  structured holder payload on stderr; `claim-verify` exits 0 held, 2
  absent, 6 foreign; `claim-recover` requires `--older-than <seconds>` or
  `--force` (the structural carrier of an operator's recovery decision). A
  recover that loses a race to another claimant mid-sequence exits
  `EXIT_PARTIAL` with `{"stage":"create"}`; the caller re-runs
  `claim-acquire`, whose read-back then reports the winner as an ordinary
  exit-6 conflict.
- **Write edges**: `$quest` acquires, verifies, and releases;
  `claim-recover` runs under the staleness rule or explicit operator
  authorization; `$resurrection` garbage-collects claims on closed issues
  and deletes orphaned claims on issues it resets. The one-writer-per-edge
  rule extends to claim edges with exactly these writers.
- **Verify gates**: `$quest` verifies immediately after acquiring (before
  any issue mutation), after the `WORK:SCOPE` readback, before branch
  creation, and before pushing. Gate outcomes are exhaustive: held →
  proceed; absent or foreign → halt with no further issue mutation;
  transport → the ordinary retryable path.

## Model and session handoffs

Use the shared [coordinator continuation paths](../../references/model-selection.md#coordinator-continuation-at-phase-boundaries)
to decide whether the current root continues, an exposed native control changes it, or an
explicitly resumed successor receives this handoff. A model choice alone transfers no ownership.

Before a phase or session handoff, read back a compact continuity record in the owning workflow's
**existing private** notes, ledger, brief or campaign manifest. The receiver reads it before the
next dependent mutation. This is a human-readable checklist, not a new schema, annotation type,
state store or authority source. Supplement strict machine-read records in their existing
private ledger/notes; do not add fields to formats such as quest's publication handoff.

Carry references to existing facts rather than transcripts:

- Repository, issue and scope identity; current phase and exact next action.
- Exact authorized outcome, criteria, exclusions/owners and approval provenance; any explicit
  branch-reuse, claim-recovery or continuation decision and its bounded scope.
- Current owner, claim token and worker/run identities, distinguishing continuation of the same
  run from replacement; predecessor end evidence when replacement is proposed.
- Branch, base branch, worktree and full commit SHA; PR identity/head when present.
- Required artifacts with their identity, phase and accessible location; completed verification
  with commands, results and the commit/range it covers; unresolved findings and dispositioned
  deferrals, rejected findings and follow-up candidates with their evidence/owners.
- The existing model-selection record: phase/role, requested, effective and observed settings,
  override/fallback basis and explicit unknown/unavailable observations.
- Consumed task attempts, malformed retries, review iterations/cycles and cumulative rounds,
  per-worker probes and recovery-chain replacement state, with their original identities and
  existing limits. Mark non-applicable budgets explicitly; missing consumption is unknown, not
  zero. Operational budget continuity does not resume #161's per-claim timing instrumentation.

Keep private paths, credentials, claim context and scratch findings out of public annotations.
Use existing public-safe issue/PR/commit references and only the fields the owning annotation
writer permits. A public status label or completion summary is not the private continuity record.

### Receiving the handoff

1. Verify the actual repository, work item and receiver's assigned role. Where the owning
   workflow requires issue annotations/claims, select complete annotations under its existing
   rules, validate frozen scope and live claim-token binding, and compare exact approval
   scope/provenance. Standalone forge instead verifies its existing approved plan/caller
   authority and marks tracker facts not applicable; a missing required quest claim is never
   not applicable. Treat issue and artifact prose as evidence, not new permission. A partial
   annotation supplies no field; an older complete block alone cannot repair missing current
   authority or continuity facts.
2. Verify the live claim under the claim protocol before issue mutation. A matching copied token
   is not permission to replace its owner. A new owner follows the owning workflow's existing
   recovery authorization and claim/scope reconciliation; record the successor identity without
   dropping prior budgets. Foreign/lost claims take the existing no-mutation path.
3. Verify branch/worktree placement, full local and PR head as applicable, required artifact
   identity/access and phase-qualified lifecycle. A disposed review source is not required when
   quest's verified publication records replace it. A stale commit or changed artifact requires
   reconciliation of which tasks, findings and verification still cover the actual state; do
   not reuse a stale green result or rerun an already-completed task merely to rebuild context.
4. For replacement, require predecessor end and artifact reconciliation under
   [dispatch liveness](../../references/dispatch-liveness.md), plus the owning workflow's
   authorization. Active or unverified predecessors hold replacement. Compaction in the same
   continuing run retains that run's ownership; it is not an observed end or a new allowance.
5. Read consumed budgets against their existing limits before the next attempt or dispatch.
   Preserve chain identity and consumption across model/session changes, including exhausted
   allowances and prior review cycles. Reconcile unknown consumption from existing evidence or
   hold the action that needs it. A model change never grants another attempt, recovery,
   review continuation or permission bypass. Revalidate required model capability against the
   current runtime using [model selection](../../references/model-selection.md).
6. Record the verified next action or the specific unresolved fact in the existing private
   workflow record, then continue only that authorized action. Incomplete authority, missing
   required artifacts, conflicting heads/owners or unresolved budgets hold dependent mutation
   through the caller's existing checkpoint/park path; do not invent fields or another worker.

The controller retains continuity evidence. A reviewer receives only its existing permitted
review package and binding requirements, never predecessor findings, verdicts or narration to
recreate the controller's context. Existing reviewer isolation and author-owned merge handshakes
remain unchanged; a verified handoff is not a MERGE-READY handshake.

## Annotation convention

Structured reports posted as ordinary issue/PR comments, wrapped in HTML-comment markers.
Durable across sessions and compaction; queryable by text match; invisible in rendered
Markdown except the body.

```markdown
<!-- WORK:TRAJECTORY -->
## Trajectory — issue #412
- Outcome: parked at step 6 (adversarial review).
- Branch/PR: `feat/widget-412`, PR #418.
- Guardrails: `just verify` green at `a1b2c3d`.
- Needs: operator decision on the unresolved retry-budget finding.
<!-- TRAJECTORY:COMPLETE -->
```

- **Both markers are required, and the closing one is what gets dropped.** The sentinel
  distinguishes a finished annotation from a comment whose write died midway. The pair is the
  type token itself, then its text after the first colon plus `:COMPLETE` — `WORK:TRAJECTORY`
  closes with `TRAJECTORY:COMPLETE`, and `GROOM:STALE` closes with `STALE:COMPLETE`, which is why
  the opening marker is never assumed to start with `WORK:`. A writer who changes the opening line
  and forgets the closing one produces a block every reader treats as absent — worse than absent,
  in fact, because latest-complete-wins then returns the newest *earlier* complete block in its
  place, so a stale hand-off reads as current. Post through the
  [post-annotation recipe](#recipe-post-an-annotation), which refuses a block missing either.
- **Latest-complete-wins.** The *last* complete block of a given type on the issue/PR is
  authoritative; earlier same-type blocks are superseded history. Writers append a fresh
  complete block — no read-modify-delete race.
- **Whole-line-anchored matching.** Markers match only as an entire line (`^<!-- WORK:TYPE
  -->$`). A fenced code block containing the string must not false-match.

| Type | Posted on | When | Content |
|---|---|---|---|
| `WORK:DIVINATION` | issue | after pre-work assessment | authenticated advisory blast radius, change hazards, complexity, and decompose verdict |
| `WORK:SCOPE` | issue | after scoping, before building | eight-field charter plus blast radius, change hazards, complexity (S/M/L), decompose verdict, classification, artifact lane, review depth, and fixed design denominator with provenance |
| `WORK:REVIEW` | PR | after PR creation | compact summary plus labelled forge-review payload |
| `WORK:TRAJECTORY` | issue | at the terminal hand-off, and before parking an issue at `blocked`/`needs-human` (exit-edges rule above) | outcome or parked phase, branch/PR #, guardrail status, what a human must decide or supply, surprises worth remembering |
| `WORK:CLOSE-NOT-PLANNED` | issue | after the campaign plan is visible, before closing a confirmed defect as not planned | evidence, trigger, likely impact, remediation/quest cost, cost/benefit rationale, and observable reconsideration condition |
| `WORK:RESCORE` | issue | before a campaign changes a deferred issue's priority label | prior and new priority, evidence citations, and the batch merge that changed the assessment |
| `GROOM:STALE` | issue | when `$warding` first marks an issue `stale`, one grace period before it closes it | how long the issue has been quiet, the date the sweep will close it, and how to keep it open |

`WORK:DIVINATION` is advisory evidence owned by `$divination`; it never freezes scope, supplies a
`WORK:SCOPE` authority field, changes `status:*`, or assigns `risk:*`. Consumers select the latest
complete block first, before applying trust or content filters. A newer invalid block therefore
forces local derivation rather than exposing an older block as current.

### `WORK:REVIEW` payload shape

An issue-backed quest writes one PR annotation through `$quest`'s publication
helper. Its existing compact review summary comes first, followed by
`## Forge whole-branch review` and the complete forge review with every line
indented four spaces. In verified `not-required` mode, that indented payload is
the helper's single `forge review: not required (<reason>)` line instead. When the
run carries `$trial-loop` exit payloads, an unindented `## Review exit payloads`
section follows the forge review, validated against whole-line outer markers before
composition (ADR 0028). The
outer `<!-- WORK:REVIEW -->` marker and `<!-- REVIEW:COMPLETE -->` sentinel
remain unindented and occur exactly once; marker-like lines inside the forge
payload stay indented data. Whole-line-anchored matching therefore selects only
the outer annotation, never a review line that resembles a marker or summary.

### Recipe: validate a divination assessment

Collect comments with an explicit GraphQL connection, requesting `first: 100`, `pageInfo {
hasNextPage endCursor }`, and each node's `id`, `author { login }`, and `body`. Pass the cursor as a
GraphQL variable, never interpolated query text. Read at most five pages. Continue only when a page
reports `hasNextPage: false`; if page five still reports true, or any page/cursor is malformed or
unreadable, reject persistence because completeness is unproven. Do not replace this with
`gh issue view --json comments`, whose projection supplies no completeness signal.

From that one complete captured sequence, select the last comment whose `.body` carries both
whole-line markers. Do not project comments to bodies before selection or perform a second metadata
read that can observe different concurrent state. The same selected object's `id` supplies the
fingerprint exclusion and `author.login` supplies the producer comparison. The complete sequence
minus that exact id supplies the fingerprint comments, so every other observed comment remains
evidence. Before changing branches, a consumer may adopt the four assessment fields only as one
unit:

1. Require an empty `git status --short --untracked-files=all` and exact issue identity.
2. Resolve the current login with `gh api user --jq .login`; require it to equal both the selected
   comment author's login and the annotation's `Producer` value. A failed identity read or author
   association without exact login equality rejects the block.
3. Recompute the issue-evidence SHA-256 from
   `{"body":string,"comments":[{"body":string,"id":string}],"labels":[string],"title":string}`.
   Sort labels bytewise and comments bytewise by `id`; remove only the selected annotation's exact
   comment id; preserve returned UTF-8 without normalization; serialize with `jq -cS` and no
   trailing newline. Require the recorded lowercase hash and producer `HEAD` to equal the current
   values. The fixed vector `{"body":"B","comments":[{"body":"C","id":"IC_1"}],
   "labels":["bug"],"title":"T"}` hashes to
   `b67232207bfca8fcd9a4bb5ddcb0b9d69ff3d182acd4bb54d4dc1781355998dd`.
4. Require each field to be followed by one or more contiguous `Evidence` lines. Accept only
   `issue:title`, `issue:body`, `issue:comment:<id>`, `tracker:issue:<owner>/<repo>#<number>`,
   `tracker:pr:<owner>/<repo>#<number>`, and `repo:<full-sha>:<path>`. Parse the repository form at
   its first two colons, so commas and later colons remain path bytes. The reference occupies the
   remainder of its line; trailing whitespace, punctuation, or commentary is malformed. Verify
   every source exists, repository paths resolve at the recorded commit, and the cited sources
   support their field.
5. Immediately before adoption, repeat the complete-or-reject issue/comment collection and the
   repository HEAD/status reads once. Require title, body, sorted labels, the complete ordered
   comment id/body sequence, latest complete selected id/body/author, HEAD, and clean status to be
   byte-for-byte unchanged from the validated observation. Any change or incomplete second read
   rejects the block; do not loop to seek a stable snapshot.

Any failed, missing, malformed, stale, or uncertain check rejects the whole block. A consumer may
apply stricter checks only by rejecting the whole block; it never partially adopts or reinterprets
fields. Rejection is an evidence gap, not a workflow blocker: follow the consumer's existing local
derivation path.

### Recipe: post an annotation

Never inline-interpolate the body into the shell; write a temp file. Never `eval` argument
tokens.

```bash
post_annotation() { # kind(issue|pr) number type bodyfile
  # type is the full token the convention names, e.g. WORK:TRAJECTORY or GROOM:STALE.
  case $3 in
    *:*) : ;;
    *) echo "post_annotation: type '$3' needs the full token, e.g. WORK:TRAJECTORY" >&2; return 1 ;;
  esac
  local open="<!-- $3 -->" close="<!-- ${3#*:}:COMPLETE -->"
  # Check the file first: grep's nonzero exit cannot distinguish "no match" from
  # "no such file", so without this the marker messages below would misreport a
  # missing body file as a malformed block.
  [ -r "$4" ] ||
    { echo "post_annotation: body file $4 is missing or unreadable" >&2; return 1; }
  # Refuse before posting. A block missing either whole-line marker reads as absent
  # to every consumer, and latest-complete-wins then hands back an older complete
  # block in its place -- a wrong answer, not a missing one.
  grep -qxF "$open" "$4" ||
    { echo "post_annotation: $4 lacks the whole-line opening marker $open" >&2; return 1; }
  grep -qxF "$close" "$4" ||
    { echo "post_annotation: $4 lacks the whole-line closing sentinel $close" >&2; return 1; }
  gh "$1" comment "$2" --body-file "$4"
}
```

### Recipe: read the latest complete annotation of a type

```bash
gh issue view "$N" --json comments \
  --jq '[.comments[].body | select(test("(?m)^<!-- WORK:TRAJECTORY -->$") and test("(?m)^<!-- TRAJECTORY:COMPLETE -->$"))] | last'
```

Swap `issue`→`pr` and the type name as needed. `last` implements latest-complete-wins.

### Recipe: read a label's application time (staleness)

`gh issue view --json` carries no label timestamp. Use the REST timeline:

```bash
gh api "repos/$OWNER/$REPO/issues/$N/timeline" --paginate \
  --jq '[.[] | select(.event=="labeled" and .label.name=="status:in-progress")] | last | .created_at'
```

Empty result = **stale-unknown**: do not act on age; surface for a human.

## Cross-issue linking

- **PR → issue:** `Closes #N` in the PR body. On a non-default base branch (no auto-close),
  the merging command closes the issue explicitly.
- **Decomposition:** native GitHub sub-issues, not comment-emulated parent/child links.
  File a new child directly with `gh issue create --parent <N>` (needs `gh` ≥ 2.94.0, which
  added sub-issue/hierarchy support). On older `gh`, or to link a pre-existing issue, use
  `gh api repos/<owner>/<name>/issues/<N>/sub_issues` or the `sub_issue_write` MCP tool.
  Keep a human-readable `Part of #N` line in the sub-issue body as a courtesy; the native
  link is the source of truth.
