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
automated consumers are excluded.

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
The summary fields remain concise and first. A separate `Forge whole-branch review` section then
contains the review file verbatim. The annotation identifies this section as the forge review, not
the later trial-loop review summary, and contains no local artifact path.

Before posting, `$quest` runs the repository's public-safety guard against the review file. A
finding or scan fault stops publication with the artifact retained. The post uses the quest-log
body-file recipe. Readback must select the complete annotation and verify both the run-specific
marker and the complete forge-review content. Only that readback authorizes disposal.

If no forge artifact exists because `$forge` legitimately ran without party mode or stopped after
a named review failure, `WORK:REVIEW` records `forge review: unavailable` with the existing reason.
It never manufactures review content. A publication rejected for comment size or service failure
stops shipping and retains the source file so a human can resolve the failure without rerunning the
review.

### Cleanup and resume

After verified publication, `$quest` moves the retained file to trash and appends `review artifact
disposed after PR publication` with its former path to the forge ledger. If the file is already
absent on resume but verified PR publication exists, the trash step is treated as complete and the
ledger is closed. If publication cannot be verified, absence is a blocker rather than inferred
success.

`$return-to-town` remains unchanged: by the time it reclaims the worktree, the PR is the durable
copy and the scratch lifecycle is closed.

## Failure cases and verification

- Missing, empty, or unreadable retained review: stop before posting and retain all remaining
  evidence.
- Public-safety match or scan fault: stop before posting; never publish the rejected content.
- Comment creation failure: retain the review and report the failed publication.
- Ambiguous write result: read back before retrying; retry only when the intended complete block is
  absent.
- Comment readback mismatch: retain the review and stop; do not claim durability.
- Crash after verified publication but before trash: resume from the verified PR block, dispose,
  and append the ledger marker.
- Crash after trash but before ledger append: verified publication plus the absent source closes
  the disposal marker without a second deletion.
- Existing `WORK:REVIEW` summary: fixtures prove its fields and complete sentinels remain present,
  with the forge review in a distinct section.

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
| Artifact discarded before durable publication | 4 | Contract fixture proves publication readback precedes disposal. |
| Unsafe or host-private text published | 5 | Fixture proves the public-safety guard runs bare and a failure stops posting. |
| Fabricated review on missing input | 4 | Fixture proves missing review is disclosed as unavailable. |
| Forge review conflated with trial-loop summary | 4 | Fixture proves separate labelled sections inside `WORK:REVIEW`. |
| Duplicate write after ambiguous response | 4 | Fixture proves readback precedes the single bounded retry. |
| Oversized or rejected comment silently loses review | 4 | Fixture proves publication failure retains the source and stops shipping. |

Stable cases: `PFR-1` publishes a safe non-empty review and then disposes it; `PFR-2` rejects a
review containing a denied host path; `PFR-3` discloses a named unavailable review; `PFR-4`
reconciles an ambiguous write by readback without duplication; `PFR-5` retains the artifact when
GitHub rejects publication; `PFR-6` resumes after publication before disposal. Each is a blocking
contract fixture whose observable traits are the required ordering and annotation fields. The
forbidden traits are early deletion, fabricated content, local paths, duplicate comments, and a
success claim without readback. Existing deterministic shell fixtures are the judge; no model
grades its own output.

## Threat model

The new boundary is model-written scratch content moving to a public GitHub PR. The untrusted actor
is the review worker, whose output may contain malformed Markdown or host-private text. Existing
boundaries widened are GitHub comment creation and the quest's scratch cleanup.

The quest trusts only a non-empty file at the controller-chosen path after the forge checks. Before
publication it applies the repository public-safety scan; GitHub receives the body as data through
`--body-file`, never shell interpolation. Markdown is intentionally rendered by GitHub, but it
does not grant repository execution. A complete-marker and content readback controls ambiguous
writes. Disposal requires that verified readback. Failures may disclose only a public-safe reason,
not rejected content or local paths.

Credential compromise, malicious content already committed to the public repository, GitHub's own
Markdown renderer, and expansion of the public-safety pattern set are out of scope: this change
does not create or widen those mechanisms. The residual comment-size limit is accepted as a
fail-closed publication error with the original scratch artifact retained.
