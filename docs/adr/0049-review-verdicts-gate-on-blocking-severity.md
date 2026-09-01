# 0049 — Review verdicts gate on blocking severity, and budgets default to two

## Status

Accepted (2026-08-31)

Amends [0011](0011-canonical-workflow-review-vocabulary.md)'s verdict rule: the
amendment is stated here and in one appended note in that record's `## Status`
section, which keeps its accepted status and whose decision sections stay untouched —
the same shape [0029](0029-budget-stops-resume-on-explicit-operator-approval.md) used
to amend 0021. The `critical | high | medium | low` scale, the `approve |
needs-attention` verdict pair, the role names, the domain-enum rules, and the artifact
contract all stand exactly as 0011 wrote them. Only the sentence binding `approve` to
zero defensible findings is replaced.

## Context

ADR 0011 ruled that "`approve` means the review found no defensible finding. Any
finding produces `needs-attention` until the orchestrator dispositions it."
`$gauntlet` implements that rule, `$trial-loop` iterates against it, and
`iteration_budget` defaulted to 5 with callers permitted only to lower it.

On any nontrivial target some defensible finding always exists, so `approve` is
close to unreachable and the loop's ordinary ending is its cap or one of the exits
built to compensate — *converged with deferrals*, *sound with record notes*,
*converged on own surface*, the consequence-free test, the one-line re-disposition
rule. Each of those was added to let a finished target leave a loop whose reviewer
could not say yes. `skills/trial-loop/SKILL.md` reached 820 lines, most of it that
machinery.

The measured cost is recorded in three issues against this repository:

- #283 — one issue's design ran 6 spec-review iterations, then 5 plan-review
  iterations, then 2 `$oathbind` audits: 13 review rounds before a line of
  implementation existed. Every loop converged legitimately within its own cap.
- #284 — a change whose implementation is roughly 150–250 lines accumulated a
  426-line spec and a 1043-line plan.
- #282 — a run produced a complete, twice-audited design and zero implementation
  before the operator capped it manually.

External evidence agrees on both the mechanism and the remedy. Anthropic's Claude
Code best practices state that "a reviewer prompted to find gaps will usually report
some, even when the work is sound," that chasing every finding produces
over-engineering, and that a reviewer should be told to flag only gaps affecting
correctness or stated requirements. OpenAI's production Codex reviewer is single-pass
and surfaces only its top two severity ranks. The cubic case study found that
instructing a reviewer to skip low-value findings had minimal effect, while requiring
a reasoning field before each finding's grade, plus a confidence score, cut false
positives by 51% without losing recall. Published self-review studies put quality
saturation at roughly three rounds, with later rounds risking regressions in
previously correct work.

## Decision

**1. The blocking line runs between `high` and `medium`.** `critical` and `high` are
blocking; `medium` and `low` are notes. The four severity definitions in 0011 are
unchanged — the line is drawn on the existing scale rather than adding a second axis,
because two severity fields on one finding are two places for it to be recorded and
free to disagree.

**2. `approve` means no blocking finding, and notes ride along with it.** A review
returning only notes returns `approve` and reports them in full. This replaces 0011's
zero-defensible-findings rule and nothing else in that record.

The finding bar does not move. A note is reported with the same rigor and the same
*Finding bar* answers as a blocking finding; what changes is only whether it withholds
the verdict. Moving a finding across the line to obtain a verdict — in either
direction — is a hard-constraint violation in `$gauntlet` and `$detect-evil`.

**3. Findings carry a `reasoning` field, written before the grade.** Every finding
states what makes it material and why it lands at its severity before `severity`,
`confidence`, or the body is written. The ordering is the substance: a justification
that must exist before the label is what makes an unjustifiable finding fail visibly
at the point of writing it, which instruction alone does not achieve.

**4. The compact object gains `blocking_count`.** `findings_count` stays the length of
the whole array; `blocking_count` is how many are `critical` or `high`. A looping
caller iterates on `blocking_count` and reads the artifact when `findings_count` is
non-zero. An `approve` with a non-zero `blocking_count`, or a `blocking_count` above
`findings_count`, is a malformed return.

