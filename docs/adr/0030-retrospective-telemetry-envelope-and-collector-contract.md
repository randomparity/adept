# 0030 — Retrospective telemetry envelope and collector contract

## Status

Accepted (2026-08-21)

## Context

The retrospective enhancement in #105 makes `$bards-tale` emit a structured telemetry
document at `docs/retro/<date>-<slug>.json` that a later run reads back to compute deltas.
A durable artifact that a later run parses is a contract, and this repository records
contracts as ADRs. Without one settled first, the collector and the five later metric
entries each renegotiate the document's shape — and `docs/adr/` is append-only, so each
renegotiation would demand a superseding record.

Two further decisions belong in the record because a later reader would otherwise meet
them as apparent oversights. First, the collector reaches GitHub through `gh` directly,
although #15 put tracker reads behind the quest-log tracker contract. Second,
`skills/quest-log/SKILL.md` requires a GraphQL connection with an explicit `hasNextPage`
signal for comment collection, while `skills/bards-tale/SKILL.md` forbids `gh api graphql`
outright in its read-only contract; the two must be reconciled on paper even if no code
moves.

## Decision

### Document shape

The telemetry document is a single JSON object at `docs/retro/<date>-<slug>.json`, where
`<slug>` is the filesystem-safe selector rendering the skill already defines. It is a
point-in-time snapshot: a later run over the same date and selector overwrites it, and the
newest document supersedes. The document carries no prose; the human-readable report
remains the skill's separate Markdown artifact.

### Tri-state encoding

Every metric in the document is in exactly one of three states, and the state survives a
JSON round trip:

- a **value**, when the source data is present, encoded at the metric's position as its
  native JSON scalar;
- **`unknown`**, when the source annotation is genuinely absent (a data gap), encoded as
  the literal string `"unknown"`, optionally carrying a reason in the skill's existing
  parenthesized form (`"unknown(no-closer)"`, `"unknown(ambiguous)"`);
- **`error`**, when a `gh` read failed (rate limit, 5xx, network — a fetch failure),
  encoded as the literal string `"error"`.

An `error` is never folded into `unknown`, and neither is ever folded into `null`. No
field in the document ever carries JSON `null`: absence of data is always one of the two
sentinels with its reason, never a null that a careless consumer collapses into a default.
A consumer distinguishes the states by exact string equality against `"unknown"` and
`"error"`; genuine metric values never equal those literals, because values are durations,
counts, ordinals, or identifiers.

### schema_version and the bump rule

The document carries a top-level `schema_version` string of the form `"M.m"`, starting at
`"1.0"`. **Adding an optional per-metric field, a new metric entry, or a new report
section is a minor bump (`m` + 1) and requires no new ADR** — this record is deliberately
narrow so that the five later metric entries land as minor bumps instead of
supersessions. Removing, renaming, re-typing, or re-nesting any existing field, or
changing the meaning of a sentinel, is a major bump (`M` + 1) and requires a new record
that supersedes this one with a banner here. A consumer that meets a major version it
does not know rejects the document rather than guessing.

### Top-level envelope

The document's top-level fields are:

- `schema_version` — as above;
- `selector` — the selector exactly as the operator passed it;
- `mode` — `"label-set"` or `"date-range"`, the skill's two selector modes;
- `generated_at` — the run's completion time, ISO 8601 UTC;
- `truncated` — boolean. True whenever the selected population's size equals the search
  limit, carrying [ADR 0013](0013-report-bounded-list-truncation.md)'s rule into the
  durable artifact: the signal is conservative (equality means "possibly truncated"), and
  a consumer must never treat the population as complete while it is true;
- `population` — the selected population as an object: `count`, and `issues`, the ordered
  array of selected issue numbers.

Per-metric fields live beside these under a `metrics` object and are added under the
minor-bump rule; this record fixes the envelope, not the metrics.

### Collector stdout contract

After writing the document, the collector prints exactly one JSON status line to stdout,
as the last line of its output:

```json
{"report":"docs/retro/2026-08-21-status-ready.json","schema_version":"1.0","generated_at":"2026-08-21T12:00:00Z","issues":42,"truncated":false}
```

The keys are `report` (the written path), `schema_version`, `generated_at`, `issues`
(population count), and `truncated`. The human-readable in-session summary the skill
already prints precedes this line; consumers that want the machine result parse only the
final line. A run that fails to write the document exits non-zero and prints no status
line, so a missing or unparseable last line is itself the failure signal.

