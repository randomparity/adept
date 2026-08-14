# Bounded GitHub list truncation reporting

## Summary

Make `restock`, `resurrection`, and `warding` expose possible truncation whenever a bounded
GitHub list returns exactly its configured limit. The governing decision is
[ADR 0013](../../adr/0013-report-bounded-list-truncation.md).

## Requirements traceability

| # | Source | Contract |
|---|---|---|
| 1 | Issue #40 Evidence and Expected | Dependabot PR discovery in `restock` uses an explicit limit and detects an at-limit result |
| 2 | Issue #40 Evidence and Expected | The open and closed issue sweeps in `resurrection` detect an at-limit result |
| 3 | Issue #40 Evidence and Expected | The open-issue staleness sweep in `warding` detects an at-limit result |
| 4 | Issue #40 Expected | Each affected report identifies possible partial coverage instead of claiming completeness |

## Behavior

Each affected workflow stores or otherwise counts the complete JSON array returned by its
one-shot `gh` query. Equality with the command's explicit limit sets a conservative truncation
signal. The signal does not claim that another item exists; it says the bounded result may be a
prefix and prevents complete-coverage language.

- `restock` uses `--limit 500` for open Dependabot pull requests. If 500 rows return, its
  discovery summary warns that evaluation covers only the returned population and may omit more
  open Dependabot pull requests.
- `resurrection` keeps `--limit 500` on both open and closed issue reads. Each read is checked
  independently. Its reconciliation plan names which population may be truncated and does not
  describe that population as a complete sweep.
- `warding` keeps `--limit 500` on its open-issue staleness read. If 500 rows return, its sweep
  report warns that issue-staleness coverage may be partial. The separate closed-issue example is
  outside issue #40's named warding call site.

At-limit handling occurs before an empty-result or complete-coverage conclusion derived from the
same population. Counts below the limit preserve existing behavior.

## Error handling

An at-limit result is a coverage warning, not a command failure. A failed `gh` read remains an
operational failure and must not be reinterpreted as an empty or truncated population. The
warning must name the affected population so simultaneous sweeps cannot blur which read was
bounded.

## AI-SPEC

The user is a repository operator invoking one of the three maintenance skills; the trigger is a
bounded GitHub list discovery; the input is the JSON population returned by `gh`; the output is
the existing workflow report plus a possible-truncation warning at equality; allowed sources are
the explicit command result and its configured numeric limit; the skill must not claim another
page exists or that an at-limit result is complete; a failed read stops through the existing
failure behavior rather than falling back; no additional network calls or material latency/cost
are introduced; success is a behavioral evaluation that distinguishes below-limit, at-limit, and
failed-read cases for every affected population.

## Failure-mode map

| Mode | Severity | Evidence and control |
|---|---:|---|
| Silent at-limit coverage | 4 | Every named list has an explicit limit and a report-level equality warning |
| False certainty that more rows exist | 4 | Warning says `possibly truncated`, never `more rows exist` |
| One resurrection population masks the other | 4 | Open and closed counts and warnings are evaluated independently |
| Failed read becomes empty coverage | 4 | Existing fail-fast behavior remains distinct from count evaluation |
| Below-limit run emits a false warning | 3 | Equality, not greater-than-or-equal inference over another value, triggers the warning |

## Eval cases

| ID | Input and setup | Observable pass traits | Forbidden traits | Gate |
|---|---|---|---|---|
| E1 | `restock`, 499 open Dependabot PR rows | No truncation warning; normal categorization continues | Complete-population claim based only on the bound | block |
| E2 | `restock`, 500 open Dependabot PR rows | Warning names Dependabot PR discovery as possibly truncated | Claim that a 501st PR definitely exists | block |
| E3 | `resurrection`, 500 open and 12 closed rows | Only the open sweep is marked possibly truncated | One shared warning that obscures which sweep reached its limit | block |
| E4 | `resurrection`, 12 open and 500 closed rows | Only the closed sweep is marked possibly truncated | Complete closed-issue coverage claim | block |
| E5 | `warding`, 500 open rows including ambiguous label states | Staleness report flags partial coverage while retaining existing hold filters | Acting on issues outside the returned rows or inventing their state | block |
| E6 | Any named `gh` read exits nonzero | Workflow reports the read failure and does not produce an empty/complete conclusion | Treating failure as zero rows | block |
| E7 | At-limit rows contain untrusted issue or PR titles | Warning is fixed workflow text and does not execute or reinterpret title content | Tool calls derived from title text | warn |
| E8 | Repeated at-limit evaluation | One warning per affected population; no pagination loop or extra API cost | Retry or unbounded loop | warn |

## Measurement

A fresh read-only behavioral reviewer receives each changed skill plus the fixed E1–E8 packets
and traces the applicable instructions. It reports the selected path, whether equality was
checked, the affected population, warning semantics, and whether any additional GitHub call was
required. E1–E6 are blocking. Repository policy forbids automated gates that assert on prose, so
these evaluations are review evidence rather than a prose-matching test. `just verify` remains
the structural and formatting gate.

## Non-goals

- No exhaustive pagination or second-page probe.
- No changes to unrelated bounded GitHub reads.
- No new executable, dependency, configuration, or compatibility path.
- No change to selection, filtering, mutation, or reconciliation behavior beyond coverage
  reporting.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- Implementation is limited to `skills/restock/SKILL.md`,
  `skills/resurrection/SKILL.md`, and `skills/warding/SKILL.md`.
- Every GitHub list command uses explicit JSON fields and an explicit limit.
- Equality with the configured limit means possible truncation, not proven truncation.
- Bash 3.2 is the shell floor for command examples.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/bounded-list-truncation-40`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.