**5. `iteration_budget` defaults to 2, ceilings at 3, and rises only on explicit
recorded human authorization.** This inverts the prior rule, under which the default
was 5 and a caller holding a risk assessment could only lower it. A triage subtype, a
divination verdict, or a `$counterspell` reversal-cost assessment is evidence that a
change is risky, not authorization to buy more passes: the loop's answer to risk is a
blocking finding it will not approve past. The loop never raises its own budget.

**6. Notes are dispositioned once, never iterated.** A `medium` or `low` finding takes
its step 6 disposition on the pass that raised it. A note recurring on a later pass —
the reviewer is naive of the run's history by design — is re-affirmed in one
transcript line, exactly as an owned deferral is. A cycle ends when `blocking_count`
reaches zero, not when the findings list empties.

**7. Routing stays separate from the verdict, as 0011 already ruled.** `$forge`
continues to dispatch fixes for `medium` and to record `low` in its ledger; that is an
orchestrator choosing to act on a note, not a reviewer withholding a verdict over one.
`$oathbind` is unchanged: it is a single-pass scope audit whose `approve` conditions
are structural — complete inputs and mappings, no remaining `scope-checkpoint`,
verified deferral ownership — so no iteration cost turns on them.

## Consequences

`approve` becomes reachable on real targets, which is the point. A sound change with
adjacent notes now leaves review in two passes carrying its residue, where it
previously ran to a cap and reported blocked, or left through an exit built to
simulate the approve the reviewer could not give.

The verdict contract changes for every consumer, so this is a major version bump. The
compact object gains a field; a caller reading only the previous five is unaffected
until it needs to iterate, at which point it must read `blocking_count` rather than
inferring from `findings_count`.

Much of `$trial-loop`'s exit machinery becomes redundant once `approve`-with-notes is
the ordinary ending. This record does not delete it — a verdict change and a
simplification of the loop that consumes verdicts are separate changes, and doing both
at once would leave no green state between them. Issue #290 owns the removal and is
blocked on this record's implementation.

Security review is not loosened. An exploitable exposure or a violated authority
boundary is `critical` or `high` by the scale's own definitions and blocks exactly as
before; what becomes a note in `$detect-evil` is what the scale already called bounded.

A residue accumulates that the old rule forced to zero: notes dispositioned but not
fixed. That is the intended trade — the notes are visible in the artifact, counted in
`findings_count`, and disclosed in the run report — and it is why the disclosure
obligations on every exit stay unchanged.

## Considered & rejected

**Add a separate `blocking` boolean to each finding.** Rejected because it duplicates
what `severity` already determines. Two fields encoding one fact can disagree, and the
gate would then have two sources of truth about the same finding.

**Introduce a new `blocking | note` severity vocabulary.** Rejected because 0011's
four-value scale is a composed public contract that `$forge`, `$trial-loop`,
`$spellcraft`, `$oathbind`, and `$detect-evil` already speak. A second vocabulary
would need a conversion table at every boundary — the failure 0011 exists to have
removed.

**Keep the zero-findings rule and lower budgets alone.** Rejected because the two
compose badly: a budget of 2 against a verdict that cannot be reached would convert
today's cap-exhaustion into a faster cap-exhaustion, reporting sound work as blocked
sooner rather than approving it.

**Instruct the reviewer to report fewer low-value findings instead.** verified: the
cubic production study found prompt-level instruction to skip minor issues had minimal
effect on false-positive rate, while structural changes — reasoning before the grade,
confidence scores — cut it by 51%. This record takes the structural route because the
instructional one is already what `$gauntlet`'s finding bar says and did not hold.

**Make the reviewer single-pass, as OpenAI's does.** judgment: it is the strongest
version of this change and remains open, but it removes the confirming pass that
reviews applied fixes. A loop whose fixes ship unreviewed is a different failure from
the one this record addresses, so the floor of 2 keeps the confirming pass and the
default stops one above single-pass rather than at it.

**Do nothing and rely on operators to cap runs manually.** Rejected because that is
the current state and it is what #282, #283, and #284 record: the operator capped the
run, after the spend.
