# Risk-routed review depth

How much review a target gets is a routing decision, made from the `$divination`
assessment before the review runs — not a budget the reviewer negotiates once it is
running. There are two depths and no third.

- **`single-pass`** — one dispatch of the selected reviewer, findings dispositioned
  once, no second pass.
- **`iterating`** — `$trial-loop`, at its default `iteration_budget` of 2 (ordinary
  ceiling 3; above that only explicit recorded human authorization).

`single-pass` is **not** `$trial-loop` at a budget of 1. The loop's floor is 2 and
stays 2, for the reason it states: a pass that applied fixes always needs a confirming
pass. A single pass is a different shape of review — it never applies a fix and then
exits, because the escalation rule below takes that case away from it.

`$spellcraft`'s combined design-artifact set is the one call-site exception. It
uses the single-pass dispatch and validation mechanics below, but not this
routing rule or its escalation into `$trial-loop`. Its bounded protocol is one
valid independent pass and at most one further valid pass over unchanged design
artifacts. That is not a third general depth, and it changes no branch-review or
loop budget.

## Deriving the depth

Read the four assessment fields — blast radius, change hazards, complexity, decompose
verdict — from an adopted `WORK:DIVINATION` block or, when there is none or it was
rejected or stale, from the caller's own live derivation. A complete live derivation is
a present assessment. Route `single-pass` only when **all four** of these hold:

1. **Change hazards are `none`** — no migration, no auth/permission or tenancy change,
   no public API or contract change, no concurrency, no data loss or other
   irreversibility, no external service.
2. **Complexity is `S`.**
3. **Decompose verdict is `one PR`.**
4. **The target is not security-relevant** by the trigger list `$quest` step 6 applies
   to the diff — or, where no diff exists yet, by `$spellcraft`'s reading of the same
   triggers on intent.

Everything else routes `iterating`. When there is no adopted assessment, derive all
four fields live before routing. Failure to derive a complete assessment routes
`iterating` for absence: **absence routes toward depth, never away from it.** A missing,
rejected, or stale block alone is not absence when its replacement live derivation
succeeds. The four conditions are read as one unit, exactly as the assessment itself is
adopted as one unit — there is no partial route, and no field is weighed against
another.

Record the routed depth where the run records its resume facts, and name it in the run
report. A reader who sees one review pass needs to be able to tell a routing decision
from a truncated loop.

## What the routing is not

**It never buys more review.** Risk routes downward only. A hazard-carrying `L` change
gets `$trial-loop` at its ordinary budget and nothing extra: a risk assessment is
still not authorization to raise the budget past 3, which is the rule ADR 0049 sets
and this reference does not touch. The only direction added here is the cheap one.

**It is not a lower bar.** Both depths dispatch the same reviewer with the same finding
bar and the same severity gate — `critical` and `high` block, `medium` and `low` are
notes that take one disposition and ride along with an `approve`.

**It carries no scope authority.** Routing depth never freezes a charter field,
selects scope, changes a `status:` label, or assigns a `risk:` label. `WORK:DIVINATION`
stays advisory evidence on the quest-log skill's terms; how much reviewing to buy is
not a question about what the run may change.

## Running a single pass

Dispatch the reviewer in a subagent exactly as `$trial-loop` step 1 does — the
installed reviewer read in full, `--json --out <findings-path>`, the complete
`CHARTER` block last, and a `Write` tool in the worker's allowlist or `--out` silently
no-ops. Put `<findings-path>` on a scratchpad path outside the repo tree, unique to
this run: embed the issue number and branch name, because a fixed filename collides
silently when an orchestrator runs several reviews in parallel.

Then apply `$trial-loop` step 2's checks, which a single pass does not get for free:

- assert the artifact's `run_id` matches the compact object's, on every return
  including an `approve` with zero suppressions — existence is not freshness;
- treat an `approve` carrying a non-zero `blocking_count`, or a `blocking_count` above
  `findings_count`, as malformed: rerun once, then stop as blocked;
- open the artifact when `findings_count > 0` **or** `suppressed_count > 0`, and
  surface each suppression (concern plus ADR) in the transcript.

