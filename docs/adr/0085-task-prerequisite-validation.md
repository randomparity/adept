# 0085 — Validate task prerequisites before dependent work

## Status

Accepted (2026-10-07)

## Context

Issue #340 extends attunement's prerequisite recording. A helper's commands and
interpreter can be absent or below a declared floor even when the tool-call shell
works. Repository setup recipes cover their own development tools, not every
installed skill a task invokes.

## Decision

Keep validation in attunement instructions. Build a task-scoped inventory from
invoked helpers and repository guardrails, check actual command/interpreter
resolution and declared floors before dependent work, and retain the evidence.
A documented equivalent is usable only when it preserves the required behavior
through the actual invocation. Otherwise name the dependency and installation or
PATH remedy and hold only dependent work. Installation still needs applicable
authorization; safety checks cannot be skipped.

This extends the existing prerequisite owner; it changes neither the detector
nor helper implementations. The specification records the bounded reader cases.

## Consequences

Missing prerequisites surface before the operations that need them. Agents must
inspect the selected invocation chain and interpret tool-specific version output;
there is no universal version parser or exhaustive package inventory. Validation
remains evidence for the observed environment, requiring recheck when it changes.

## Considered & rejected

- **Recording alone.** verified: issue #340's expected scope requires availability
  and declared-floor validation before dependent work.
- **Global installer or dependency framework.** judgment: broader lifecycle and
  maintenance surface than this task-scoped instruction change needs.
- **Policy inside the architecture detector.** judgment: combines task-dependent
  prerequisites with host observations and requires an unnecessary code change.
