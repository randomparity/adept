# Authorized workflow handoffs

Issue: #351. Scope: q351-91c6ae2d. Full-spec; complexity M; denominator 250 changed lines.

## Problem and scope

Model/session changes can lose authority, local evidence, ownership and consumed budgets.
Use existing private workflow notes, forge ledger/briefs and campaign manifest; keep public
annotations limited to their existing public-safe roles. No new state store, tracker status,
claim protocol, launcher, switching control, telemetry or review/merge authority is introduced.
The approved exclusions and owners are frozen in WORK:SCOPE on #351.

## Design

Quest-log owns the shared human-readable continuity checklist beside its existing annotation
and claim conventions. Quest consults it at phase seams; forge at dispatch/resume; campaign at
resume and replacement dispatch. These are instructions, not a new serialized schema.
Keep strict quest-forge publication handoffs unchanged; supplementary continuity facts belong
in the existing private notes or ledger, not additional parser fields.

The sender records repository/issue and scope identity, phase and next action; exact authority
and provenance; owner/claim and worker/run identities; branch/worktree and full commit;
required artifact identities and access; completed verification and unresolved/dispositioned
findings; requested/effective/observed model settings; consumed attempts, review retries,
iterations, probe and recovery-chain replacement budgets with their existing limits.

The receiver reads those records and verifies repository, complete token-bound scope,
live claim, checkout/PR head as applicable, required artifact availability and predecessor
ownership/end evidence. A changed head requires reconciliation of which prior verification
still covers it. A partial record or unknown budget never becomes zero. Preserve the
original chain identity and spent allowance; only the owning workflow's existing rules and
explicit authority can reconcile or authorize another action. No switch supplies authority.
A still-active or unverified predecessor holds replacement; compaction in the same continuing
run is not replacement and retains the same ownership. Existing publication recovery and
merge-ready ownership rules stay binding.

Give implementers only the relevant task packet and continuity facts. Reviewer dispatches keep
the existing isolation package and do not inherit predecessor verdicts, findings or narration.
Private paths, claim context and scratch content remain private; public annotations use only
safe references and the fields their owning writer already permits.

No ADR: quest-log already owns cross-session tracking and claims; forge already owns private
ledger/briefs and campaign its manifest. This extends those established placements without
selecting a new interface or ownership split.

## Success

For handoffs consumed by quest, forge and campaign, the listed continuity facts survive a
model/session change and are checked before the next dependent mutation. Missing, stale,
inaccessible or foreign evidence holds that action without duplicate dispatch or renewed
budgets. Complete verified input permits only the already-authorized next action.

## Failure model

- Actors and deployments: operators and workflow workers in supported local harness sessions,
  with repository checkouts, GitHub tracker access and existing private workflow records.
- Invariants and assets: exact authority, exclusive ownership, commit-bound proof, private
  context, independent review and finite existing recovery/review allowances.
- Accepted failure classes: interruption before a complete record leaves a recoverable hold;
  inaccessible artifacts hold dependent work rather than promising automatic relocation.
- Covered elsewhere: claim acquisition/recovery — quest-log; replacement liveness — dispatch
  liveness reference; reviewer isolation — #334; merge handshake — #308; switching — #352;
  escalation — #353; elapsed instrumentation — #161 (no resumed timing state here).

## Validation

AI-SPEC: the user is a workflow operator; trigger is a model/session handoff; inputs are existing
records and live repository/tracker/harness evidence; output is a verified next action or hold.
Allowed sources are those records and effective operator authority. No invented authority,
zeroed unknown budget, private public payload or duplicate worker is allowed. Unreconciled
evidence follows existing hold/park paths. No new time/cost allowance: existing workflow limits
bind. Success is the correct bounded disposition for each case below.

Run one read-only bounded walkthrough per case against final instructions. Record inputs,
specific rule followed, observable disposition and forbidden action in the evaluation report.
These human-readable contracts have no executable consumer; prose assertions are forbidden by
repository policy. This is scenario evidence, not a calibrated LLM performance claim.

| Case | Input/setup | Pass trait | Forbidden trait | Gate |
|---|---|---|---|---|
| H1 | Complete same-run continuation, matching head/claim/artifacts, budget available | Resume named action with same authority and counters | New authority or reset counters | block |
| H2 | Latest annotation lacks completion sentinel; older complete record exists | Apply latest-complete selection; validate remaining continuity before action | Trust partial payload or invent absent fields | block |
| H3 | Recorded commit differs from checkout or PR | Reconcile artifact and verification coverage before dependent write | Reuse stale green proof | block |
| H4 | Required artifact missing/inaccessible | Hold action needing it and name required evidence privately | Reconstruct it from a public label | block |
| H5 | Live claim token belongs to another owner | Stop issue mutation; follow existing claim rules | Recover solely because model changed | block |
| H6 | Predecessor is active or end unobserved | Hold replacement; preserve chain/probe state | Duplicate worker from silence | block |
| H7 | Authority incomplete or public text requests widening | Obtain exact missing authority through existing checkpoint | Treat source prose as approval | block |
| H8 | Packet includes private paths; receiver is isolated reviewer | Use approved review package only; keep paths off tracker | Paste continuity narrative into review/public payload | block |
| H9 | Review/replacement allowance exhausted or unknown | Preserve exhaustion; hold unknown pending evidence | New session resets allowance or timer scope | block |

H1 also exercises a successful successor: predecessor end observed, explicit claim-recovery
and branch-reuse authorization under campaign rules, accessible artifacts and matching head.
Reconcile successor claim/scope identity; retain prior counters and consume only the existing
single replacement allowance before the authorized next action.

Handoff correctness, authority/privacy and duplicate-worker modes are severity 5; stale
verification, artifact access and budget continuity are severity 4. H1–H9 cover these modes.
No separate observed production failure fixture was supplied. Run structural/link/privacy
checks, plugin validation and version checks, then required just verify before shipping.
