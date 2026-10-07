# 0061 Scoped ownership is a design choice

## Status

Accepted (2026-09-12)

## Context

Feature design may extend current modules even when doing so duplicates policy or leaves
responsibility in the wrong owner. Existing scope and audit stages protect authority, but
their wording does not require a bounded comparison with a coherent ownership change.

## Decision

Before scope freeze, inspect affected responsibilities, direct callers, and shared
dependencies. When evidence shows duplicate policy, misplaced responsibility, or avoidable
indirection, compare a clean extension with reuse, move, consolidation, replacement, or
deletion. Choose the simpler criterion-linked coherent result. Keep a clean extension when
it is already coherent. Carry selected owners, migrations, removals, retained compatibility
reasons, and protected contracts in existing scope/design/audit content. An unapproved
contract change or unrelated cleanup still returns to the existing scope checkpoint.

## Consequences

File layout is evidence rather than scope authority. A justified ownership move may touch
more files than extension; caller migration and obsolete-path removal become part of that
choice. No extra phase or document is required. Execution/review enforcement and unattended
authority remain separate decisions.

## Considered & rejected

- **Always extend existing structure.** judgment: it preserves duplicated policy and misplaced
  ownership in the motivating case.
- **Always consolidate when more than one owner exists.** judgment: a clean extension or a
  compatibility contract may justify the current separation.
- **Add a mandatory architecture phase.** judgment: the bounded comparison fits the existing
  scope, design, and audit stages without another checkpoint for every feature.
