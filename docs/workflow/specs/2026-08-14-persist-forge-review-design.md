# Persist the forge whole-branch review design

Issue: #75

## Goal

Make `$forge`'s complete whole-branch review readable from the pull request after its worktree has
been reclaimed, while retaining `.agent/` as ignored scratch space and preserving the existing
`WORK:REVIEW` summary.

## Scope and authority

The frozen scope is issue #75 annotation token
`C70B87A9-14E3-438B-B4E2-815EAD0DCD15`. Issue #75 supplies the regression, evidence, and baseline
criteria; the operator selected PR attachment on 2026-08-14 and approved the design in the active
quest. There are no unresolved ambiguities.

Permitted surface is the `$forge` final-review lifecycle, `$quest` shipping and `WORK:REVIEW`
contract, their direct fixtures and gates, and these design records. Standalone `$deliver` and
`$return-to-town` behavior, reviewer findings semantics, alternate external storage, and new
automated consumers are excluded. Concurrent controllers for the same issue are not serialized by
this change; the existing status label is observability, not a lock.

This design is governed by [ADR 0016](../../adr/0016-publish-forge-review-with-work-review.md).

## Design

### Build-to-ship handoff

After the whole-branch fix wave closes, `$forge` no longer disposes the final-review file. It
appends a ledger record that the artifact is retained for PR publication and returns control with
the file still in the ignored workspace. Resume logic treats a closed review with neither a
publication-retained nor disposal record as the old interrupted cleanup state, and treats the new
retained record as build-complete evidence. The review remains available to every existing in-run
consumer before this transition.

`$quest` records the exact review path at the build-to-review seam and retains it through
trial-loop, simplification, local verification, and `$deliver`. A missing or empty retained file is
a named shipping failure; the quest does not post a placeholder claiming a review existed.

### Durable PR publication

Once `$deliver` creates the PR, `$quest` composes its existing complete `WORK:REVIEW` annotation.
The summary fields remain concise and first. A separate `Forge whole-branch review` section contains
a lossless rendering of a canonical text snapshot. Canonicalization accepts valid UTF-8 without NUL,
normalizes CRLF and bare CR line endings to LF, and produces exactly one final LF. Invalid UTF-8 or
NUL is a publication failure. The publisher prefixes every canonical line with four spaces,
including empty lines and lines that resemble annotation markers or summary fields. Removing that
prefix and restoring the specified final LF reconstructs the canonical snapshot. The indentation
makes the payload a Markdown code block and prevents whole-line marker or field readers from
treating model-written content as annotation structure. The annotation identifies this section as
the forge review, not the later trial-loop review summary, and contains no local artifact path.

Before copying, `$quest` mints one unique publication token and derives controller-owned temporary
and final snapshot paths in the same ignored workspace. It appends `review publication intent` with
the token and both paths to forge's progress ledger and verifies that append. Only then does it copy
and canonicalizes the consumed review to the temporary path, verifies a regular non-empty UTF-8
file with exactly one final LF, and atomically renames it to the final path. It rejects a
pre-existing unrecorded destination and never refreshes a completed snapshot from the source.

Resume reads the intent rather than minting new paths. A recorded final snapshot is adopted only
after its type, non-emptiness, digest, and public-safety scan pass. If a recorded temporary exists
without the final snapshot, it is an incomplete owned copy. Resume moves that exact path to trash
and restarts the copy. Any path/type mismatch stops with both artifacts retained. Once the final
snapshot passes, `$quest` computes its SHA-256, appends `review publication pending` with the token,
final path, and digest, and verifies that append. Comment composition reads only that recorded
snapshot and records the token in a named outer `publication token` field. The token, ownership,
snapshot, and digest therefore survive process loss, reconciliation, and the one permitted retry.
The post uses the quest-log body-file recipe.

Readback exhaustively enumerates PR issue comments through GitHub's paginated API; every page must
be readable and pagination must reach its declared end. A bounded projection without completeness
evidence cannot authorize either retry or disposal. From that complete observation, readback
selects the exact comment carrying the publication token and outer complete sentinels, rejects zero
or multiple matches, extracts only the indented payload after the forge-review heading, removes
exactly one four-space prefix per payload line, restores the canonical final LF, and compares the
result with the recorded byte length and pre-publication SHA-256. Embedded `WORK:REVIEW` markers,
completion
sentinels, publication fields, or summary-shaped
lines never count as outer structure. Only that exact readback authorizes disposal.

