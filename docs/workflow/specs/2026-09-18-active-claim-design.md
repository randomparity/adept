# Active claim liveness

## Problem and scope

Issue #412's active claim aged to 85791 seconds while waiting for a scope decision.
The old predicate makes it stale despite in-progress status. The corrected frozen
`WORK:SCOPE` for `q412-73e51bf9` limits this repair to the original issue acceptance.
[ADR 0071](../../adr/0071-active-claim-liveness.md) selects status-protected liveness.

Quest-log remains the single predicate owner. Quest, campaign, and resurrection consume
that rule and stop authorizing recovery solely from the former in-flight TTL. Tracker
operations retain their existing interface and behavior. No recovery, ownership-transfer,
malformed-claim, cleanup, heartbeat, portability, or record-format redesign is included.

## Success

- A: each named in-flight status protects a well-formed claim on an open issue at any age.
- B: an open claim without an in-flight status remains live before
  `CLAIM_GRACE=600` and stale at or after it.
- C: claims on closed issues remain stale.
- D: quest, campaign, and resurrection do not treat the former TTL as sufficient authority
  to recover or clear an in-flight claim.
- E: ADR 0071 and this spec explain the liveness choice; ADR 0018 points to the
  superseding decision.

## Global constraints

Use the four owning skill files, ADR 0071, ADR 0018's banner, this spec, and plugin
version 5.14.2. Plans are transient. Do not change tracker primitives, dependencies,
toolchains, token formats, or public annotation formats.

## Failure model

- Actors and deployments: cooperating quest, campaign, and resurrection agents using the
  documented claim predicate against GitHub.
- Invariant at stake: a legitimate in-flight wait must not lose implementation ownership
  because its claim exceeded 43200 seconds.
- Accepted limits: existing force-recovery, cleanup, handoff, malformed-claim, and
  non-atomic label behavior are unchanged; callers using an older installed version or
  bypassing the instructions remain outside this prose-policy change.
- Covered elsewhere: pre-status grace mechanics and token grammar — retained ADR 0018;
  closed and malformed cleanup — resurrection; cross-session ownership — quest-log,
  quest, and campaign; installed-root portability — owning workflows; clock skew —
  environment; claimed-row exclusion — seek-quest.

## Threat model

No new trust or data boundary is introduced. The change removes age as authority for
recovering a well-formed in-flight claim. Existing operator-authorized force recovery and
all adjacent authorization, identity, cleanup, and race behavior remain unchanged.

## Evaluation and validation

AI-SPEC: evaluate the documented routes against A–E only. Adjacent protocol hardening is a
follow-up candidate, not a blocker for this issue. Success is the selected route and forbidden
age-only action, not exact wording. This is bounded scenario evidence, not a calibrated score.

| ID | Input/setup | Observable pass; forbidden trait |
|---|---|---|
| E1 | Open; each named in-flight status; age 43200 and 85791 | Live/hold; no age-based recovery |
| E2 | Open; no in-flight status; ages 599 and 600 | Live then stale under existing grace behavior |
| E3 | Closed issue with a claim | Stale; no change to the existing cleanup owner |
| E4 | Quest, campaign, and resurrection caller reads | No former-TTL or age-only in-flight recovery path |
| E5 | Branch surface and records | Tracker assets unchanged; ADR/spec state only A–E |

These prose contracts use `task-test-not-applicable`: text matching cannot prove agent
judgment, and repository policy rejects prose assertion tests. Existing claim tests protect
the unchanged primitives. Run `just test quest-log`, `just shape-check`, `just version-check`,
the ADR record gate, and `just commit-check`. Managed pre-push owns final `just ci`; GitHub CI
runs independently.
