---
title: Standing repair barred for accepted instruction locations
status: proposed
date: 2026-07-10
related:
  - 0064
  - 0081
---

## Context

ADR 0064 defines accepted instruction locations (`AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`) and gates repairs touching them through policy admission. ADR 0081 records that standing repair authority binds maintainer approval to the exact Git blob of the declaring instruction file, so editing that file invalidates old packets.

A security pass on PR #447 (#446) raised a gap: if a standing policy's permitted surfaces cover an accepted instruction location, a repair admitted under that policy could restore an earlier blob of the declaring file itself. That would revive authority the maintainers later narrowed or revoked, without a fresh human approval. ADR 0081 records this replay as an accepted residual and defers the barring rule to a follow-up. ADR 0064 names no control for it at the root locations either.

## Decision

A repair whose diff adds, edits, removes, or renames any accepted instruction location (`AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`) is **barred** from standing-policy admission and from policy-only merge, regardless of the policy's permitted surfaces. Such repairs fall back to the ordinary per-repair human gate.

The bar is enforced at two checkpoints:

1. **Policy-admission check** — when evaluating whether a repair qualifies for standing-policy admission, if the diff touches any accepted instruction location, the repair is rejected from policy admission.
2. **Pre-merge recheck** — when re-evaluating policy admission before merge, the same bar is enforced; a repair that now touches an accepted instruction location is blocked from policy-only merge.

All other guarantees in ADR 0064 and ADR 0081 remain unchanged.

## Consequences

- Repairs touching accepted instruction locations always require explicit human approval, even when a standing policy would otherwise admit them.
- No behavior changes for repairs that do not touch accepted instruction locations.
- The bar is append-only: it only restricts, never permits.

## References

- Raised by the security pass on PR #447 (#446).
- Related to ADR 0064 (instruction-file locations) and ADR 0081 (standing repair authority).
