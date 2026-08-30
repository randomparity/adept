# 0048 — Preflight forge-review publication before terminal state

## Status

Accepted (2026-08-30)

## Context

Quest rewrites its private handoff to `publication-in-progress` before
`publish-forge-review` validates and composes the comment. That phase deliberately forbids an
automatic retry because a failed comment request may have succeeded remotely. A deterministic
local validation failure therefore parks a green pull request in a state intended for ambiguous
network outcomes.

The helper also caps every source at 4,096 bytes even though its complete comment is independently
bounded at 32,768 bytes. A retained 5,548-byte forge review demonstrated that the smaller cap can
reject an otherwise valid publication before any GitHub request.

## Decision

The helper gains a validation-only preflight mode. It performs the same argument, artifact,
composition-size, and public-safety checks as publication, makes no GitHub request, changes no
ledger, and removes only its generated temporary body. Quest must run this mode successfully
before it writes `publication-in-progress`.

The forge review has no separate 4,096-byte cap. The existing 32,768-byte composed-body cap is its
effective bound. Summary, optional payload, and inline not-required reason retain their smaller
caps.

A `publication-in-progress` handoff remains terminal by default. One human-authorized recovery may
continue only after Quest verifies the unchanged repository, pull request, branch, base, delivered
HEAD, handoff, forge-result ledger record, and retained inputs; finds neither a matching complete
`WORK:REVIEW` comment nor a later publication-verification record; and reruns the new preflight
successfully. It records the recovery authorization in the private ledger before the attempt. That
record consumes the recovery allowance whether publication succeeds or fails.

## Consequences

- Deterministic local failures occur while the handoff remains recoverable.
- Ambiguous network failures still park without an automatic retry.
- Reviews are bounded by the actual composed artifact rather than an unrelated per-source limit.
- Legacy parked runs can be recovered without treating absence of a comment as blanket retry
  permission.
- Recovery still assumes the human-authorized operator has excluded a concurrent publisher; the
  GitHub issue-comment API supplies no idempotency key or atomic create-if-absent operation.

## Considered & rejected

- **Raise the 4,096-byte cap only.** verified: running the current helper with a private 5,548-byte
  review exits before `gh` with `required review exceeds local size limit`; raising the cap removes
  that trigger but leaves every other deterministic validation failure after the terminal handoff.
- **Retry every `publication-in-progress` handoff after finding no comment.** judgment: absence is
  not proof that another actor is not between its own check and write, and it would erase the
  phase's ambiguity boundary.
- **Split large reviews across comments.** judgment: it adds ordering, partial-publication, and
  cleanup state when the existing single-comment budget already fits the observed review.
- **Store the review outside GitHub.** judgment: it reopens ADR 0016's durability ownership without
  addressing the state-ordering defect.
