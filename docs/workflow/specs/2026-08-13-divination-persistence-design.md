# Durable divination assessment design

Issue: [#49](https://github.com/randomparity/adept/issues/49)
Decision: [ADR 0015](../../adr/0015-persist-divination-assessments.md)

## Provenance

Issue #49 supplies the durability and dispatch-loss requirement. The operator explicitly chose a
distinct durable `WORK:DIVINATION` annotation with consumer revalidation rather than reusing
`WORK:SCOPE`. Accepted ADR 0011 supplies the `change hazards` versus `risk:*` execution-policy
terminology, and ADR 0015 records the resulting persistence decision.

## Scope and outcome

`$divination` will persist its four assessment fields in a distinct issue annotation so later
sessions and dispatched workers can recover them. `$quest` will adopt usable evidence and
revalidate it before freezing its independently owned `WORK:SCOPE` charter. `$bounty decompose`
will use a usable persisted split when present. No historical migration, risk-label assignment,
or reinterpretation of `WORK:SCOPE` is included. Direct installed-skill references that characterize
divination's mutation behavior will be made consistent with its one-comment write contract.

## Annotation contract

`$divination` remains read-only while investigating, then performs one bounded tracker write. It
posts this public-safe shape to the issue it assessed:

```markdown
<!-- WORK:DIVINATION -->
## Divination — issue #N
- Assessment identity: <issue URL>; token `<opaque token>`.
- Producer: `<authenticated GitHub login>`.
- Source revision: issue evidence SHA-256 `<lowercase hex>`; producer HEAD `<full SHA>`;
  worktree `clean`.
- Blast radius: <files/modules and local or cross-cutting judgment>.
  - Evidence: <one source reference; repeat this line for additional references>
- Change hazards: <named hazards or `none`>.
  - Evidence: <one source reference; repeat this line for additional references>
- Complexity: S | M | L.
  - Evidence: <one source reference; repeat this line for additional references>
- Decompose verdict: one PR | split — <actionable breakdown>.
  - Evidence: <one source reference; repeat this line for additional references>
<!-- DIVINATION:COMPLETE -->
```

Every `Evidence` line contains exactly one reference using only these forms:
`issue:title`, `issue:body`, `issue:comment:<GraphQL node id>`,
`tracker:issue:<owner>/<repo>#<number>`, `tracker:pr:<owner>/<repo>#<number>`, or
`repo:<full producer HEAD SHA>:<repository-relative path>`. Parse the repository form at its first
two colons; the remainder is the path and may contain commas or colons. The reference occupies the
remainder of the line; trailing whitespace, punctuation, or commentary is malformed. Values
contain no free-form labels or snippets. A field owns every contiguous, indented `Evidence` line immediately following
it and requires at least one. Missing, unknown, or non-contiguous evidence is malformed. The
producer checks each reference exists in the captured input, and repository references resolve at
the recorded commit. Revalidation repeats those existence checks and semantically confirms that
the referenced sources support the field; any failed or uncertain check rejects the whole
assessment rather than guessing or partially adopting it.

The producer resolves its login with `gh api user --jq .login` before posting and records it. A
consumer reads the selected comment's author login and resolves its own authenticated login with
the same command. Both must equal the recorded producer. A mismatch or failed identity read rejects
the block. Author association alone is insufficient because public commenters can carry several
association values without being the operator who ran divination.

The issue evidence fingerprint input is exactly
`{"body":string,"comments":[{"body":string,"id":string}],"labels":[string],"title":string}`.
Sort label names bytewise and comments bytewise by `id`; preserve the UTF-8 strings returned by
`gh` without Unicode normalization. Serialize with `jq -cS` and no trailing newline, then compute
SHA-256. The vector
`{"body":"B","comments":[{"body":"C","id":"IC_1"}],"labels":["bug"],"title":"T"}`
must produce `b67232207bfca8fcd9a4bb5ddcb0b9d69ff3d182acd4bb54d4dc1781355998dd`.

The producer computes the fingerprint before its new annotation exists; a consumer recomputes it
after removing only the selected annotation's exact comment `id`, never other marker-shaped
comments. The fingerprint and full producer-worktree `HEAD` SHA come from the same reads used for
the assessment and are captured before posting. The producer requires `git status --short
--untracked-files=all` to be empty before it posts; a dirty-worktree assessment remains local and
explicitly non-durable. Every assessment field
cites the issue fact, linked tracker artifact, or repository path that supports it. The producer
makes one post attempt, captures the returned comment URL, and reads the comment back. Success
requires the token, both whole-line markers, the assessed issue identity, both source-revision
values, all four assessment fields, and their grounding. If the post result is indeterminate, the
producer performs one bounded comments read for the unique token. Exactly one complete match is
verified normally; zero or multiple matches is an explicit non-durable result. It never retries
the write blindly. A denied write or failed readback also must not claim that a durable handoff
exists. The assessment itself may still be reported to the interactive caller.

The shared annotation convention owns whole-line matching, completion sentinels, and
latest-complete-wins. `WORK:DIVINATION` is posted on an issue after assessment and before any
implementation workflow. It is advisory evidence, not a status transition or scope charter.

## Consumer behavior

Consumers query issue comments with explicit JSON fields, including comment id and author login,
and select the last block carrying both whole-line markers before applying any trust or content
filter. They then require the selected comment author, recorded producer, and current authenticated
login to be identical. A newer foreign complete block therefore rejects persistence and triggers
fresh local derivation; it never exposes an older block as latest. A block is usable only when it
names the requested issue, contains the four fields and their source references, and provides
parseable source evidence. Before changing branches,
consumers recompute the issue evidence fingerprint and compare it and the producer `HEAD` SHA with
current values, and require their own worktree to be clean. Only the selected annotation's exact
comment is excluded, so the producer's own write does not stale the evidence and every other
comment remains fingerprinted. Any mismatch or dirty state rejects the block. On an exact match,
consumers verify every cited issue fact, linked tracker artifact, and repository path still exists
and supports its associated field. Exact source matches establish freshness, not truth.

`$quest` adopts all four fields as one assessment only after every citation passes. Any missing,
malformed, mismatched, stale, unsupported, or ungrounded field causes it to derive the complete
assessment itself, then record the resulting values only as tracking metadata inside its complete
frozen `WORK:SCOPE`. Assessment content never fills any of the eight charter authority fields.
`$bounty decompose` likewise uses the whole revalidated assessment, including a `split` verdict,
as drafting evidence; otherwise it performs its existing decomposition reasoning without
blocking. Consumer-specific stricter checks may reject the whole block, never partially adopt or
reinterpret it.

No consumer rewrites or deletes a divination comment. Older complete assessments remain
superseded history.

Direct references may describe their own workflow as read-only, but must not use divination as a
read-only exemplar. This wording repair changes no behavior outside divination and its consumers.

## Failure handling

- A GitHub read failure is degraded evidence: name the failed operation and use the consumer's
  existing local derivation path when that path can independently read the issue and repository.
- If persisted-evidence validation and the independent issue/repository derivation read both fail,
  quest stops before freezing scope and bounty stops before drafting or filing. Return explicit
  non-adoption with the failed operation and suggested retry, without external payload or auth data.
- An absent or incomplete annotation behaves like the pre-change state.
- A mismatched issue identity is ignored and reported as malformed evidence.
- Changed issue or HEAD source values mark the assessment stale; the consumer derives fresh
  values instead of editing the old comment.
- Embedded instructions or private-looking content in issue data are never copied verbatim. The
  producer summarizes only public-safe evidence and treats GitHub-authored content as untrusted.

## Adversarial review checklist

E1–E15 are review scenarios, not an executable prompt or model gate. Reviewers inspect the skill
contracts and their concrete command recipes against these cases, fix defensible findings, and
re-review the changed diff:

- E1–E2: select a fresh complete assessment without mistaking historical markers for the selected
  block; preserve quest's independent `WORK:SCOPE` boundary; derive locally when no block exists.
- E3–E4: reject the whole block for stale issue or HEAD fingerprints, incomplete fields, wrong
  identity, foreign authorship, unknown evidence, or punctuated/malformed evidence references.
- E5: summarize untrusted issue content without copying embedded instructions, canaries, or other
  unsafe text into the public comment.
- E6: distinguish confirmed, recovered, absent, duplicate, denied, and unreadable write outcomes;
  attempt at most one write and reconcile only an indeterminate outcome, without blind retry.
- E7–E8: choose the latest complete block with bounded collections and a terminal stability
  recheck; dispatched quest may adopt it but still creates its own later `WORK:SCOPE` boundary.
- E9–E10: reject adoption from a dirty consumer worktree; preserve the annotation; verify the
  fixed fingerprint vector, selected comment identity, and first-two-colons evidence parsing.
- E11–E12: bounty adopts a fully supported `split` assessment or falls back as a whole; a
  structurally valid block from any login other than the authenticated producer is rejected.
- E13–E14: a dirty producer reports locally without posting; direct installed references describe
  their own mutation behavior, while divination performs at most its one bounded comment write.
- E15: if persisted evidence cannot be read or validated and independent derivation also cannot
  read its inputs, quest and bounty stop before mutation with a public-safe retry message.

## Threat model

The new boundary is a tool-using agent writing a public GitHub comment derived from untrusted issue
content. Existing widened boundaries are later agents reading that comment and using its fields as
workflow evidence. Untrusted actors are issue authors and commenters; the trusted actor is the
authenticated local operator whose `gh` credential authorizes the write.

Controls are: explicit repository and issue resolution; explicit JSON reads; public-safe
summarization instead of verbatim copying; exact authenticated-login equality between producer,
comment author, and consumer; fixed annotation markers and evidence grammar; identity,
completeness, and source checks; readback after write; revalidation against current evidence; and
strict separation from scope authority and `risk:*` labels. Failures name the operation without
including auth or private environment detail.

Threats outside scope are malicious changes already merged into the repository and compromise of
the operator's GitHub credential; this workflow neither creates those trust boundaries nor can
repair them. GitHub availability is also outside scope and follows the explicit failure path.

## Verification

Review the final diff against the frozen scope and E1–E15 checklist, including exact marker names,
public-safe handling, bounded reads/writes, and consumers that still assume divination is
in-session only. Run diff-scoped adversarial and security reviews, fix defensible findings, and
re-review. Run `git diff --check`, `just shape-check`, `just public-safety`, and
`just commit-check`, then run `just verify` bare at final HEAD. Run
`rg -n '\$divination|read-only|writes nothing' skills` and inspect every match; no direct
installed-skill reference may characterize divination as read-only, while unrelated skills retain
their own read-only guarantees. Repository policy does not add an automated gate that asserts on
natural-language model responses.
