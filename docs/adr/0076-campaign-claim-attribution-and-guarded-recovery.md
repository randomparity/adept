# 0076 — Attribute campaign claims and guard forced recovery

## Status

Accepted (2026-09-29).
Supersedes ADR0018's unguarded forced-recovery and malformed-force behavior;
supplements [0071](0071-active-claim-liveness.md), retaining its liveness rule.

## Context

Issue #423 demonstrates that shared account logins do not attribute a live claim
to a campaign's worker. Existing campaign instructions mint tokens in workers and
permit recovery after an observed end without binding that end to the holder.
The GitHub profile's forced path currently deletes any held or malformed label.
Source evidence: `profile_claim_recover` in the GitHub profile; campaign step 5;
claim fixtures currently assert unconditional young/malformed forced recovery.

## Decision

Campaign persists an issue-specific scope token before dispatch and binds it to
the dispatched worker in existing private manifest notes. Quest consumes the token
and includes Campaign identity in the existing WORK:SCOPE provenance field.
Unknown tokens remain foreign. A live-claim recovery decision must identify its
observed holder; campaign-owned recovery also needs the recorded holder's worker end.

`claim-recover --force` requires `--expect-token`, validates it before network calls,
and refuses a nonmatching, malformed or absent current holder with conflict exit 6.
Age recovery and the persisted `<token>;<login>;<epoch>` description remain unchanged.
This breaking invocation contract ships as version 6.0.0.

## Consequences

- Old force callers must supply the operator-named observed token. Malformed claims
  require explicitly authorized manual reconciliation instead of forced recovery.
- GitHub label GET then DELETE remains non-atomic: the guard detects substitution
  before its read but cannot prevent substitution between read and delete. Existing
  verify gates and harness-observed-end reconciliation remain necessary.
- Private attribution is an operator-managed record, not a cryptographic identity;
  same-issue token collisions and malicious credential-holder copying remain possible.
- Legacy manifests without token bindings cannot prove ownership and hold live claims.

## Considered & rejected

- **Do nothing** — requirement judgment: contradicts #423's holder-attribution and
  expected-holder criteria; a shared login cannot supply a worker binding.
- **Add campaign identity to label descriptions** — source-backed: the current
  `github_claim_read` requires three fields and treats a fourth as malformed.
  Unnecessary persisted-format migration when the existing token discriminates runs.
- **Use login or WORK:SCOPE provenance alone** — requirement judgment: #423's observed
  shared-account incident requires exact durable token ownership, not a descriptive hint.
- **Replace the coordination store** — scope judgment: atomic compare-delete needs a
  different primitive and caller migration; #423 explicitly proposes the bounded
  expected-token check under the existing read/delete sequence.

## Provenance

Human campaign invocation and Approve for #423, 2026-09-29; explicitly empty exclusions.
Charter token `q423-6aa6a0af`; design: campaign claim attribution and guarded recovery.
