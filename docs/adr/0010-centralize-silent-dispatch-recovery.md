# 0010 — Centralize silent dispatch recovery

## Status

Accepted (2026-08-13)

## Context

Several skills dispatch workers but define no complete response when a worker never returns a
report. `$campaign` already distinguishes silence from an observed end of run: it probes a quiet
worker, refuses to infer death from silence, and permits re-dispatch only after the harness reports
that the run ended. Copying variants of that contract into each dispatcher would let their safety
rules drift.

## Decision

Define the shared silent-worker contract once in `references/dispatch-liveness.md`. Every skill
that dispatches a worker and waits for a report links to that reference and applies it at each wait
site. The contract uses roughly ten minutes of silence as the point to probe, treats no reply by
the next observation as an unresolved hold rather than proof of death, and authorizes one
re-dispatch only after an observed end of run. The dispatcher records the hold or recovered run in
its existing run report or ledger and reconciles durable artifacts before re-dispatch.

## Consequences

- `restock`, `forge`, `saga`, and `trial-loop` share one liveness and retry rule.
- A silent live worker cannot be duplicated merely because it missed a response window.
- Dispatchers must retain enough run-local state to identify the worker, wait site, probe, and
  recovery result.
- This is an instruction contract; repository policy requires behavioral review instead of an
  automated assertion over prose.

## Considered & rejected

**Do nothing.** Rejected because the named dispatchers would retain undefined behavior when a
worker never reports, leaving operators to improvise unsafe retries or wait indefinitely.

**Repeat the full rule in every dispatching skill.** Rejected because independent copies will
diverge as the observed-end-of-run rule evolves.

**Put the rule in `$forge` and have unrelated skills cite it.** Rejected because `$forge` does not
own dispatch generally; a neutral reference makes the ownership boundary explicit.

**Treat a timeout as proof that a worker ended.** Rejected because a live worker may be inside a
long tool call, and re-dispatching it can produce competing writes, branches, or reports.
