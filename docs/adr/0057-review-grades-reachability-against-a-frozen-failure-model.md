# 0057 — Review grades reachability against a frozen failure model

## Status

Accepted (2026-09-09)

## Context

`$gauntlet` is instructed to break confidence in a target, and its document attack list names
empty, large, malformed, concurrent, and hostile cases as things to look for. Nothing tells it
which of those matter for the change in front of it. A design under `$spellcraft` states what
can go wrong only when the change is security-relevant — the threat model at
`skills/spellcraft/SKILL.md` — so an ordinary correctness or robustness change reaches review
with no stated actors, deployments, or accepted failures at all. The reviewer supplies its own,
and it supplies the worst case: every deployment, every actor, every input.

The observed shape is a spec that says "all" and a review that answers with an open series of
"what about this?" findings, one per instance the word would have to cover. `$trial-loop`'s
`rejected-with-evidence` disposition already names the way out — a finding that "presumes a
requirement or threat model nothing claims" — but on a non-security change no such model was
ever written, so the author refutes each instance from scratch. The reviewer generates
against an unbounded quantifier for free; the author pays per finding.

ADRs 0049 through 0053 bounded what a pass costs and when a loop stops. None of them bounds
what a pass reports, and the finding bar's per-finding questions cannot: they raise the quality
of each finding without touching the count.

## Decision

**1. Every spec carries a `Failure model` section, on both lanes.** Four entries: actors and
deployments, invariants and assets at stake, accepted failure classes each with its reason, and
classes covered elsewhere with their owner. In the light lane it is a third-level subsection of
`Scope` and counts against the caps; in the full lane it is its own section. It is sized to
the change. The security threat model becomes its security-specific extension and keeps its
four items.

**2. The model is a review target during the design review and frozen after it.** The design
reviewer challenges each entry once on the merits. After the review closes, `$quest` names the
section to the branch reviewer on a `failure model:` line of the review block, carried by a
new optional `$trial-loop` input. The line is not a ninth charter field: it carries no scope
authority and is not hashed.

**3. `$gauntlet` grades reachability against the model.** A trigger inside a named
deployment or against a named invariant is a finding on ordinary terms. A class the model
accepts is dropped and disclosed as a suppression, on the same terms as governing-ADR
re-litigation, with the entry named. A trigger outside the named deployments is at most a
`medium` note stating the gap, reported once. A defensible case that the model itself is wrong
is one finding against the entry, with evidence, at whatever severity the evidence supports.

**4. A universal claim is one finding.** "All", "every", "any", "never", "always", or an
unbounded "must" with no stated closure earns exactly one finding against the quantifier,
whose remedy is to bound or ground it. Its instances are not enumerated. `$spellcraft`'s
self-review bounds every such word before the reviewer sees it.

**5. `$trial-loop` cites the model to reject in one line.** A finding the frozen model accepts
or places outside the named deployments takes `rejected-with-evidence` by citing the entry. A
defensible finding against an entry takes `blocked`, because changing a frozen model is a
design decision. Adding an accepted class mid-cycle to retire a finding is the exclusion-gaming
the charter section already forbids.

## Consequences

- A reviewer has a stated referent for "does this matter here", written by the author before
  the review and challenged once. Instance enumeration against an accepted class or an unnamed
  deployment stops being reportable as findings.
- The author owes one line per rejected finding instead of a fresh refutation each, which is
  the cheap re-disposition the iteration cap depends on.
- Every spec grows by a few lines, including a light spec inside its 60-line cap. On a small
  change that is one operator, one invariant, and one or two accepted classes.
- A wrong model is now a way to under-review: an accepted class nobody should have accepted
  suppresses real findings. Three things hold that: the design review attacks each entry, the
  branch reviewer may attack an entry with evidence at blocking severity, and every acceptance
  is disclosed in `suppressions` and surfaced on `approve`.
- `suppressions` entries now carry either `adr` or `failure_model`. Readers that assumed every
  entry names an ADR see an entry that names something else; the `suppressed_count` contract is
  unchanged.
- A `no-spec` run passes `none` and reviews exactly as before. Standalone `$gauntlet` on a
  document with no model gets only the quantifier rule.

## Considered & rejected

- **Add the failure model as a ninth charter field.** verified: at `9d866fc`,
  `rg --no-config -n 'eight' skills/quest/SKILL.md skills/trial-loop/SKILL.md
  skills/spellcraft/SKILL.md` matches ten lines stating the eight-field contract, and
  `skills/spellcraft/SKILL.md` freezes it before design with "Use a complete caller-supplied
  charter unchanged" — the charter is fixed at `$quest`'s scope checkpoint, before the code is
  read, so a field that needs the codebase cannot be written there. judgment: the model also
  needs to be attackable, and charter fields are authority, not claims.
- **Cap the number of findings per pass.** judgment: a count cap drops the last real finding
  as readily as the last nitpick. The CriticGPT result (McAleese et al., 2024) is that catches
  and nitpicks rise together with claim count and the only lever that separated them was a
  learned precision term; a raw count is not that lever.
- **Keep the threat model conditional and rely on `rejected-with-evidence` (do nothing).**
  verified: at `9d866fc`, `skills/spellcraft/SKILL.md` gates the threat model on the `$quest`
  step 6 security triggers, and `skills/trial-loop/SKILL.md` names "a threat model nothing
  claims" as rejection evidence — a referent that, on a non-security change, nothing writes.
- **Let the reviewer derive the model itself.** judgment: a model the reviewer writes is graded
  against a premise the author never saw and cannot cite, and it is rewritten on every pass.
  The value of the section is that it is authored once, before review, and challenged once.
- **Treat an outside-the-model trigger as a suppression rather than a note.** judgment: a
  suppression is visible only by count and entry, while a note keeps the gap stated in the
  findings where the author decides whether the model was incomplete. The note costs one
  disposition; the gap it names is the information.
