# Quest publication guidance on demand

## Problem

Quest loads publication and exceptional recovery details before early phases need them (#464).
This pilot reorganizes instructions without changing workflow policy.

## Scope

One Cast unit: retain ordering, invocation, completion, common safeguards and complete step-5
handoff validation/resume routing in `skills/quest/SKILL.md`. Move step-8 publication detail
verbatim to `skills/quest/publication.md`; move exceptional recovery detail verbatim to
`skills/quest/publication-recovery.md`. Require reading the applicable full document before
dependent decisions or writes. Keep existing heading anchors as delegating entrypoints and
adjust relative links in moved material. Preserve the newly landed worker model guidance.
The entrypoint remains the phase owner; supporting documents own its detailed procedures.
Direct callers keep their entrypoint anchors; obsolete inline detail is removed. No helper,
schema, retry or authorization policy changes. Bump assigned manifest version to 7.11.3.
No ADR: this is document organization with existing policy and no architectural decision.
A single combined document would load exceptional recovery on ordinary shipping; two files
are the minimum separating those paths. Other skill organization, policy/retry changes,
helper/schema changes and credentialed/billed benchmarks remain operator-owned exclusions.

### Failure model

- Actors and deployments: Quest operator/agent in an installed plugin, startup or resume.
- Invariants and assets: unchanged claim, privacy, exact-head, disclosure, publication,
  cleanup, authorization and retry contracts; complete installed routes and compatibility anchors.
- Accepted failure classes: no billed-cost or model-compliance guarantee; measured loaded
  material only, as the issue requests. Unrelated skill and helper behavior is outside this pilot.
- Covered elsewhere: existing structural gates own plugin/link shape; operator owns excluded
  policy, helper/schema and benchmark changes. Literal comparison and route walks cover relocation.

## Success

The entrypoint retains the named common contracts and routes each of build-complete,
publication-in-progress and publication-verified to its complete applicable contract.
Moved publication and recovery clauses preserve their policy; installed paths and existing
anchors resolve. Record before/after bytes, words and lines and required document sets for
startup and each resume route, without claiming billed savings.

## Validation

`task-test-not-applicable`: this pure prose relocation has no new executable behavior or
machine-consumed structure; prose-pinning tests would violate repository policy. Review
literal moved text, contextual references and existing structural/link/plugin/version gates.
Walk normal shipping, interrupted publication, verified resume and unauthorized recovery refusal.
AI-SPEC: user is Quest operator; trigger is workflow entry/resume; input is entrypoint plus
applicable linked text and existing handoff; output is unchanged phase action; sources are
installed skill and validated run evidence; forbidden is a dependent write before its complete
contract or unauthorized recovery; fallback is existing park protocol; no extra provider
experiments; context budget is measured loaded material, no latency/billed guarantee.
Eval cases (block; manual pass/fail): normal shipping loads publication before G4/delivery;
ambiguous interrupted publication parks; unauthorized recovery refuses before writes;
stale HEAD parks; unsafe/nonprivate artifact parks; consumed recovery allowance refuses;
verified resume validates closing records/HEAD then step9 without re-publication (regression).
Each passes only with the named route/guard and fails on a skipped guard, extra write or retry.
