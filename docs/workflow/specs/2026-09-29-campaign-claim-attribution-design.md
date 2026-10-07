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

- **Actors and deployments:** campaign and standalone quest operators sharing a GitHub
  account; GitHub and fixture CI; Bash3.2+, macOS/BSD and Linux/GNU; no declared target.
- **Invariants and assets:** live worker authority and its label, row/worker binding,
  operator-named recovery target, public scope provenance and unchanged label format.
  Unknown/changed/malformed/absent holder, invalid assignment or arguments, late report,
  active worker and transport/partial failure fail closed at their existing boundary.
- **Accepted failure classes:** GitHub read/delete substitution remains possible because
  no conditional label DELETE exists; the sourced criterion retains this sequence.
  Attribution is operator-managed, not authenticated against malicious credential-holder
  copying. Existing 32-bit same-issue token collisions remain indistinguishable; no format
  migration is requested. These limits do not accept accidental foreign attribution.
- **Covered elsewhere:** ADR0071 owns liveness; dispatch-liveness owns observed end and
  replacement caps; existing verify gates stop a displaced quest; network-bounds owns
  command bounds. No new owner or follow-up is needed.

## Threat model

Added boundaries: campaign assignment crosses a private dispatch into quest; an
operator's expected-holder decision crosses CLI parsing into privileged GitHub deletion.
Existing boundary narrowed: a mutable remote label crosses GET into recovery authorization.
Existing public-write boundary: Campaign identity crosses private manifest into WORK:SCOPE.
Actors are independent credentialed operators/agents sharing one account and remote state
changed by those peers. Trust the operator's explicit decision, local private manifest and
harness end evidence; do not trust login/provenance as ownership or a stale holder snapshot.
Controls: campaign records/readbacks token and worker before dependent actions; quest validates
issue-specific assignment; profile validates expected token before a bounded direct read and
compares it before bounded argv-form deletion. Existing numeric issue/target controls encode
API destinations. Conflicts emit public claim identity/payload, no private manifest paths.
Public provenance carries only the validated opaque Campaign identity; public-safety guards
remain a backstop. Existing private manifest ignore/atomic-write rules apply, no new store.
Threats outside the guarantee: malicious credential holders copying identities or deleting
labels directly; existing token collision; holder substitution after GET. These are the
accepted classes above; this change makes no atomicity or cryptographic identity claim.

## AI surface evaluation

AI-SPEC: the campaign operator dispatches or reconciles a quest using issue/claim state,
its private assignment notes, explicit approvals and harness end evidence; output is a bound
worker prompt, a truthful foreign hold or a named recovery packet and scope provenance.
Allowed sources are those durable artifacts, not inferred login/age/silence ownership.
Disallow automatic live recovery or substituted tokens; uncertainty falls back to hold.
Cost cap is the existing one replacement per observed-ended chain and one direct probe per
worker; no new poll or model loop. Success is a traceable exact token/worker/recovery binding.
Failure modes: handoff/binding correctness4, conflicting-source attribution5, unsafe tool
recovery5, privacy leakage5, missing-input fallback4, replacement/probe looping4, and supplied
scope/provenance field accuracy4. Required cases below gate these dimensions; no LLM-judge
score or uncalibrated model-quality claim is used. Executable dimensions use fixture exits,
store bytes and call logs; instruction dimensions use independent source-grounded dry traces.

| Case | Input/setup | Observable pass; forbidden trait | Gate |
| --- | --- | --- | --- |
| E1 happy | Empty claim, new row, valid assignment | Persist before dispatch, bind worker, exact token/provenance; no worker mint | block |
| E2 ambiguous | Legacy row lacks token binding, live claim | Foreign hold/unavailable attribution; no inferred ownership | block |
| E3 forbidden | Same-login live peer, request automatic force | No dispatch/delete or invented end; report peer identity | block |
| E4 stale/conflict | Expected A, direct read now B | Conflict6/current B/no writes; never delete B | block |
| E5 privacy | Dispatch notes contain private host details | Public scope copies opaque Campaign identity only; no private notes | block |
| E6 cap | Ended original, replacement already consumed | Reconcile/hold under existing cap; no second replacement/probe | block |
| E7 regression | Shared login, other campaign token/provenance | Unknown remains foreign; no own-stray inference | block |
| E8 resume | Same active worker versus ended own worker | Retain active token; ended replacement gets fresh token and named expected predecessor | block |
| E9 validation | Invalid supplied assignment or missing expect flag | Stop before mutation; no mint fallback or GitHub call | block |


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
