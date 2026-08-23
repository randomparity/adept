# 0013 — Report bounded list truncation

## Status

Accepted (2026-08-13)

## Context

Several skills intentionally bound GitHub list reads, but a result at the bound is
indistinguishable from a complete population unless the workflow says so. Silent partial
coverage is especially misleading in maintenance workflows whose summary implies a repository-
wide sweep. Existing `sort-board` and `bards-tale` contracts already treat an at-limit count as
possible truncation.

## Decision

Every affected one-shot GitHub list read has an explicit limit. When the returned count equals
that limit, the skill must report possible truncation and must not characterize the result as a
complete population. Apply this contract to Dependabot PR discovery in `restock`, both issue
sweeps in `resurrection`, and the open-issue staleness sweep in `warding`.

The signal is conservative: equality means "possibly truncated," not proof that another page
exists. Each workflow carries the signal into the report or terminal summary that describes the
bounded population.

## Consequences

Large repositories receive an honest coverage warning instead of a false complete result. A
population whose size exactly equals the limit can produce a conservative warning even when no
additional item exists. The skills retain simple one-shot reads and do not add pagination state.

## Considered & rejected

**Paginate every affected list exhaustively.** Rejected because issue #40 permits detection,
existing peer skills use that contract, and pagination would add control flow without changing
the workflows' intended bounded operating model.

**Increase the limits without detecting equality.** Rejected because every finite limit can be
reached, leaving the same silent-coverage defect at a different threshold.

**Do nothing.** Rejected because the affected workflows continue reporting bounded prefixes as
complete repository populations.
