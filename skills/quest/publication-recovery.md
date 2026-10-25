# Quest exceptional publication recovery

Read this complete procedure before deciding whether an interrupted publication may recover,
and before any recovery ledger or external write. Also read the complete
[ordinary publication procedure](publication.md) before a dependent validation or helper call;
its preflight, verified-URL, closing-partition, unchanged-HEAD and handoff contracts apply here.
Start with [Quest's step-5 handoff validation](SKILL.md#5-build-with-contract-evidence).
This document supplies no authorization beyond the exact human decisions required below.

### Human-authorized publication recovery

Never enter this route from `build-complete`, and never infer its authority from a request to
finish, resume, ship, merge, or run a campaign. A parsed `publication-in-progress` handoff may
make one recovery attempt only when the human explicitly authorizes recovery of that exact PR's
forge-review publication.

Revalidate the handoff and forge-result record under [step 5](SKILL.md#5-build-with-contract-evidence). There are two exclusive routes:
reconcile an already-existing verified comment below, or make the existing absence-only
publication attempt. Both consume the same single recovery allowance; a failed reconciliation
never falls through to publication.

#### Reconcile an existing verified publication

Use this route only when the retained failure evidence identifies a comment the helper already
read back successfully, but verification-ledger append or readback failed before disposal.
The human must explicitly authorize reconciliation of that exact PR and comment URL. Require:

- the live repository, PR number, branch, base and full `headRefOid` equal the handoff, including
  `delivered-head-sha:`; revalidate original private review/reason, ledger, summary and payload
  under [step 5](SKILL.md#5-build-with-contract-evidence), preserving the legacy explicit payload reconciliation rule below;
- the original retained helper body is a regular private mode-0600 direct child of the physical
  ledger directory, named `.publish-forge-review.` plus its original six-character suffix;
  establish its identity from retained failure evidence, never by newest-file selection;
- after the exact `forge-result-record`, no disposal, undisposed or recovery-authorization
  record exists; admit either no verification line or one whole exact
  `review-publication-verified: <selected URL>` line, rejecting partial, different or duplicate
  verification records; the ledger remains readable text with complete newline-terminated lines;
- a complete bounded read of PR comments identifies exactly one complete `WORK:REVIEW` comment
  matching the original summary, and that comment is the selected URL; unreadable, inconclusive,
  duplicate or mismatched evidence parks;
- read that exact comment with `gh api --hostname github.com` at its numeric comment endpoint;
  require its `html_url` to equal the selected URL, its `issue_url` to identify this repository
  and PR, and its body to equal the original retained helper body byte-for-byte; and
- the normal validation-only [helper preflight](publication.md) succeeds with the exact original inputs.

Before consuming the allowance, repeat the PR identity/HEAD and complete-comment checks. Append
and read back the existing `review-publication-recovery-authorized: pr <number> head <full-sha>`
line once. Then invoke only this mode, once, with the verified original body and URL:

```sh
"<plugin root>/skills/quest/scripts/publish-forge-review" \
  --reconcile "$VERIFIED_COMMENT_URL" "$ORIGINAL_HELPER_BODY" --claim-token "$SCOPE_TOKEN" \
  "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
  "$FORGE_LEDGER" "$REVIEW_SUMMARY" "$REVIEW_PAYLOAD"
```

This mode recomposes and compares the original inputs, reads the existing comment, records or
reuses its exact verification line, and closes disposal for the original owned paths. It never
creates a comment. A failure retains evidence and parks with the allowance consumed; do not
invoke normal publication. On success apply every existing verified-URL, closing-partition,
unchanged-HEAD and atomic `publication-verified` handoff check in [ordinary publication](publication.md), then continue to step 9.
The unchanged-HEAD check still runs after reconciliation; a changed head parks without reposting.
ADR0083 amends only ADR0048's existing-comment exclusion for this route.

#### Recover only when publication is absent

Require all of the following:

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
  `review-publication-verified:` line, no `review-publication-disposed:` line, no
  `review-publication-undisposed:` line, and no
  `review-publication-recovery-authorized:` line;
- the PR contains no complete comment whose first whole line is `<!-- WORK:REVIEW -->`, whose body
  contains this exact summary, and whose last whole line is `<!-- REVIEW:COMPLETE -->`; treat an
  unreadable or inconclusive comment list as a match and park; and
- the validation-only helper invocation in [ordinary publication](publication.md) succeeds with the exact retained inputs.

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
comment-identity, readback, disposal, unchanged-HEAD, and `publication-verified` check in [ordinary publication](publication.md). The
absence checks narrow a human-authorized exceptional recovery; they never become permission for
an automatic retry.

