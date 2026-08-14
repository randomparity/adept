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
| `status:awaiting-merge` | `5319e7` | green + mergeable; human just clicks merge |
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
  to `status:ready` only when its body has at least one canonical whole-line
  `Blocked by #N` record and every referenced issue resolves closed. `$return-to-town` is
  the primary owner after a verified merge and closure. `$resurrection` owns the same
  repair edge behind its plan-and-confirm gate. A canonical line is case-sensitive, has no
  leading or trailing content, and contains decimal digits after `#`. A line beginning
  exactly `Blocked by #` but failing that grammar is malformed and holds the issue blocked;
  other prose and every comment are ignored. Open, missing, malformed, or unreadable
  references fail closed and produce an actionable report.

### Recipe: reconcile cleared dependencies

Source `assets/cleared-dependencies.sh` (deployed with this skill) in Bash, never in zsh;
the array and regular-expression behavior is intentionally Bash-specific. Then call
`reconcile_cleared_dependencies plan <owner/name>` to print the repair set without writes,
or `reconcile_cleared_dependencies apply <owner/name>` to perform the primary post-merge
edge. Recovery passes the confirmed issue numbers after the repository name so apply mode
cannot widen the approved plan. GitHub's REST pagination is exhaustive; do not replace it
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
| `risk:night-watch` | `bf8700` | yes | no — stops at `status:awaiting-merge` |
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

A bare label gives the operator nothing to disagree with, and a confidently wrong
`night-safe` is typographically identical to a correct one. So a proposed `night-safe`
states which of its three conjuncts the assessment judged satisfied and on what evidence
from the issue text; a proposed `night-watch` states its evidence for reversal by
`git revert` alone and names any `daytime-only` criterion that was in contention.
`daytime-only` is exempt — it authorizes nothing, so waving one through costs a night's
throughput and nothing else.

## Annotation convention

Structured reports posted as ordinary issue/PR comments, wrapped in HTML-comment markers.
Durable across sessions and compaction; queryable by text match; invisible in rendered
Markdown except the body.

```markdown
<!-- WORK:TYPE -->
## <Type> — issue #N
<structured body, short labelled bullets>
<!-- TYPE:COMPLETE -->
```

- The `TYPE:COMPLETE` sentinel distinguishes a finished annotation from a comment whose
  write died midway. A block without its sentinel is treated as absent.
- **Latest-complete-wins.** The *last* complete block of a given type on the issue/PR is
  authoritative; earlier same-type blocks are superseded history. Writers append a fresh
  complete block — no read-modify-delete race.
- **Whole-line-anchored matching.** Markers match only as an entire line (`^<!-- WORK:TYPE
  -->$`). A fenced code block containing the string must not false-match.

| Type | Posted on | When | Content |
|---|---|---|---|
| `WORK:DIVINATION` | issue | after pre-work assessment | authenticated advisory blast radius, change hazards, complexity, and decompose verdict |
| `WORK:SCOPE` | issue | after scoping, before building | blast radius, change hazards, complexity (S/M/L), decompose verdict |
| `WORK:REVIEW` | PR | right after the PR is created | verdict, findings count, iterations, security-review status |
| `WORK:TRAJECTORY` | issue | at the terminal hand-off, and before parking an issue at `blocked`/`needs-human` (exit-edges rule above) | outcome or parked phase, branch/PR #, guardrail status, what a human must decide or supply, surprises worth remembering |
| `GROOM:STALE` | issue | when `$warding` first marks an issue `stale`, one grace period before it closes it | how long the issue has been quiet, the date the sweep will close it, and how to keep it open |

`WORK:DIVINATION` is advisory evidence owned by `$divination`; it never freezes scope, supplies a
`WORK:SCOPE` authority field, changes `status:*`, or assigns `risk:*`. Consumers select the latest
complete block first, before applying trust or content filters. A newer invalid block therefore
forces local derivation rather than exposing an older block as current.

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
   its first two colons, so commas and later colons remain path bytes. Verify every source exists,
   repository paths resolve at the recorded commit, and the cited sources support their field.
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
  # bodyfile already contains the full block incl. <!-- WORK:$3 --> ... <!-- $3:COMPLETE -->
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