Before disposal, `$quest` appends `review publication verified` with the publication token, exact
GitHub comment identity, and the already-recorded snapshot digest to the forge ledger, then reads
that record back. This is the durable proof that content comparison succeeded while the snapshot
still existed; an in-memory success observation cannot authorize trash.

The publication contract assumes one active quest controller for the issue. GitHub comment creation
has no token-keyed create-if-absent operation, so two concurrent controllers can race after the same
absence observation. The required uniqueness readback detects but cannot prevent that race. When it
finds multiple comments carrying the token, the quest retains the artifact, reports the token and
public comment URLs for operator repair, and does not dispose or claim successful publication.

If `$forge` legitimately ran in a mode that does not require a whole-branch review, `WORK:REVIEW`
records `forge review: not required` with that verified mode. It never manufactures review content.
A named failure of a required forge review remains terminal: the quest cannot reach delivery or
`WORK:REVIEW` publication on that path. A publication rejected for comment size or service failure
stops shipping and retains the source file so a human can resolve the failure without rerunning the
review.

### Cleanup and resume

After the verified-publication ledger record exists, `$quest` moves the retained review and
publication snapshot to trash and appends `review artifacts disposed after PR publication` with
their former paths to the forge ledger. If either file is already absent on resume, its trash step
is treated as complete only when the ledger's
verified record carries the same token, comment identity, and source digest; the quest re-reads that
exact comment and validates its outer structure and recorded digest before closing the disposal
marker. Without that durable verified record, absence is a blocker rather than inferred success.

`$return-to-town` remains unchanged: by the time it reclaims the worktree, the PR is the durable
copy and the scratch lifecycle is closed.

## Failure cases and verification

- Missing, empty, or unreadable retained review: stop before posting and retain all remaining
  evidence.
- Failed required forge review: stop before delivery; do not downgrade it to an unavailable review
  annotation. Only a verified mode where no whole-branch review was required may publish `forge
  review: not required`.
- Public-safety match or scan fault: stop before posting; never publish the rejected content.
- Retained source changes after snapshot: never refresh or replace the snapshot; publication uses
  only the scanned, hashed snapshot. A snapshot digest mismatch stops without posting or disposal.
- Invalid UTF-8 or NUL in the source: canonicalization stops before publication. Fixtures cover
  empty interior lines, no final newline, one final newline, CRLF, bare CR, and invalid input.
- Crash during snapshot creation: resume uses the verified intent record, removes only its exact
  incomplete temporary copy through trash, and retries the atomic copy. A completed final snapshot
  is validated and adopted rather than overwritten.
- Comment creation failure: retain the review and report the failed publication.
- Ambiguous write result: exhaustively read back before retrying; retry once only when the exact
  publication token is absent, and reuse that token on the retry. A partial or unreadable comment
  collection stops without retry or disposal.
- Crash after GitHub accepts the comment but before the response is observed: resume obtains the
  token from the forge ledger, finds and validates the existing comment, and does not post again.
- Concurrent resume creates duplicate token comments: uniqueness readback stops shipping, retains
  the artifact, and names the duplicate public comments for operator repair; this change does not
  add a distributed lock or delete public comments.
- Comment readback mismatch: retain the review and stop; do not claim durability.
- Crash after comment readback but before the verified ledger append: the source still exists, so
  resume repeats content verification and persists the proof before disposal.
- Crash after the verified ledger append but before trash: resume verifies the recorded token,
  comment identity, and digest, then disposes and appends the disposal marker.
- Crash after trash but before disposal append: the durable verified-publication record plus the
  matching live comment closes the disposal marker without a second deletion.
- Existing `WORK:REVIEW` summary: fixtures prove its fields and complete sentinels remain present,
  with the forge review in a distinct indented section. A hostile fixture includes duplicate
  summary fields plus both annotation marker lines in the review and proves they remain payload.

Focused contract tests must first fail against current behavior, then prove the retained-artifact
handoff, publication/readback ordering, public-safety stop, absent-artifact disclosure, and
post-publication disposal paths. `just verify` remains the full local and CI guardrail.

## AI-SPEC and evaluation plan

