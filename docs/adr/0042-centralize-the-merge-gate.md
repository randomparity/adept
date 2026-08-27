# 0042 Centralize the merge gate in a reference

## Status

Accepted (2026-08-27)

## Context

ADR 0035 defines one four-part commit-bound merge gate. Issue #249 implemented it by
copying the same normative block into `campaign`, `quest`, and `return-to-town`. Those
skills must stay semantically identical, but anatomy rule 4 forbids a prose-comparison
gate, so no automated check can detect wording drift between the copies.

The repository already uses `references/` for standards consulted by several skills, and
`scripts/check-skill-shape.sh` structurally verifies that relative links into that directory
resolve.

## Decision

The complete merge gate lives once in `references/merge-gate.md`. `campaign`, `quest`, and
`return-to-town` link that reference at the point where each previously carried the inline
gate. The reference preserves ADR 0035's normative behavior, including its issue-backed
scope and the restock PR-only exception.

The structural link check remains the only automated validation. Nothing asserts on the
reference's prose.

## Consequences

- A gate change has one normative edit location, so the three consumers cannot drift by
  independently changing copied prose.
- Each consumer adds one indirection at the merge boundary and must read the reference
  before executing the gate.
- A missing or renamed reference fails `just shape-check`; semantically incorrect prose
  remains a reading and review concern.

## Considered & rejected

- **Keep three inline copies.** judgment: immediate locality does not outweigh a
  three-way normative drift surface that anatomy rule 4 deliberately leaves unpoliced.
- **Generate the three copies from one source.** judgment: generated prose adds a build
  step and derived artifacts when the existing reference mechanism already supplies one
  source with structurally checked links.
- **Add a prose-equivalence test.** verified: repository anatomy rule 4 in `CLAUDE.md`
  prohibits gates that assert on prose.
