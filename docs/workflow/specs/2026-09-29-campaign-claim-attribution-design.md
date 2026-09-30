# Campaign claim attribution and guarded recovery — #423

## Scope

Charter: #423 WORK:SCOPE token `q423-6aa6a0af`, posted 2026-09-29.
Human campaign invocation and Approve authorize an explicitly empty exclusion set.
Nontrivial M, full-spec, iterating; fixed denominator 250 changed lines.
One PR, version 6.0.0; permitted surfaces are the frozen charter's skills,
quest-log fixtures, references, workflow specifications, ADRs and metadata.
No label-description migration. ADR0076 supplements liveness ADR0071 and replaces
ADR0018's unguarded forced recovery. The historical #125 design remains historical.

## Outcome and ownership

A shared GitHub login identifies an account, not a campaign or worker.
Campaign owns assignment attribution; quest consumes that assignment; the GitHub
profile enforces the expected-holder guard. Existing tracker operations remain.

Before each new dispatch attempt, campaign mints `q<N>-<8 lowercase hex>` and
atomically persists it in existing manifest notes with issue, Campaign identity,
attempt and worker binding (worker initially pending until harness identity exists).
Read back before dispatch; bind the returned worker identity before dependent actions.
Pass the exact token and Campaign identity to quest. Retain previous attempt bindings
and observed-end evidence on replacement. A resumed active worker retains its token;
a replacement gets a fresh token. Never reconstruct a missing binding from login or
public provenance. Legacy manifest rows without bindings are unknown ownership.

Quest validates a supplied token against its issue-specific minted form before any
claim or issue mutation; a supplied invalid token fails closed, never falls back to
minting. Standalone quest mints its own token. Campaign identity is copied into the
existing WORK:SCOPE provenance field, preserving all eight charter fields.

Before dispatch or re-dispatch, classify the live claim under ADR0071. Any unknown
holder token is foreign, including the same login or Campaign identity in a comment.
Hold live foreign claims and report token, producer, age, status and matching complete
WORK:SCOPE provenance (or explicit unavailable); do not mutate the issue or claim.
Existing stale non-in-flight recovery remains available under its age rule; unknown
ownership must not be described as this run's stray. Force for a live claim requires
both an exact durable row/worker binding with harness-observed end and an explicit
operator decision naming that observed holder. End of a different worker proves nothing.
An explicit operator-directed exceptional foreign recovery must be described as foreign,
never inferred from campaign ownership. Re-read the claim immediately before dispatch;
a changed holder holds the row and invalidates the earlier recovery packet.

## Recovery interface

`claim-recover --force --expect-token <observed-holder> --token <new-owner>
--producer <login>` requires a valid expected token under the existing 1–32 ASCII
alphanumeric/hyphen grammar. Missing, empty or invalid expected tokens are usage exit 1
before any GitHub call. `--expect-token` without `--force` is also usage exit 1.
The current direct claim read must be parseable and its token must match exactly.
Mismatch or malformed description returns exit 6 with the existing holder payload;
absence returns exit 6 with `holder: null`. None deletes or creates a label.
Matching force retains delete/create and partial/transport failure behavior.
`--older-than` without force retains age checks and absent-claim creation.
A supplied `--older-than` with force does not weaken the expected-token requirement.

GitHub label deletion is not a compare-delete: a holder can change after the read
and before deletion. The guard detects a changed holder at the read, not atomically
through deletion. Existing verify gates and observed-end reconciliation remain required.
The description stays `<token>;<login>;<epoch>`, with existing parsing and exits.
Malformed force can no longer clear a claim; an explicitly authorized manual label
reconciliation is the existing escape hatch. No new automatic recovery path is added.

## Failure model

Named deployments: campaign and standalone quest on GitHub, Bash 3.2 or later,
macOS/BSD and Linux/GNU. No target architecture is declared.
- Required: unknown or changed holder, unparseable/absent holder, missing assignment,
  invalid arguments, late report, worker still active and transport/partial failure
  fail closed at their existing authority or tracker boundary.
- Accepted limitation: GitHub's read/delete race persists; the criterion asks for an
  expected-holder check under that sequence, not an unavailable atomic label API.
- Accepted limitation: workflow prose and private ledger entries are operator-managed,
  not authenticated identities. The threat model is accidental cross-run attribution,
  not malicious token copying by a credential holder.
- Accepted limitation: existing 32-bit token entropy and legacy label parser remain.
  A same-issue token collision cannot be distinguished; no format migration is requested.

## Validation and success

Executable contract: extend the stateful claim fixture with matching force, same-login
wrong holder, changed holder since authorization, malformed and absent holders,
missing/empty/invalid expected token, expectation without force, and force plus age.
Refusals assert exit, structured payload and an unchanged store with zero delete/create
calls. Match asserts replacement token. Preserve stale/absent age recovery cases.
Migrate the existing delete-timeout fixture to a parseable matching expected holder;
it must still reach bounded deletion and return partial exit 5. Migrate the sourced-zsh
success probe with its matching expected token, preserving successful-call coverage.
Run `just test claim-test tracker-test`, Bash syntax and commit checks. Prove the new
mismatch test fails against the old profile; after green, temporarily bypass the
match guard and observe that test fail, then restore exact bytes.

Instruction contracts: human review walks initial dispatch, active resume, known ended
replacement, unknown shared-login claim, missing legacy binding and changed holder.
These have no executable instruction consumer; tests must not assert prose.
Review active force call sites and provenance paths; identify historical code examples
as superseded by ADR0076 rather than pretending the archived plan is executable.
Run independent design review and scope audit, then branch and security reviews.
Managed pre-push `just ci` owns the single final full local candidate gate; Ubuntu and
macOS CI must pass. Author handoff binds WORK:REVIEW and MERGE-READY to exact SHA.

## Global constraints

Bash 3.2 floor, tab-indented shell, existing exit taxonomy and bounded commands;
no new dependency, persisted label field, service or atomicity claim. No code on main;
external sibling worktree, private uncommitted plan and session evidence. Public-safe
provenance only. Preserve existing verify gates, liveness and replacement budgets.
