# 0086 — Wait through the capabilities the harness exposes

## Status

Accepted (2026-10-07)

## Context

Issue #344 requires an executable positive waiting procedure on Codex and Claude Code.
The shared dispatch reference owns recovery, but forge and campaign assume a blocking
field and the reference promises zero-turn waits regardless of the active surface.

## Decision

Keep waiting in the shared dispatch reference: record the handoff, perform independent
work, await the needed event, reconcile once, then advance or diagnose. Select native
notification/wait, supported foreground dispatch or CLI process completion from the
actual schema. A worker's inner tool wait is a separate lifecycle.

Unchanged timeout returns remain pending. Required progress messages use known facts;
healthy waits need no discretionary status reads. A task-appropriate deadline permits
bounded diagnosis, never inferred termination. Retain ADR 0010's ownership, observed-end,
late-report reconciliation and probe/replacement budgets.

## Consequences

Serial ordering no longer depends on a blocking-dispatch field. Harness-imposed timeout
or progress turns remain visible in accounting. Capability checks and finite live traces
support only their tested surfaces; they establish no universal cost or reliability claim.

## Considered & rejected

- **Keep mandatory blocking dispatch.** verified: the observed Codex `spawn_agent` schema
  exposes asynchronous dispatch without a blocking flag and has a separate `wait_agent`.
- **Add a watcher/runtime.** judgment: unnecessary lifecycle and persistence for capabilities
  already owned by the harness, and excluded by the approved scope.
- **Keep zero-turn guarantees.** verified: the observed native wait accepts a bounded timeout;
  the active interface also requires progress updates, so indefinite silence is not promised.
