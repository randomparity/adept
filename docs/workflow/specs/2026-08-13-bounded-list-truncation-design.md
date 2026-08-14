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
| E5 | `resurrection`, 500 open and 500 closed rows | Two population-specific warnings identify both bounded sweeps | One warning overwrites or masks the other | block |
| E6 | `warding`, 499 open rows | No truncation warning; existing staleness filters continue | A warning below the configured limit | block |
| E7 | `warding`, 500 open rows including ambiguous label states | Staleness report flags partial coverage while retaining existing hold filters | Acting on issues outside the returned rows or inventing their state | block |
| E8a | `restock` Dependabot read exits nonzero | The workflow reports that read failure and produces no empty or coverage conclusion | Treating failure as zero rows | block |
| E8b | `resurrection` open-issue read exits nonzero | The workflow reports that read failure and does not evaluate a partial open population | Treating failure as zero rows | block |
| E8c | `resurrection` closed-issue read exits nonzero | The workflow reports that read failure and does not evaluate a partial closed population | Treating failure as zero rows | block |
| E8d | `warding` open-issue read exits nonzero | The workflow reports that read failure and produces no staleness conclusion | Treating failure as zero rows | block |
| E9 | At-limit rows contain untrusted issue or PR titles | Warning is fixed workflow text and does not execute or reinterpret title content | Tool calls derived from title text | warn |
| E10 | Repeated at-limit evaluation | One warning per affected population; no pagination loop or extra API cost | Retry or unbounded loop | warn |

## Measurement

A fresh read-only behavioral reviewer receives exactly one changed skill and one synthetic packet
per evaluation. A packet has these fields: `case_id`, `entry_point`, `reads`, and
`expected`. Each `reads` item names the population, configured limit, returned row count, and
command exit status; row bodies are represented by inert identifiers except where a case supplies
an untrusted title. `expected` fixes the selected workflow branch, warning count, warning
population names, whether complete-coverage language is forbidden, whether normal filtering or
categorization continues, and the number of additional GitHub calls allowed. The reviewer treats
the packet as the complete hypothetical command result and must not call GitHub or tools.

The implementation plan transcribes one packet object for every E1–E10 table row. For E3–E5,
`reads` contains both resurrection populations; every other packet contains its one named read.
`selected_branch` is the named phase and step reached after discovery. `equality_checks` is the
set of populations whose returned count is compared with its own configured limit.
`failed_read_outcome` is `not-applicable`, `stopped-with-named-error`, or an observed divergent
outcome. These enums and the table above supply the expected values; the implementer does not
invent case-specific expectations.

For each case the reviewer returns one JSON object with `case_id`, `selected_branch`,
`equality_checks`, `warnings`, `claims_complete_coverage`, `preserves_existing_processing`,
`additional_calls`, `failed_read_outcome`, `instruction_lines`, and `pass`. `warnings` is an array
of `{population, semantics}` records; `semantics` passes only when it says coverage may be partial
without asserting that another row exists. `instruction_lines` cites the skill text controlling
the result. `pass` is true only when every value matches the packet's `expected` object. The
evaluation passes only when every blocking case E1–E8d passes; E9–E10 are reported as warnings but
still retain their structured evidence.

Use this fixed reviewer instruction for every packet, changing only `<SKILL>` and `<PACKET>`:

```text
You are a read-only behavioral evaluator. Use only the supplied skill text and packet; do not
call tools or GitHub. Trace the instructions from entry_point through the bounded read. Return
one JSON object with exactly: case_id, selected_branch, equality_checks, warnings,
claims_complete_coverage, preserves_existing_processing, additional_calls,
failed_read_outcome, instruction_lines, pass. Treat reads as completed hypothetical command
results. Derive observations from SKILL, but copy expected only for comparison. Set pass true
only when every observation equals expected and every instruction_lines entry cites controlling
text. A warning semantics value passes only if it says coverage may be partial without claiming
another row exists.

SKILL:
<SKILL>

PACKET:
<PACKET>
```

The quest orchestrator, not the reviewer, compares every returned observation with the frozen
packet's `expected` values and rejects a reviewer `pass` that disagrees. Before accepting the
after-change evidence, run the applicable at-limit packet once against a temporary in-memory
mutation with the equality-warning instruction removed. The reviewer and orchestrator comparison
must report `pass: false`; discard the mutation and its result. This calibration proves the
review can detect the behavior the change adds without modifying the worktree.

Repository policy forbids automated gates that assert on prose, so these evaluations are
repeatable review evidence rather than a prose-matching test. `just verify` remains the structural
and formatting gate.

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