The user is the quest operator. The trigger is completion of `$forge`'s whole-branch review during
an issue-backed quest. Inputs are the model-written review artifact, forge ledger, trial-loop
summary, and live PR state; output is a complete `WORK:REVIEW` PR annotation and closed scratch
lifecycle. Allowed sources are the frozen scope, repository files, verified worker artifact, and
GitHub readback. The workflow must not invent review content, publish a local path or denied public
data, discard the only copy before verified publication, or label the forge review as trial-loop
output. A missing or unsafe artifact fails closed. No new model call is added, so latency and model
cost do not change; success is a verified complete PR annotation followed by verified disposal.

| Failure mode | Severity | Evaluation |
|---|---:|---|
| Artifact discarded before durable publication | 4 | Contract fixture proves publication readback and a durable digest record precede disposal. |
| Unsafe, changed, malformed, or host-private text published | 5 | Fixture proves canonical UTF-8 framing is scanned, hashed, and posted, while mutation or invalid input stops. |
| Failed review treated as optional or fabricated on missing input | 4 | Fixture proves legitimate no-review mode is disclosed while failed required review cannot ship. |
| Forge review conflated with trial-loop summary | 4 | Fixture proves separate labelled sections and payload escaping inside `WORK:REVIEW`. |
| Duplicate write after ambiguous response or crash | 4 | Fixture proves ledger-backed token readback precedes the single bounded retry. |
| Oversized or rejected comment silently loses review | 4 | Fixture proves publication failure retains the source and stops shipping. |

Stable cases: `PFR-1` snapshots and publishes a safe non-empty review, verifies its digest, and then
disposes both artifacts; its framing cases cover empty lines, absent/present final LF, CRLF, bare
CR, and invalid UTF-8/NUL. `PFR-2` rejects a review containing a denied host path and proves source
or snapshot mutation after scanning cannot change the canonical bytes posted. It also crashes
before and during the atomic snapshot copy, then proves resume reclaims only the owned temporary path
and adopts a completed final snapshot. `PFR-3` proves both state arms:
a verified no-review mode may
publish `forge review: not required`, while a failed required review cannot reach delivery. `PFR-4`
starts with older complete annotations and reconciles an ambiguous write by finding its unique
token across multiple complete pages without duplication; it also proves an incomplete page set
stops without retry. `PFR-5` retains the artifact when GitHub rejects publication; `PFR-6` resumes
after comment acceptance but before response observation by recovering the ledger token, persists
verified comment identity and source digest before disposal, and resumes after trash but before the
disposal append without inferring success from absence alone. `PFR-7` publishes a
review containing duplicate summary fields and both outer sentinel lines, then reconstructs the
original content exactly without confusing those payload lines for structure. Each is a blocking
contract fixture whose observable traits are the required ordering and annotation fields. The
forbidden traits are early deletion, fabricated content, local paths, duplicate comments,
payload-shaped annotation structure, and a success claim without readback. Existing deterministic
shell fixtures are the judge; no model grades its own output.

## Threat model

The new boundary is model-written scratch content moving to a public GitHub PR. The untrusted actor
is the review worker, whose output may contain malformed Markdown or host-private text. Existing
boundaries widened are GitHub comment creation and the quest's scratch cleanup.

The quest trusts only a non-empty review at the controller-chosen forge path, then creates one
controller-owned snapshot whose digest is recorded before publication. It applies the repository
public-safety scan to that snapshot and GitHub receives a body derived only from those bytes through
`--body-file`, never shell interpolation. Every review line is indented before composition, so
model-written markers and Markdown stay inside the payload boundary. A ledger-persisted publication
token, exhaustive comment collection, outer-marker validation, and a lossless content comparison
control ambiguous writes and process loss. Disposal requires that verified readback.
Failures may disclose only a public-safe reason, not rejected content or local paths.

Credential compromise, malicious content already committed to the public repository, GitHub's own
Markdown renderer, and expansion of the public-safety pattern set are out of scope: this change
does not create or widen those mechanisms. The residual comment-size limit is accepted as a
fail-closed publication error with the original scratch artifact retained. Concurrent controllers
for one issue are also outside the supported operating model; duplicate-token detection bounds that
race to visible operator repair rather than pretending GitHub comment creation is atomic.
