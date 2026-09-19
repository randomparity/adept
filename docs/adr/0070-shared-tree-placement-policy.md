# 0070 — Consume shared-tree observations in one placement policy

## Status

Accepted (2026-09-18)

## Context

Attunement records sibling counts and pre-existing dirty state without attributing either.
Issues #416 and #415 require the consumers to act on undisclosed sharing, while linked
worktrees and temporary verification siblings must not cause recursive isolation.

## Decision

Forge's Pocket dimension owns the ordered placement policy; quest consults it before its
first workspace mutation. Dirty or unknown dirty/topology state stops mutation. A clean,
assigned external linked worktree is reused regardless of sibling count. A clean primary
checkout isolates when concurrency is disclosed, isolation is required, or siblings are
nonzero/unknown. Only clean primary, zero siblings, no isolation requirement or disclosure
permits the existing in-place feature-branch/preference path. Counts never identify agents.

Preserve dispatch assignments and branch authority. Failed required isolation stops rather
than falling back to the original checkout. Attunement keeps recording; no competing probe ships.

## Consequences

Quest depends on forge's policy subsection, not forge execution. A tooling sibling can require
primary-checkout isolation but cannot force a second worktree from an existing isolated one.
Unknown dirty state can pause work. Observations are not locks against later unseen mutations.

## Considered & rejected

- **Do nothing.** verified: #416's live evidence and quest's Worktree placement condition at
  base d75a99e depend on instructions/disclosure, leaving the new observation unconsumed.
- **Duplicate the policy in each skill.** judgment: two tables can drift on unknowns and reuse.
- **Add a policy reference or executable.** judgment: the existing placement owner can hold the
  short policy and a link serves its one other consumer without a new supporting artifact.
- **Treat siblings as agents or always isolate linked checkouts.** judgment: attribution is
  unavailable, and repeatedly isolating an already-isolated checkout adds no protection.