### The collector reads through `gh`, not the tracker contract

The collector's GitHub reads go through `gh` directly and stay there permanently; the
quest-log tracker contract is not adopted for them. Measured against
`skills/quest-log/assets/profiles/github.sh`, no tracker operation supplies what this
document needs: `view` returns a normalized issue projection with no event stream and no
label timestamps; `label-history` returns only the most recent application timestamp of a
single label, discarding the ordered transition history the cycle-time family is built
on; `search` exposes predicates only; `comment-list` returns bare bodies. The metrics
need the ordered `labeled` / `closed` / `commented` event stream from the REST timeline
endpoint, which only a direct `gh api` read supplies. The tracker contract serves
write-path portability across trackers; retrospective telemetry is inherently
GitHub-shaped, because GitHub is where the telemetry lives. The tracker contract's
measured shortfalls remain routed to #18 and #20 by a human; this record does not fix
them.

### Comment-pagination completeness

The strict GraphQL pagination recipe in `skills/quest-log/SKILL.md` binds **authority
adoption**: a consumer that verifies a `WORK:DIVINATION` assessment and changes branches
on it must prove its comment read was complete. `$bards-tale` consumes `WORK:*`
annotations as advisory telemetry — it never changes branches on them — so the recipe
does not bind the collector, and the `gh api graphql` ban in the skill's read-only
contract stands. `skills/bards-tale/SKILL.md` is left untouched by this record.

The residual hazard is recorded rather than fixed: the collector's bounded comment
projections carry no completeness signal, so an annotation posted past the projection
bound presents as genuinely absent and lands in the report's data-gap section. That is an
honest data gap under the tri-state encoding, never a fabricated value or a zero fill. A
future completeness signal — for instance, cross-checking the projected comment count
against the exhaustive timeline capture the cycle-time metric already fetches — is an
additive per-issue field under the minor-bump rule, and routes with the tracker shortfalls
to #18 and #20 for human disposition.

## Consequences

The five later metric entries extend the document under the minor-bump clause without
touching this record, and `docs/adr/` absorbs them append-only. Consumers gain a stable
envelope to parse and a null-free invariant that keeps absence distinguishable from every
default a JSON decoder might supply. The stdout line gives callers a machine result
without parsing prose, at the cost of one more contract the collector must honor. Staying
on `gh` couples retrospective telemetry to GitHub's availability and REST shapes —
accepted, because the source telemetry is GitHub-native and a tracker-portable retro would
have nothing portable to read. Leaving `skills/bards-tale/SKILL.md` untouched means the
silent-truncation hazard above remains until a later minor bump carries the completeness
field; it is recorded here so the gap is a known decision, not an oversight.

## Considered & rejected

**Encode `unknown`/`error` as JSON `null`.** Rejected because null collapses the tri-state
to two states — a null is indistinguishable from a missing key or an omitted field after a
round trip, which is exactly the defect this encoding exists to prevent.

**Encode every metric as a `{"state": ..., "value": ...}` object.** Rejected because two
sentinel literals at the metric's position carry the same information with no nesting, and
they match the conventions the skill's computation rules already use
(`"unknown(no-closer)"`, `cycle="error"`). Object-wrapping every field would renegotiate
the shape more than the problem requires.

**Adopt the quest-log GraphQL pagination recipe in `$bards-tale`.** Rejected because the
recipe exists to protect authority adoption that changes branches, and no bards-tale
consumer does that. Lifting the `gh api graphql` ban into a hard-constrained read-only
skill to serve advisory telemetry weakens the constraint for nothing it protects.

**Migrate the collector onto the tracker contract now, or declare it temporary.**
Rejected on the measured gaps above: no tracker operation returns an ordered event stream
or label-transition timestamps, and re-deriving them from `view` plus `label-history`
loses ordering and intermediate transitions. The dependency is permanent for telemetry
reads; the tracker shortfalls route to #18 and #20.

**Leave the document shape to each metric entry.** Rejected because five later entries
would each renegotiate the envelope, and an append-only record directory cannot absorb
five supersessions of one contract.

## Provenance

Issue #106 (part of epic #105) establishes the contract gap and the deliberately narrow
scope. The tri-state rule is the skill's existing never-zero-fill behavior; the
truncation flag carries ADR 0013; the tracker-gap measurements were verified against
`skills/quest-log/assets/profiles/github.sh`. The comment-pagination resolution follows
from `skills/quest-log/SKILL.md` scoping the strict recipe to authority adoption.
