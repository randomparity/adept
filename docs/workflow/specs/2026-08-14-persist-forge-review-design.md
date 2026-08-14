# Persist the forge whole-branch review design

Issue: #75

## Goal

Make `$forge`'s complete whole-branch review readable from the pull request after its worktree has
been reclaimed, while retaining `.agent/` as ignored scratch space and preserving the existing
`WORK:REVIEW` summary.

## Scope and authority

The frozen scope is issue #75 annotation token
`C70B87A9-14E3-438B-B4E2-815EAD0DCD15`. Issue #75 supplies the regression, evidence, and baseline
criteria; the operator selected PR attachment and approved this ownership split on 2026-08-14.
There are no unresolved ambiguities.

Permitted surface is the `$forge` final-review lifecycle, `$quest` shipping and `WORK:REVIEW`
contract, their direct fixtures and gates, and these design records. Standalone `$deliver` and
`$return-to-town` behavior, reviewer findings semantics, alternate external storage, new automated
consumers, generalized GitHub comment transactions, and concurrent quest controllers are excluded.

This design is governed by [ADR 0016](../../adr/0016-publish-forge-review-with-work-review.md).

## Design

### Build-to-ship handoff

After the whole-branch fix wave closes, `$forge` appends a retained-for-PR-publication ledger line
instead of disposing the final-review file. The line carries the review path and forge ledger path.
The review remains in the ignored workspace and available to every existing in-run consumer.

Resume treats a closed review without a retained or disposed line as interrupted at retention
marking. A retained line makes the forge phase complete and supplies the exact handoff paths.
Required-review failures remain terminal and never produce a retained artifact.

`$quest` records the handoff paths at the build-to-review seam and carries them through trial-loop,
simplification, local verification, and `$deliver`. A missing, non-regular, empty, or unreadable
retained review is a named shipping failure.

### Durable PR publication

After `$deliver` creates the PR, `$quest` invokes one deterministic publication helper. The helper
accepts `required`, `not-required`, and `failed` modes. Required mode validates the retained review.
Not-required mode publishes a summary-only `forge review: not required` result with the already
verified mode reason. Failed mode stops before any GitHub write.

The helper creates one ignored temporary body file beside the forge ledger. It writes one complete
outer `WORK:REVIEW` block: the existing compact review summary first, followed by a separately
labelled `Forge whole-branch review` section. Every forge-review line is prefixed by four spaces, so
literal marker, sentinel, or summary-shaped lines remain Markdown code payload rather than outer
annotation structure. The helper validates the summary as UTF-8 text without NUL and rejects
whole-line outer markers. It runs the repository public-safety guard against the exact completed
body file and posts that same file through `gh pr comment --body-file`.

Successful comment creation must return the created comment URL. The helper resolves that exact
comment identity, reads it back once, and requires its body to equal the body file exactly. It then
appends `review publication verified` with the comment identity to the forge ledger and reads the
line back. Only that durable verification authorizes recoverable disposal of the retained review
and body file. The helper appends and verifies the disposal ledger line, then returns the comment
URL.

Comment failure, missing returned identity, failed exact readback, ledger failure, or disposal
failure stops the quest with remaining evidence retained. An ambiguous write does not retry or scan
all comments: a human may reconcile the public comment and ledger. This change does not promise
automatic recovery across every process-loss seam or support concurrent controllers.

## Failure cases and verification

- Required review missing, empty, unreadable, or non-regular: stop before body creation.
- Failed required forge review: stop before delivery; never downgrade it to `not required`.
- Verified no-review mode: publish the compact summary with `forge review: not required`; do not
  invent review content.
- Invalid summary encoding, NUL, or outer marker: stop before GitHub write.
- Public-safety match or scan fault on the exact body: stop before GitHub write.
- Comment call fails or returns no usable identity: retain the review and body; do not retry.
- Exact comment readback differs or fails: retain the review and body; do not claim durability.
- Verified-ledger append/readback fails: retain both files and the public comment identity.
- Disposal failure: retain all files not already moved to trash and report the exact remaining
  ledger-owned paths privately; do not claim a closed scratch lifecycle.
- Existing `WORK:REVIEW` summary fields and outer sentinels remain first and intact. Review payload
  containing those literal lines stays indented and cannot become structure.

Focused fixtures first fail against current behavior, then prove all three modes, marker-like
payload, summary rejection, public-safety failure, exact comment readback, ledger-before-disposal
ordering, and retained evidence on every failure. `just verify` remains the full local/CI guardrail.

## AI-SPEC and evaluation plan

The user is the quest operator. The trigger is completion of `$forge`'s whole-branch review during
an issue-backed quest. Inputs are the model-written review, forge ledger, compact trial-loop
summary, and created PR identity; output is a complete `WORK:REVIEW` comment and closed scratch
lifecycle.
Allowed sources are the frozen scope, repository files, verified worker artifact, and exact GitHub
comment readback. The workflow must not invent content, publish a local path or denied public data,
discard the only local copy before verified publication, or label forge output as trial-loop output.
A missing or unsafe required artifact fails closed. No model call is added; success is exact comment
readback, durable verification, then recoverable disposal.

| Case | Gate | Observable result |
|---|---|---|
| `PFR-1` safe required review | block | One exact comment; verified ledger precedes disposal. |
| `PFR-2` unsafe body | block | Public-safety failure; zero posts; review retained. |
| `PFR-3` mode arms | block | Required publishes; not-required is summary-only; failed never posts. |
| `PFR-4` comment failure/ambiguity | block | No retry; review/body retained with actionable failure. |
| `PFR-5` exact readback mismatch | block | No verified/disposed ledger lines; evidence retained. |
| `PFR-6` ledger/disposal failure | block | No false closed-lifecycle claim; remaining paths retained. |
| `PFR-7` hostile marker payload | block | Markers are indented payload; outer summary stays parseable. |

Existing deterministic shell fixtures judge these cases; no model grades its own output.

## Threat model

The new boundary is model-written scratch content moving to a public GitHub PR. The review worker is
untrusted and may emit malformed Markdown or host-private text. Existing boundaries widened are
GitHub comment creation and quest scratch cleanup.

The helper reads only the controller-supplied regular review, indents it as payload, validates the
controller summary, scans the exact completed body with the existing public-safety guard, and passes
that file through `--body-file` without shell interpolation. Exact returned-comment readback binds
the public copy to the checked body. Disposal requires a durable verified record.

Credential compromise, malicious content already committed to the public repository, GitHub's
renderer, ambiguous-write recovery, concurrent controllers, and expansion of the public-safety
pattern set are out of scope. These cases retain evidence and stop rather than adding transaction,
retry, locking, or generalized parsing machinery.