Validate the full artifact before routing it, exactly as `$trial-loop` step 2
does. Every finding has exactly one recognized `surface` (`in | adjacent`) and
`trigger` (`constructed | reproduced | inferred`); a `critical` or `high`
finding cannot be `inferred`; and each count must equal its severity-derived or
array-derived value. Rerun malformed output once, then stop as blocked. Never
repair or infer a missing field.

Outside the bounded design-artifact review below, every finding immediately
takes exactly one disposition from step 6's vocabulary —
`accepted-fixed`, `follow-up-candidate`, `deferred-tracked`,
`rejected-with-evidence`, `blocked` — under [heed-counsel](heed-counsel.md), and
a `deferred-tracked` disposition owes the same `docs/debt/` record on the same
terms. An adjacent note takes `follow-up-candidate`: copy its title,
repo-relative file evidence, trigger, recommendation, and public-safe
source-pass reference into the follow-up-candidates table, but keep its scratch
findings path in the local report only. The pass's follow-up candidates,
deferrals, suppressions, and `rejected-with-evidence` findings are disclosed
exactly as a loop run discloses them.

### Bounded design-artifact review

For `$spellcraft`'s combined design set, dispatch the first pass with the first
compatible lens selected under [review lenses](review-lenses.md). Validate its
artifact with the single-pass checks above. Apply the evidence checks from
[heed-counsel](heed-counsel.md) without editing or finally dispositioning the
findings yet; this establishes which blocking findings are defensible without
letting the second reviewer observe a response to the first.

A defensible adjacent blocking finding refutes the frozen correctness surface.
Return to `SCOPE CHECKPOINT` when interactive or park when unattended. Do not
edit, defer, expand scope, or spend the optional second pass. Adjacent notes
remain follow-up candidates under the existing disposition rule.

When a defensible in-surface blocking finding remains, dispatch one fresh
reviewer with no first-pass findings or verdict in its brief. Assert that every
design artifact is byte-identical to the first pass's target, retain the same
reviewer and frozen charter, and select the next compatible lens under
[review lenses](review-lenses.md). A changed target blocks this route rather
than turning the second pass into confirmation. There is no third valid pass.

After the last valid pass, apply the existing disposition rules to all findings
from the phase and make the accepted edits once. A repeated concern still gets
one disposition per finding; its later occurrence may cite the earlier
disposition rather than duplicate the remedy. Every defensible in-surface
blocking finding must be fixed or otherwise resolved before the scope audit. A
`blocked` disposition stops before that audit. Do not dispatch a confirming
prose review after the edits.

Each pass retains the existing one malformed-output retry: the original attempt
plus one fault-recovery attempt with the same target and lens. A malformed
attempt is not a valid independent pass and creates no additional retry budget.
Report dispatch attempts separately from valid passes, and count only valid
passes in the cumulative review-round figure.

## Escalation — an ordinary single pass is refutable

This section applies to every routed single pass except the bounded
design-artifact review above.

Inspect every blocking finding before escalation. If any is adjacent, it refutes
the frozen correctness surface: return to `SCOPE CHECKPOINT` when interactive or
park when unattended. Do not fix, defer, subtract, escalate into the loop, or
spend another review pass.

When every blocking finding is in-surface, the result **refutes the routing**: a
change that drew a blocking finding was not the low-risk change the assessment
described. Do not fix the finding and continue — that is the one outcome a
single pass cannot support, because no pass would ever review the fix.

Escalate instead. Record the escalation and the finding that caused it, then run
`$trial-loop` against the same target at its ordinary budget, starting at iteration 1.
The single pass is **not** one of that run's iterations: it is an independent review run,
and the loop's charter and disclosure obligations belong to the run that owns them. No pass
changed the target before this escalation, so select a different focus lens under
[review lenses](review-lenses.md). The loop then keeps that lens for every iteration.

This is not a risk signal buying passes, which ADR 0049 forbids. A blocking finding is
a defect a reviewer found and defended, not a forecast of what might go wrong, and the
escalation corrects a routing decision the evidence refuted. It is the same principle
read forward: the loop's answer to risk is a blocking finding it will not approve past,
and here that finding is what pays for the extra passes.

Notes never escalate. A `single-pass` review returning `approve` with `medium` or `low`
findings is a completed review — each note takes its one disposition, every adjacent note
is recorded as a follow-up candidate, and the run advances.
