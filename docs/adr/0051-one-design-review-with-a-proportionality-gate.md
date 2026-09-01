# 0051 — The design phase is one review, one audit, and a proportionality gate

## Status

Accepted (2026-09-01)

Refines [0050](0050-risk-routes-review-depth.md), whose rule 1 bound the depth routing to
"`$spellcraft`'s ADR, spec, and plan reviews — routed per target". There is now one design
target, so there is one route. Everything else in 0050 stands, and the two-pass budget
[0049](0049-review-verdicts-gate-on-blocking-severity.md) set is untouched.

## Context

`$spellcraft` ran a separate `$trial-loop` per design artifact: one per companion ADR, one
for the spec, one for the plan. Each was a fresh charter, so each drew a full
`iteration_budget`, and `$oathbind` audited afterwards — observed twice, because an accepted
audit finding sent the design back through its review and then through a new audit.

Every one of those loops was individually correct. The cost was structural: the design phase
bought three-to-five budgets for one change, and no report stated the total. #283 made the
total sayable by carrying `prior_rounds` across loops, which named the cost without changing
it. The observed run still reached 13 review rounds and 1,469 lines of design for an
implementation capped at roughly 150–250 lines, with zero code written.

#284 named the other half. `$spellcraft` states that a design's *length* scales to the size
of the change, and nothing measured it. `$oathbind` does check proportionality, but against
a smaller viable alternative — scope against scope — and after the design is complete, so it
can grade the spend and never prevent it. It returned "proportionate" both times, correctly,
on its own axis.

## Decision

**1. One review over the whole design set.** The ADRs, the spec, and the plan are one change
reviewed under one charter, at one budget, producing one report. `$trial-loop` runs in
file-list mode over every artifact the design produced, detected with the same git predicates
the ADR step used, widened to `docs/workflow/specs/` and `docs/workflow/plans/`. A set
holding no spec and no plan is a lost-artifact resume and stops as blocked; an ADR-free set
is the common case and reviews identically, which removes the ADR-specific skip that
previously had to be evaluated correctly at the call site.

**2. The review runs after the plan, not between the artifacts.** The plan is therefore
derived from a spec no adversarial pass has seen. That is the cost of the collapse and it is
paid deliberately: the spec self-review and the plan-against-spec self-review, both already
in the skill, are what stand in the gap, and the combined focus requires the reviewer to
check the plan back against the spec in the same set so an inherited defect is one finding
rather than two.

**3. The plan records an expected implementation size, and the review measures the design
against it.** The plan header carries `Expected implementation size: <low>–<high> changed
lines (<S|M|L>)`, derived from the file map and task list it has just written — a
by-product, not new analysis, with the band taken from the `$divination` complexity verdict
where the caller supplied one. Before dispatching, `$spellcraft` measures the design set with
`wc -l`, divides by the range's high end, and echoes both numbers and the ratio in its audit
line. Above 3× is a blocking finding; 2× to 3× is a note. The only remedy is cutting the
design — never more text defending its length, and never a widened estimate.

**4. The orchestrator measures and the reviewer judges.** The ratio is computed at the call
site and passed into the focus as a number. A reviewer asked to both measure and judge does
neither reproducibly, and the audit line leaves the measurement inspectable in the transcript
— which is the repo's only verification for a prose contract.

**5. One `$oathbind` audit, and it is not rerun.** The audit stays where it is, at `$quest`
step 4, immediately after the design review. What changes is the round trip: an accepted
remedy no longer sends the design back through its review and then a second audit. Every
remedy the audit can legitimately yield is a cut, a split, or a `SCOPE CHECKPOINT`, and a cut
cannot invalidate an audit that already approved the larger surface. So an accepted cut is
applied, the two self-review passes `$spellcraft` already defines are re-run over it to catch
a reference the cut stranded, and the run continues on the same report. A remedy that would
*widen* the surface was never responsive; it is a checkpoint. The two triggers `$oathbind`
itself names stay — a verified ownership change, and an artifact changing for a reason the
report does not account for — because neither is the round trip.

## Consequences

The design phase's floor drops from three budgets to one. On the two-pass default that is
four reviewer dispatches saved per design that carries an ADR, and the saving is largest
exactly where the old shape was most expensive.

A spec defect now reaches the plan before any adversarial pass sees it. When the review
finds one, the fix is two edits rather than one, and both live inside the same loop's budget.
That is the trade rule 2 accepts; the self-reviews are what keep it from being routine.

The proportionality gate can block a design that is genuinely long for good reason. The
escape is the estimate itself, which is why the focus makes an unsupported range a finding in
its own right: the honest number is the one the plan's file map yields, and inflating it to
move the ratio defeats the control rather than satisfying it.

3× is a threshold, not a measurement. It is set from the observed failure — roughly 7× — and
from this repo's own norm that a 57-line record can settle the shape of a command. A design
sitting at 2.9× draws no finding and may still be too long; the gate catches the case nobody
was catching, not every case.

`$spellcraft` no longer has an ADR-review step whose skip predicate could be mis-evaluated,
and no longer has three routing decisions where the reference expects one. The cumulative
round carry survives intact and gets simpler: one design-phase figure, handed to `$quest` for
the branch review.

## Considered & rejected

- **Keep the per-artifact loops and add an aggregate ceiling.** verified: #283 already
  carried the total across charters and shipped in 2fd991b; the run that motivated this
  record happened with the total visible. Reporting named the cost, and the operator still
  had to cap it by hand — the budgets themselves are what multiply.
- **Review the set once, but before writing the plan.** judgment: the plan is where the
  design's length actually accumulates (1,043 of the observed 1,469 lines), so a review
  placed before it cannot see the artifact the proportionality gate exists to measure.
- **Enforce proportionality with absolute line ceilings per complexity band.** verified:
  `wc -l docs/workflow/plans/*` over this repo's 43 plans gives a median of 218 lines and a
  range of 32 to 1,200 — a 37× spread, because the changes they describe span a comparable
  range. A ceiling low enough to catch the observed 1,469-line set would fire on the
  legitimate 1,200-line one, and a ceiling above that catches nothing. A ratio has a
  denominator; a ceiling does not.
- **Have `$oathbind` carry the proportionality check.** verified: `skills/oathbind/SKILL.md`
  audits authority, is read-only, and runs after design completion, so it can grade the spend
  and not prevent it — which is exactly the failure #284 recorded, twice.
- **Fold the audit into the review loop as a second reviewer.** judgment: the loop fixes
  findings between passes and the audit is defined as one independent pass over an unchanged
  input set; putting it inside a loop that mutates its target between iterations contradicts
  its own contract for no saving, since it is one dispatch either way.
- **Move the `$oathbind` invocation from `$quest` into `$spellcraft`.** verified: `$quest`
  step 4 owns the `.agent/.gitignore` query, the ignored report path, and the dispatch;
  duplicating that in `$spellcraft` while `$quest` still calls it is how a second audit gets
  created rather than removed.
- **Do nothing.** verified: #288 and #284 record the outcome — 13 review rounds and a
  1,469-line design for a ~150–250 line change, with every control in the pipeline reporting
  success.
