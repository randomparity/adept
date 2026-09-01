# 0050 — The divination verdict routes review depth, and a split verdict gates dispatch

## Status

Accepted (2026-08-31)

Builds on [0049](0049-review-verdicts-gate-on-blocking-severity.md), which set the
blocking line and the two-pass budget. That record governs what a pass costs and when
a loop stops; this one governs whether a loop runs at all. Nothing in 0049 changes.

## Context

`$divination` assesses blast radius, change hazards, complexity, and a decompose
verdict, and persists them as an authenticated `WORK:DIVINATION` annotation. Nothing
consumed the result.

`$quest` read the block and adopted it as an explicitly *advisory* assessment, with no
branch, gate, or stop condition keyed on any of its four fields. `$campaign` — the one
actor that could act on a `split`, because it owns the queue and can turn one row into
several — never read the block at all: its triage returned
`close-candidate | close-not-planned | fix` with a subtype whose only documented
consequence was model selection, and it had no output slot for "should this be split".
So an issue bundling several heterogeneous deliverables entered a single quest with no
decomposition checkpoint, and the cost of that only became visible after the design was
finished.

The observed run in #282: a campaign row whose issue carried five heterogeneous
deliverables — a shell fixture, a Makefile target, a Python refactor, a docs section,
and Rust comment markers — was triaged `fix: non-trivial` and dispatched as one quest.
Roughly two hours later it had a complete, twice-audited design and zero
implementation, and the operator capped it by hand. Nothing in the pipeline had raised
decomposition as a question, and nothing had asked whether a change of that shape
needed the full design-and-review depth before a line of it existed.

The second half of the gap is the same shape. Review depth was uniform: every
non-trivial change got `$spellcraft`'s three design reviews, an `$oathbind` audit, and
an iterating branch loop, whether it carried a migration or renamed a variable. 0049
made each pass cheaper to stop; it did not give the pipeline a way to decide that one
pass is enough.

## Decision

**1. The four assessment fields route review depth, through one rule with two
values.** [`references/review-depth.md`](../../references/review-depth.md) is the
normative rule: `single-pass` — one reviewer dispatch, findings dispositioned once —
or `iterating` — `$trial-loop` at its ordinary budget. `single-pass` requires change
hazards `none`, complexity `S`, decompose verdict `one PR`, and a target that is not
security-relevant. Everything else, including an absent, rejected, or underivable
assessment, routes `iterating`: absence routes toward depth, never away from it.

The rule binds every review the pipeline dispatches on its own initiative:
`$spellcraft`'s ADR, spec, and plan reviews — routed per target, on intent, since no diff
exists yet — and `$quest`'s branch review, re-derived there against the diff that by then
does exist. `$oathbind`'s scope audit is untouched: it audits authority, not code quality,
and its cost is one dispatch either way.

**2. `single-pass` is a different review shape, not a budget of 1.** `$trial-loop`'s
floor stays 2. A single pass never applies a fix and exits, because a blocking finding
refutes the routing rather than being fixed in place.

**3. A blocking finding on a single pass escalates.** The run records the escalation
and runs `$trial-loop` on the same target at its ordinary budget, starting at iteration
1. The single pass is not one of that run's iterations. This does not reopen 0049's
prohibition on risk buying passes: a blocking finding is a defect a reviewer found and
defended, not a forecast, and the escalation corrects a routing decision the evidence
refuted.

**4. Routing never routes upward and carries no scope authority.** A high-risk verdict
buys the ordinary budget and nothing more. Depth selection freezes no charter field,
changes no `status:` label, and assigns no `risk:` label; `WORK:DIVINATION` remains
advisory evidence on the quest-log skill's terms.

**5. `$campaign` triage returns a decomposition field, and `split` gates dispatch.**
Triage returns `decomposition: one-pr | split` alongside its verdict and subtype,
derived from the issue's `WORK:DIVINATION` block or from the same live evidence when
there is none, plus a proposed breakdown when `split`. Step 4's plan table — which the
operator already reads before anything is dispatched — carries the value, and a `split`
row is held from dispatch until the operator decides. That is the moment splitting is
still cheap.

**6. `$quest` never splits its own issue, and says so.** A lone quest holds one issue
number and creates one branch for it, so it has no route to act on `split`. Rather than
implying a control it cannot exercise, the skill states the boundary: the verdict is
the caller's to act on, and an interactive quest surfaces a `split` at its scope
checkpoint before design.

## Consequences

Review cost on low-risk work falls to one reviewer dispatch, which is where most of a
batch's rows sit.

A misrouted change costs more than before, not less: a single pass that escalates
spends one pass plus a fresh two-pass loop. That is the price of routing on an
assessment rather than on the finished diff, and it is bounded by rule 1's conditions
being conjunctive and by absence routing to `iterating`.

`$campaign` gains one operator gate. A batch containing a `split` row stops for a
decision it previously did not ask for — which is the point, but it means an unattended
run cannot drain such a row without a human.

Three skills now depend on the assessment's *content* rather than only recording it, so a
`WORK:DIVINATION` block whose adoption is rejected changes behavior: it routes
`iterating` and the run pays full depth. That is the safe direction, and it keeps the
quest-log recipe's all-or-nothing adoption intact — no consumer partially adopts fields
to reach a cheaper route.

The depth is a resume fact. A run that loses it re-derives it, and re-deriving without
the assessment lands on `iterating`, so a lost route is expensive rather than unsafe.

## Considered & rejected

- **Pass `single-pass` to `$trial-loop` as `iteration_budget: 1`.** verified: the
  loop's floor is 2 (`skills/trial-loop/SKILL.md:70-71`) because a pass that applied
  fixes always needs a confirming pass, and under 0049 an `approve` on pass 1 already
  exits after one pass — so a budget of 1 changes nothing in the clean case and ships
  unreviewed fixes in the dirty one.
- **Leave the decompose verdict advisory and stop producing it.** judgment: the
  assessment is cheap and the evidence in #282 shows it was correct; the defect is that
  nothing consumed it, and deleting a right answer is a worse fix than giving it a
  reader.
- **Gate the split inside `$quest` instead.** verified: `$quest` claims one issue
  number at step 1 and creates one branch for it at step 2, so the gate could only park
  the issue at `status:needs-human` after the charter freeze — later than the plan table
  the operator already reads, and after the claim and label writes.
- **Add a fifth `review depth` field to the `WORK:DIVINATION` annotation.** judgment:
  it derives from three fields the block already carries, and persisting it would
  change the annotation format, the canonical fingerprint, and the quest-log adoption
  recipe to store something every consumer can compute.
- **Escalate by raising the running loop's budget in place.** verified: 0049 forbids
  deriving a budget above the default from a risk signal, and the loop's charter and
  cycle-start self-collision baseline are run-scoped — a pass taken before the run
  began cannot be one of its iterations without corrupting both.
- **Do nothing.** verified: #282 records the cost of that option — a run reached a
  complete, twice-audited design with zero implementation before an operator capped it
  manually, because no actor held both the authority and the instruction to act on the
  verdict.
