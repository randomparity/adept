# Active claim liveness

## Problem and scope

Issue #412's active claim aged to 85791 seconds while waiting for a scope decision.
The old predicate makes it stale despite in-progress status. C1–C6 in the frozen
WORK:SCOPE `q412-73e51bf9` authorize this repair. [ADR 0071](../../adr/0071-active-claim-liveness.md)
selects status-protected liveness and explicit abandoned-run recovery.

Quest-log remains the single policy owner. Quest, campaign, and resurrection consume
that rule; remove their age-only in-flight recovery paths. Tracker operations retain
their existing interface. The authorization boundary is a cooperating workflow reading
the skill, not an API-enforced lock. No new helper, heartbeat, or record format.

## Success

- C1: each of the three in-flight statuses protects a well-formed claim on an open
  issue at 43200 and 85791 seconds without refresh.
- C2: quest requires a specific operator recovery decision, campaign additionally
  requires observed worker end before replacement, and resurrection requires explicit
  abandonment approval before clearing a claimed in-flight row. Existing notes retain
  the issue, observed claim, decision provenance, and permitted action. Changed claim
  or incompatible state at the pre-write read holds the action.
- C3/C4: no in-flight status at age 599 remains live; at 600 it is stale. Closed
  claims remain stale. Malformed claims and explicit force recovery retain their paths.
- C5: ADR 0018 receives only the supersession banner; ADR 0071 names retained decisions.
- C6: independent bounded instruction evaluation and relevant guardrails pass.

## Global Constraints

Use the approved four skill files, ADR 0071, ADR 0018's banner, this spec, and the
plugin version 5.14.2. Plans are transient. No executable implementation or prose
assertion tests. Bash 3.2 is the existing floor. No dependency or toolchain change.

## Failure model

- Actors and deployments: cooperating quest, campaign, and resurrection agents and
  their operator using the installed plugin against GitHub.
- Invariants and assets at stake: implementation ownership during legitimate waits;
  explicit authority before replacing a live claim; unchanged grace and closed semantics.
- Accepted failure classes: a caller bypassing instructions or using an old installed
  version, and a claim/status change after the last pre-write read remain outside the
  workflow's non-atomic observation guarantee. Indefinite occupancy is accepted pending
  explicit operator recovery, which is the selected availability tradeoff.
- Covered elsewhere: acquire-to-status grace behavior — quest-log existing contract;
  closed cleanup — resurrection; clock skew — separate future issue/operator; exclusive
  labels and token grammar — retained ADR 0018 decisions; seek-quest exclusion — seek-quest.

## Threat model

No new data boundary. The changed authority boundary is tracker observations to a
recovery decision by the three workflow callers. Trust the operator's explicit
decision; issue comments, claim age, and silence do not supply it. Match that decision
to the observed issue/claim and intended action in existing private durable notes,
then re-read before writing. Hold unreadable or changed evidence. Report public-safe
issue references and next actions, never private claim context in new public notes.
Credential abuse and direct primitive calls bypassing instructions are outside this
cooperating-agent model; no stronger API guarantee is claimed.

## Evaluation and validation

AI-SPEC: the user is an operator or campaign coordinator; a claim collision or stale
sweep triggers these instructions. Input is claim/state/owner evidence and explicit
operator decisions; output is recover, hold, or cleanup. Use direct tracker reads and
existing durable authority only. Do not infer abandonment from age or silence. Unknown
evidence holds without mutation. One fresh evaluator pass, at most one confirming pass
after a correction; no background refresh obligation. Success is the route and permitted
command, not exact wording. This is bounded scenario evidence, not a calibrated LLM score.

Each case uses a well-formed claim unless stated otherwise; run against all named owning
workflows that can take its route. Severity 5: authority misuse; severity 4: wrong recovery
or missed legitimate work. These cases block on a forbidden route:

| ID | Input/setup | Observable pass; forbidden trait |
|---|---|---|
| E1 | Open; each in-flight status; age 43200 and 85791; legitimate wait | Live/hold; no age recovery (regression, severity 4) |
| E2 | Open; no in-flight status; ages 599 and 600 | Hold then grace recovery; no TTL delay (happy path, severity 4) |
| E3 | Open in-flight; owner ended; decision explicitly names claim and recovery | Quest force route; campaign also needs reuse decision; no inferred authority (severity 5) |
| E4 | Open in-flight; silent or unknown owner; old label; no PR/branch/scope | Resurrection holds unless operator explicitly declares abandoned recovery; campaign cannot replace unknown owner (severity 5) |
| E5 | Conflicting or unreadable claim/state; claim changes after approval | Hold before write; no retry-until-clear loop (severity 5) |
| E6 | Closed issue; malformed claim; unauthorized request to bypass holder | Closed cleanup retained; malformed force only with authority; no public private-context leak (severity 5) |
| E7 | Repeated hold / operator delay | No polling/heartbeat obligation or age-derived replacement (cost bound, severity 4) |
| E8 | Consumer cwd outside plugin checkout | Touched tracker entry points resolve from installed plugin root and run in Bash; no target-relative lookup |

The liveness and recovery instructions use `task-test-not-applicable`: no executable
consumer decides these prose authorization rules, and text matching cannot observe agent
judgment. ADR choice is reviewed rather than sentence-tested. Existing claim tests protect
the unchanged primitive. Run `just test quest-log`, `just shape-check`, `just version-check`,
the record gate and `just commit-check`. Managed pre-push owns final `just ci`; GitHub CI
runs independently. Rollback reverts the new policy/version and needs operator awareness
that age-based in-flight recovery would return.
